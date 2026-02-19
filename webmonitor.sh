#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

while true; do
    echo -e "\n${BLUE}🛡️  WEB MONITOR DASHBOARD${NC}"
    echo "1) Manage Sender Account (Verified)"
    echo "2) Manage Recipient Email"
    echo "3) Manage CC Mode"
    echo "4) Manage Lists (Triggers/Whitelist)"
    echo "5) Restart Engine (Apply Changes)"
    echo "6) Stop & Uninstall Options"
    read -p "Select option: " opt

    case $opt in
        1)
            echo -e "\n${YELLOW}Current Sender:${NC} $(get_val sender_email)"
            read -p "Enter New Sender Gmail: " n_email
            read -p "Enter App Password: " n_pass
            n_pass_clean=$(echo $n_pass | tr -d ' ')
            echo "Verifying..."
            if python3 monitor.py --test-creds "$n_email" "$n_pass_clean" "$(get_val recipient_email)"; then
                save_val "sender_email" "'$n_email'"; save_val "app_password" "'$n_pass_clean'"
                echo -e "${GREEN}Saved.${NC}"
            else
                echo -e "${RED}Failed. Check credentials.${NC}"
            fi ;;
        2)
            old_rec=$(get_val recipient_email); read -p "New Recipient: " n_rec
            save_val "recipient_email" "'$n_rec'"
            python3 monitor.py --alert "recipient_changed" "$n_rec" "$old_rec" ;;
        3)
            cc_val=$(get_val cc_email); status="${GREEN}ON${NC}"; [[ -z "$cc_val" ]] && status="${RED}OFF${NC}"
            echo -e "CC Mode: $status"; read -p "Toggle? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                [[ -z "$cc_val" ]] && save_val "cc_email" "'$(get_val sender_email)'" || save_val "cc_email" "''"
                python3 monitor.py --alert "settings_adjusted" "CC Mode Toggled"
            fi ;;
        4) echo "1) Triggers 2) Whitelist"; read -p "> " sub; [[ "$sub" == "1" ]] && python3 -c "import json; d=json.load(open('$CONFIG')); print(d['trigger_words'])" ;;
        5) pkill -f monitor.py; nohup python3 monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        6) 
            pkill -f monitor.py 2>/dev/null; echo -e "${YELLOW}Service Stopped.${NC}"
            read -p "Uninstall WebMonitor? (y/n): " uninst
            if [[ "$uninst" =~ ^[Yy]$ ]]; then
                read -p "Type 'confirm deletion': " confirm
                if [[ "$confirm" == "confirm deletion" ]]; then
                    (crontab -l | grep -v "monitor.py") | crontab -
                    rm -rf "$HOME/.webmonitor"
                    cd ~ && rm -rf "$HOME/webmonitor"
                    echo "Uninstalled."; exit
                fi
            fi
            exit ;;
    esac
done
