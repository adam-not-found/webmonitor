#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
GUID=$(id -u)
PLIST="$HOME/Library/LaunchAgents/com.webmonitor.engine.plist"

# CRITICAL: Create directory before anything else
mkdir -p ~/.webmonitor

echo -e "${BLUE}🛡️ WebMonitor: Setup Wizard${NC}"
echo "=================================="

# 1. Collect Data
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "Would you like to be CC'd on alerts for transparency? (y/n): " WANT_CC
CC_EMAIL=""
[[ "$WANT_CC" =~ ^[Yy]$ ]] && CC_EMAIL="$SENDER"

# 2. Create Config
cat << JSON > ~/.webmonitor/config.json
{
    "sender_email": "$SENDER",
    "app_password": "$PASS_CLEAN",
    "recipient_email": "$PRIMARY",
    "cc_email": "$CC_EMAIL",
    "trigger_words": ["testing123"],
    "whitelist": ["apple.com"]
}
JSON

# 3. Create Launch Agent
cat << XML > "$PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.webmonitor.engine</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which python3)</string>
        <string>-u</string>
        <string>$HOME/webmonitor/monitor.py</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$HOME/.webmonitor/log.txt</string>
    <key>StandardErrorPath</key><string>$HOME/.webmonitor/error.txt</string>
</dict>
XML

echo -e "\n${BLUE}🔍 Initializing Engine...${NC}"

# 4. Force Bootstrap
launchctl bootout gui/$GUID "$PLIST" 2>/dev/null
sleep 1
launchctl bootstrap gui/$GUID "$PLIST"
launchctl kickstart -k gui/$GUID/com.webmonitor.engine

echo -e "${GREEN}✅ Installation Complete!${NC}"
echo -e "🛠️  Manage with: ./webmonitor.sh"
