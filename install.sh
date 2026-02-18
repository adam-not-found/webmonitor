#!/bin/bash

# Styling
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🛡️  WebMonitor: Setup Wizard${NC}"
echo "=================================="

# 1. Create directory
mkdir -p ~/.webmonitor

# 2. Instructions for App Password
echo -e "${YELLOW}⚠️  Action Required: Gmail App Password${NC}"
echo "To send alerts, you need a 16-character App Password from Google."
echo "1. Go to: https://myaccount.google.com/security"
echo "2. Enable 2-Step Verification if not already on."
echo "3. Search for 'App passwords' at the bottom."
echo "4. Create one named 'WebMonitor' and copy the code."
echo "----------------------------------"

# 3. Collect Data
read -p "Enter the SENDER Gmail address: " SENDER
read -p "Enter the 16-character App Password: " PASS
# Clean spaces from password
PASS_CLEAN=$(echo $PASS | tr -d ' ')

# Flexible Email Setup
RECIPIENTS="[]"
read -p "Enter the primary Accountability Partner email: " PRIMARY
read -p "Enter your email (for CC/Transparency): " CC_EMAIL

# 4. Create the JSON file
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

echo -e "${GREEN}✅ Configuration saved to ~/.webmonitor/config.json${NC}"
echo "Next: I will prepare the monitoring engine..."
