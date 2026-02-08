#!/data/data/com.termux/files/usr/bin/bash

# ==========================================
#  OPENCLAW: SAFE UPDATE SCRIPT
#  Preserves config & service setup
# ==========================================

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}>>> Updating OpenClaw...${NC}"

# 1. Stop the service first (Important!)
echo -e "${YELLOW}[-] Stopping background service...${NC}"
sv down openclaw

# 2. Pull the latest code
echo -e "${YELLOW}[-] Fetching latest version from npm...${NC}"
npm install -g openclaw@latest

# 3. Re-apply the Critical Patch (Updates often overwrite this!)
echo -e "${YELLOW}[-] Re-patching hardcoded /tmp paths...${NC}"
TARGET_FILE="$PREFIX/lib/node_modules/openclaw/dist/entry.js"

if [ -f "$TARGET_FILE" ]; then
    sed -i "s|/tmp/openclaw|$PREFIX/tmp/openclaw|g" "$TARGET_FILE"
    echo -e "${GREEN}    Success: Patch re-applied.${NC}"
else
    echo -e "\033[1;31m[!] Warning: entry.js not found. Update might have changed structure.\033[0m"
fi

# 4. Restart the service
echo -e "${YELLOW}[-] Restarting service...${NC}"
sv up openclaw

echo -e "\n${GREEN}>>> Update Complete! Check status with: sv status openclaw${NC}"
