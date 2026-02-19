#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

while true; do
    echo -e "\n${BLUE}🛡️  WEB MONITOR DASHBOARD${NC}"
    echo "1) Email & Account Settings"
    echo "2) Manage Lists (Triggers/Whitelist)"
    echo "3) Alert Toggles (On/Off)"
    echo "4) Restart Engine (Apply Changes)"
    echo "5) Stop & Uninstall Options"
    read -p "Select option: " opt

    case $opt in
        1)
            cc_status="OFF"; [[ -n "$(get_val cc_email)" ]] && cc_status="ON"
            echo -e "\n${YELLOW}--- EMAIL SETTINGS ---${NC}"
            echo "1) Sender:    $(get_val sender_email)"
            echo "2) Recipient: $(get_val recipient_email)"
            echo "3) CC Mode:   $cc_status"
            echo "0) Back"
            read -p "Selection: " e_opt
            case $e_opt in
                1) read -p "New Sender Gmail: " n_em; read -p "New App Password: " n_pw
                   n_pw=$(echo $n_pw | tr -d ' ')
                   if python3 monitor.py --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                       python3 monitor.py --alert "settings_adjusted" "Sender account updated to $n_em"
                   fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   save_val "recipient_email" "'$n_r'"
                   python3 monitor.py --alert "recipient_changed" "$n_r" "$old_r" ;;
                3) read -p "Should sender be CC'd on all alerts? (y/n): " confirm
                   if [[ "$confirm" =~ ^[Yy]$ ]]; then save_val "cc_email" "'$(get_val sender_email)'"; else save_val "cc_email" "''"; fi
                   python3 monitor.py --alert "settings_adjusted" "CC Mode changed to $confirm" ;;
            esac ;;
        2) echo "1) Triggers 2) Whitelist"; read -p "> " sub; [[ "$sub" == "1" ]] && python3 -c "import json; d=json.load(open('$CONFIG')); print(d['trigger_words'])" ;;
        3) 
            python3 -c "import json; d=json.load(open('$CONFIG')); [print(f'{i+1}) [{\"ON\" if v else \"OFF\"}] {k}') for i, (k, v) in enumerate(d['alerts'].items()) if k != 'settings_adjusted']"
            read -p "Toggle which (0 to exit): " t_opt
            [[ "$t_opt" == "0" ]] && continue
            key=$(python3 -c "import json; d=json.load(open('$CONFIG')); keys=[k for k in d['alerts'].keys() if k != 'settings_adjusted']; print(keys[$t_opt-1])")
            python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4)"
            python3 monitor.py --alert "settings_adjusted" "Alert toggle: $key" ;;
        4) pkill -f monitor.py; nohup python3 monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) pkill -f monitor.py 2>/dev/null; echo -e "${YELLOW}Stopped.${NC}"
           read -p "Uninstall? (y/n): " un; [[ "$un" =~ ^[Yy]$ ]] && read -p "Type 'confirm deletion': " c && [[ "$c" == "confirm deletion" ]] && rm -rf "$HOME/.webmonitor" && cd ~ && rm -rf "$HOME/webmonitor" && exit ;;
    esac
done
