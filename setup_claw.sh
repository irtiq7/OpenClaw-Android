#!/data/data/com.termux/files/usr/bin/bash

# ====================================================
#  OPENCLAW: AUTOMATED TERMUX INSTALLER
#  Target: Android (Non-Rooted)
#  Fixes: /tmp paths, Node-GYP crashes, Service Daemon
# ====================================================

set -e  # Stop immediately if any command fails

# Colors for output
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}>>> Starting Fresh OpenClaw Setup...${NC}"

# --- STEP 1: Dependencies & System Prep ---
echo -e "${YELLOW}[1/6] Updating system and installing dependencies...${NC}"
pkg update -y && pkg upgrade -y
# Core tools + Build tools (for compiling AI engine) + Hardware APIs + Service Manager
pkg install -y nodejs-lts git build-essential python cmake clang ninja pkg-config binutils termux-api termux-services proot tmux nano

# --- STEP 2: Fix Environment Variables ---
echo -e "${YELLOW}[2/6] Configuring environment paths...${NC}"
# Create the correct temp directories
mkdir -p "$PREFIX/tmp"
mkdir -p "$HOME/tmp"

# Ensure that ~/.bashrc exists before attempting sed
touch ~/.bashrc

# Clean up old/duplicate entries in .bashrc
sed -i '/export TMPDIR=/d' ~/.bashrc
sed -i '/export TMP=/d' ~/.bashrc
sed -i '/export TEMP=/d' ~/.bashrc

# Add persistent exports to .bashrc
echo 'export TMPDIR="$PREFIX/tmp"' >> ~/.bashrc
echo 'export TMP="$PREFIX/tmp"' >> ~/.bashrc
echo 'export TEMP="$PREFIX/tmp"' >> ~/.bashrc

# Export for THIS session right now
export TMPDIR="$PREFIX/tmp"
export TMP="$PREFIX/tmp"
export TEMP="$PREFIX/tmp"

# --- STEP 3: Fix Node-GYP Crash (Android NDK) ---
echo -e "${YELLOW}[3/6] Applying Node-GYP workaround...${NC}"
mkdir -p ~/.gyp
# Create a dummy config so build tools don't panic looking for Android NDK
echo "{'variables':{'android_ndk_path':''}}" > ~/.gyp/include.gypi

# --- STEP 4: Install OpenClaw ---
echo -e "${YELLOW}[4/6] Installing OpenClaw via npm (This may take 5-10 mins)...${NC}"
# Install globally
npm install -g openclaw@latest

# --- STEP 5: Patch Hardcoded Paths (CRITICAL) ---
echo -e "${YELLOW}[5/6] Patching application code...${NC}"
# We must replace the hardcoded '/tmp/openclaw' with our valid Termux path
TARGET_FILE="$PREFIX/lib/node_modules/openclaw/dist/entry.js"

if [ -f "$TARGET_FILE" ]; then
    sed -i "s|/tmp/openclaw|$PREFIX/tmp/openclaw|g" "$TARGET_FILE"
    echo -e "${GREEN}    Success: Patched entry.js${NC}"
else
    echo -e "${RED}    WARNING: entry.js not found. Installation structure might have changed.${NC}"
fi

# --- STEP 6: Service Setup (Manual Daemon) ---
echo -e "${YELLOW}[6/6] Setting up background service...${NC}"
SERVICE_DIR="$PREFIX/var/service/openclaw"
LOG_DIR="$PREFIX/var/log/openclaw"

mkdir -p "$SERVICE_DIR/log"
mkdir -p "$LOG_DIR"

# Create the RUN script (The Brain)
cat <<EOF > "$SERVICE_DIR/run"
#!/data/data/com.termux/files/usr/bin/sh
# 1. We must explicitly set PATH so the service finds 'node'
export PATH=$PREFIX/bin:\$PATH
# 2. We must explicitly set TMPDIR so it can write files
export TMPDIR=$PREFIX/tmp
# 3. Start the gateway
exec openclaw gateway 2>&1
EOF

# Create the LOG script
cat <<EOF > "$SERVICE_DIR/log/run"
#!/data/data/com.termux/files/usr/bin/sh
exec svlogd -tt $LOG_DIR
EOF

# Make them executable
chmod +x "$SERVICE_DIR/run"
chmod +x "$SERVICE_DIR/log/run"

# Enable the service (but don't start yet)
# Termux services sometimes don't export SVDIR until a new shell.
# Make it explicit for this session and future shells.
sed -i '/export SVDIR=/d' ~/.bashrc
echo 'export SVDIR="$PREFIX/var/service"' >> ~/.bashrc
export SVDIR="$PREFIX/var/service"

# Ensure runit is actually supervising $SVDIR (termux-services can be flaky right after install)
service-daemon stop >/dev/null 2>&1 || true
service-daemon start >/dev/null 2>&1 || true

# Wait briefly for supervise/ok to exist so sv doesn't error out
for i in 1 2 3 4 5; do
  [ -e "$PREFIX/var/service/openclaw/supervise/ok" ] && break
  sleep 1
done

sv-enable openclaw

# --- FINAL INSTRUCTIONS ---
echo -e "\n${GREEN}============================================="
echo -e "       SETUP COMPLETE - READ CAREFULLY"
echo -e "=============================================${NC}"

echo -e "${RED}[!] WARNING FOR ONBOARDING:${NC}"
echo -e "    1. Run: ${YELLOW}openclaw onboard${NC}"
echo -e "    2. When asked to install a Daemon/Service: ${RED}SAY NO / SKIP${NC}"
echo -e "       (Android does not support systemd. We already installed the service for you manually.)"

echo -e "\n${GREEN}[+] AFTER ONBOARDING:${NC}"
echo -e "    1. Reload shell:  ${YELLOW}source ~/.bashrc${NC}"
echo -e "    2. Start Service: ${YELLOW}sv up openclaw${NC}"
echo -e "    3. Lock Process:  ${YELLOW}termux-wake-lock${NC} (Required to keep it running)"
echo -e "    4. Access UI:     ${YELLOW}http://localhost:18789${NC}"
echo ""
