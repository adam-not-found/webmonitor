#!/bin/bash

# --- STYLING ---
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- HELP SECTION ---
show_help() {
    echo -e "${BLUE}📖 QUICK START GUIDE${NC}"
    echo "1. Config: Manages your Gmail, App Password, and Partner Email."
    echo "2. Triggers: Add or remove words that trigger instant alerts."
    echo "3. Engine: Restarts the background monitor if it stops working."
    echo "4. Debug: Shows you exactly what the monitor is 'seeing' right now."
    echo "--------------------------------------------------------"
}

# --- MENU ---
echo -e "${BLUE}🛡️  WebMonitor Command Center${NC}"
show_help

echo "1) Manage Gmail & Passwords (Config)"
echo "2) Manage Trigger Words & Whitelist"
echo "3) Restart Monitoring Engine"
echo "4) View Live Logs (Debug)"
echo "5) Stop Monitoring"
echo "6) Exit"
read -p "Select an option: " opt

case $opt in
    1)
        # Opens the hidden config file in the default text editor
        nano ~/.webmonitor/config.json
        ;;
    2)
        # Simple interface to add words (Logic handled in monitor.py)
        echo "Current Config:"
        cat ~/.webmonitor/config.json
        echo -e "\n${YELLOW}Tip: Edit the 'trigger_words' list in the file.${NC}"
        nano ~/.webmonitor/config.json
        ;;
    3)
        # Kills any stuck processes and starts a fresh one
        pkill -f monitor.py
        nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
        echo -e "${GREEN}✅ Engine Restarted.${NC}"
        ;;
    4)
        # Shows the last 20 lines of activity
        tail -f ~/.webmonitor/log.txt
        ;;
    5)
        pkill -f monitor.py
        echo -e "${YELLOW}⚠️  Monitoring Stopped.${NC}"
        ;;
    *)
        exit
        ;;
esac
