#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${BLUE}🛡️  WebMonitor Command Center${NC}"
echo "----------------------------------"
echo "1) Manage Gmail & Passwords  -> Update your login info or recipient email"
echo "2) Manage Trigger Words      -> Add or remove keywords to watch for"
echo "3) Restart Engine            -> Use if alerts aren't sending"
echo "4) View Live Logs            -> See what the monitor is reading right now"
echo "5) Stop Monitoring           -> Turn off the engine completely"
echo "6) Exit"
echo ""
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
