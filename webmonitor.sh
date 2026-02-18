#!/bin/bash
GUID=$(id -u)
PLIST="$HOME/Library/LaunchAgents/com.webmonitor.engine.plist"

echo "----------------------------------"
echo "🛡️  WebMonitor Command Center"
echo "----------------------------------"
echo "1) Manage Trigger Words & Whitelist"
echo "2) Restart Monitoring Engine"
echo "3) View Live Logs (Debug)"
echo "4) Stop Monitoring (Kill Process)"
echo "5) Exit"
read -p "Select an option: " OPT

case $OPT in
    1) python3 webmonitor_mgr.py ;;
    2) launchctl bootout gui/$GUID "$PLIST" 2>/dev/null
       launchctl bootstrap gui/$GUID "$PLIST"
       echo "✅ Engine Restarted using Modern Bootstrap." ;;
    3) echo "📋 Showing logs (Press Ctrl+C to stop)..."
       tail -f ~/.webmonitor/log.txt ;;
    4) launchctl bootout gui/$GUID "$PLIST"
       echo "🛑 Engine Stopped." ;;
    *) exit ;;
esac
