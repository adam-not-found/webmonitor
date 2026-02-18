#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
mkdir -p ~/.webmonitor
touch ~/.webmonitor/log.txt
pkill -f monitor.py 2>/dev/null

echo "🛡️ WebMonitor: Setup Wizard"
echo "=================================="

# 1. Collect Data
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "CC yourself? (y/n): " WANT_CC
CC_EMAIL=""
[[ "$WANT_CC" =~ ^[Yy]$ ]] && CC_EMAIL="$SENDER"

# 2. Create Config (Adding 'test' and 'testing123' as defaults)
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

# 3. Setup Auto-Start (Cron)
(crontab -l 2>/dev/null | grep -v "monitor.py"; echo "@reboot python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &") | crontab -

# 4. Start Now
nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &

echo -e "${GREEN}✅ Installation Complete!${NC}"
