#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${BLUE}🛡️ WebMonitor: Setup Wizard${NC}"
echo "=================================="

# 1. SENDER EMAIL & APP PASSWORD GUIDE
echo -e "${YELLOW}Step 1: The 'Sender' Account${NC}"
echo "This is the Gmail account that will physically send the alert emails."
echo -e "To make this work, you MUST have ${BLUE}2-Step Verification${NC} enabled on this Google account."
echo ""
echo "How to get your App Password:"
echo "1. Go to: https://myaccount.google.com/apppasswords"
echo "2. Give it a name (e.g., 'WebMonitor') and click Create."
echo "3. Copy the 16-character code it gives you."
echo "--------------------------------------------------------"
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter the 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')

# 2. RECIPIENT EMAIL
echo -e "\n${YELLOW}Step 2: The 'Recipient' Account${NC}"
echo "This is the person who will actually receive the alerts (e.g., a partner or parent)."
read -p "Enter Recipient Email: " PRIMARY

# 3. CC OPTION
echo -e "\n${YELLOW}Step 3: Visibility${NC}"
echo "Would you like a copy of every alert sent to your own 'Sender' email as well?"
read -p "CC yourself? (y/n): " WANT_CC
CC_EMAIL=""
[[ "$WANT_CC" =~ ^[Yy]$ ]] && CC_EMAIL="$SENDER"

# 4. CONFIG GENERATION
mkdir -p ~/.webmonitor
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

# 5. STARTUP SETUP
(crontab -l 2>/dev/null | grep -v "monitor.py"; echo "@reboot python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &") | crontab -
pkill -f monitor.py 2>/dev/null
nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo "--------------------------------------------------------"
echo -e "${YELLOW}HOW TO MANAGE YOUR SETTINGS:${NC}"
echo "To add more words or change emails later, run this command:"
echo -e "${BLUE}cd ~/webmonitor && ./webmonitor.sh${NC}"
echo "Tip: Save that code in your Notes app for future use."
echo "--------------------------------------------------------"
