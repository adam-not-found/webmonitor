#!/bin/bash
GUID=$(id -u)
PLIST="$HOME/Library/LaunchAgents/com.webmonitor.app.plist"
mkdir -p ~/.webmonitor
touch ~/.webmonitor/log.txt
pkill -f monitor.py 2>/dev/null
echo "🛡️ WebMonitor: Setup Wizard"
echo "=================================="
read -p "Enter SENDER Gmail: " SENDER
read -p "Enter 16-char App Password: " PASS
PASS_CLEAN=$(echo $PASS | tr -d ' ')
read -p "Enter Partner Email: " PRIMARY
read -p "CC yourself? (y/n): " WANT_CC
CC_EMAIL=""
[[ "$WANT_CC" =~ ^[Yy]$ ]] && CC_EMAIL="$SENDER"
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
cat << XML > "$PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.webmonitor.app</string>
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
launchctl bootout gui/$GUID "$PLIST" 2>/dev/null
sleep 1
launchctl bootstrap gui/$GUID "$PLIST"
launchctl kickstart -k gui/$GUID/com.webmonitor.app
echo "✅ Installed and Running."
