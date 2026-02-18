#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${BLUE}🛡️ WebMonitor: Setup Wizard${NC}"
echo "=================================="

# Explanation: Directory Setup
echo -e "${YELLOW}Step 1: Creating hidden storage...${NC}"
echo "Creating ~/.webmonitor to store your logs and encrypted settings safely."
mkdir -p ~/.webmonitor
touch ~/.webmonitor/log.txt
pkill -f monitor.py 2>/dev/null

# Explanation: Credentials
echo -e "\n${YELLOW}Step 2: Email Configuration${NC}"
echo "We need your Gmail 'App Password' to send alerts without using your main password."
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "CC yourself? (y/n): " WANT_CC
CC_EMAIL=""
[[ "$WANT_CC" =~ ^[Yy]$ ]] && CC_EMAIL="$SENDER"

# Explanation: Config File
echo -e "\n${YELLOW}Step 3: Saving Preferences...${NC}"
echo "Writing your trigger words and emails to a JSON config file for the engine to read."
cat << JSON > ~/.webmonitor/config.json
{
    "sender_email": "$SENDER",
    "app_password": "$PASS_CLEAN",
    "recipient_email": "$PRIMARY",
    "cc_email": "$CC_EMAIL",
    "trigger_words": ["test", "testing123"],
    "whitelist": ["apple.com"]
}
JSON

# Explanation: Persistence
echo -e "\n${YELLOW}Step 4: Setting up Auto-Start (Cron)...${NC}"
echo "Adding a 'reboot' instruction so the monitor starts automatically when your Mac turns on."
(crontab -l 2>/dev/null | grep -v "monitor.py"; echo "@reboot python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &") | crontab -

# Explanation: Ignition
echo -e "\n${YELLOW}Step 5: Launching Engine...${NC}"
echo "Starting the Python process in the background (nohup) so it stays alive after you close Terminal."
nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo "Run ./webmonitor.sh at any time to manage your settings."
