#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
mkdir -p ~/.webmonitor

echo -e "${BLUE}🛡️ WebMonitor: Setup Wizard${NC}"
echo "=================================="
echo -e "${YELLOW}⚠️  Action Required: Gmail App Password${NC}"
echo "To send alerts, you need a 16-character App Password from Google."
echo "1. Go to: https://myaccount.google.com/security"
echo "2. Enable 2-Step Verification."
echo "3. Search for 'App passwords' at the TOP search bar."
echo "4. Create one named 'WebMonitor' and copy the code."
echo "----------------------------------"

# 1. Collect Data
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "Would you like to be CC'd on alerts for transparency? (y/n): " WANT_CC

CC_EMAIL=""
if [[ "$WANT_CC" =~ ^[Yy]$ ]]; then
    CC_EMAIL="$SENDER"
fi

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

echo -e "\n${BLUE}🔍 Running System Tests...${NC}"

# 3. Test Permissions
if osascript -e 'tell application "Safari" to return URL of front document' >/dev/null 2>&1; then
    echo -e "Checking macOS Accessibility permissions... ${GREEN}PASS${NC}"
else
    echo -e "Checking macOS Accessibility permissions... ${RED}FAIL${NC}"
    echo -e "${YELLOW}👉 FIX: Go to System Settings > Privacy & Security > Accessibility.${NC}"
    echo -e "${YELLOW}   Ensure 'Terminal' and 'python3' are toggled ON.${NC}"
fi

# 4. Test Email
python3 -c "import smtplib; s=smtplib.SMTP_SSL('smtp.gmail.com', 465); s.login('$SENDER', '$PASS_CLEAN'); s.quit()" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "Checking Gmail connection... ${GREEN}PASS${NC}"
else
    echo -e "Checking Gmail connection... ${RED}FAIL${NC}"
fi

# 5. Setup Launch Agent
cat << PLIST > ~/Library/LaunchAgents/com.webmonitor.engine.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.webmonitor.engine</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which python3)</string>
        <string>-u</string>
        <string>$HOME/webmonitor/monitor.py</string>
    </array>
    <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
    <key>StandardOutPath</key><string>$HOME/.webmonitor/log.txt</string>
    <key>StandardErrorPath</key><string>$HOME/.webmonitor/error.txt</string>
</dict>
</plist>

# 6. Start Engine
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.webmonitor.engine.plist 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.webmonitor.engine.plist

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo -e "----------------------------------"
echo -e "🚀 The engine is now running in the background."
echo -e "🛠️  To manage settings or triggers, run: ${BLUE}./webmonitor.sh${NC}"
