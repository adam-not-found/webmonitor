#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'

echo -e "${BLUE}🛡️  WebMonitor Command Center${NC}"
echo "----------------------------------"
echo "1) Manage Gmail & Passwords (Config)"
echo "2) Manage Trigger Words & Whitelist"
echo "3) Restart Monitoring Engine"
echo "4) View Live Logs (Debug)"
echo "5) Stop Monitoring"
echo "6) Exit"
read -p "Select an option: " opt

case $opt in
    1|2) nano ~/.webmonitor/config.json ;;
    3) pkill -f monitor.py
       nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
       echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
    4) tail -f ~/.webmonitor/log.txt ;;
    5) pkill -f monitor.py
       echo "Monitoring Stopped." ;;
    *) exit ;;
esac
