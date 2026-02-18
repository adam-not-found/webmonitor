#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
mkdir -p ~/.webmonitor
touch ~/.webmonitor/log.txt

echo "🛡️ WebMonitor: Setup Wizard (Robust Mode)"
echo "=================================="

# 1. Collect Data
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "CC yourself? (y/n): " WANT_CC
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

# 3. Use Cron for Auto-Start (Avoids Launchctl Error 5)
# This clears old webmonitor cron jobs and adds a fresh one
(crontab -l 2>/dev/null | grep -v "monitor.py"; echo "@reboot python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &") | crontab -

# 4. Start the engine immediately for this session
pkill -f monitor.py 2>/dev/null
nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &

echo -e "${GREEN}✅ Installed and Running via Cron!${NC}"
echo "The engine will now start automatically whenever the Mac reboots."
