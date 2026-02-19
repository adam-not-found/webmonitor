#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

manage_alerts() {
    while true; do
        echo -e "\n${BLUE}--- MANAGE ALERTS (Toggle On/Off) ---${NC}"
        python3 -c "import json; d=json.load(open('$CONFIG')); [print(f'{i+1}) [{\"ON\" if v else \"OFF\"}] {k}') for i, (k, v) in enumerate(d['alerts'].items()) if k != 'settings_adjusted']"
        echo "0) Back to Main Menu"
        read -p "Select a number to toggle: " alert_num
        [[ "$alert_num" == "0" ]] && break
        key=$(python3 -c "import json; d=json.load(open('$CONFIG')); keys=[k for k in d['alerts'].keys() if k != 'settings_adjusted']; print(keys[$alert_num-1])")
        python3 -c "import json; d=json.load(open('$CONFIG')); k='$key'; d['alerts'][k]=not d['alerts'][k]; json.dump(d, open('$CONFIG', 'w'), indent=4)"
        python3 $HOME/webmonitor/monitor.py --alert "settings_adjusted" "Alert toggle changed: $key" &
    done
}

manage_list() {
    local key=$1; local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        echo "1) View All"; echo "2) Add $name"; echo "3) Remove $name"; echo "4) Back"
        read -p "Selection: " subopt
        case $subopt in
            1) echo -e "\n${YELLOW}Current ${name}s:${NC}"
               python3 -c "import json; d=json.load(open('$CONFIG')); items=sorted(d['$key']); [print(f' • {i}') for i in items] if items else print('Empty')" ;;
            2) read -p "Enter $name to add: " val
               python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
               python3 $HOME/webmonitor/monitor.py --alert "added_$key" "$val" & ;;
            3) items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
               for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
               read -p "Number to remove: " num
               idx=$((num-1))
               if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
                   item_to_rm=${items[$idx]}
                   python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                   python3 $HOME/webmonitor/monitor.py --alert "removed_$key" "$item_to_rm" &
               fi ;;
            4) break ;;
        esac
    done
}

while true; do
    echo -e "\n${BLUE}🛡️  WEB MONITOR DASHBOARD${NC}"
    echo "1) Manage Gmail & Passwords"
    echo "2) Manage Trigger Words"
    echo "3) Manage Whitelisted Sites"
    echo "4) Manage Alerts (Toggles)"
    echo "5) Restart Engine (Apply Changes)"
    echo "6) Stop Monitoring & Exit"
    read -p "Select option: " opt

    case $opt in
        1)
            echo -e "\n${YELLOW}Account Settings:${NC}"
            echo "1) Sender Email:    $(get_val sender_email)"
            echo "2) App Password:    ********"
            echo "3) Recipient Email: $(get_val recipient_email)"
            echo "4) CC Mode:         $(get_val cc_email)"
            echo "0) Cancel"
            read -p "Change which? (1-4): " c_opt
            [[ "$c_opt" == "0" ]] && continue
            read -p "Enter new value: " n_val
            case $c_opt in
                1) save_val "sender_email" "'$n_val'" ;;
                2) save_val "app_password" "'$(echo $n_val | tr -d ' ')'" ;;
                3) old_rec=$(get_val recipient_email)
                   save_val "recipient_email" "'$n_val'"
                   # Now send the alert after the value is saved
                   python3 $HOME/webmonitor/monitor.py --alert "recipient_changed" "$n_val" "$old_rec" ;;
                4) if [[ "$n_val" =~ ^[Yy]$ || "$n_val" == "true" ]]; then
                       save_val "cc_email" "'$(get_val sender_email)'"
                   else
                       save_val "cc_email" "''"
                   fi ;;
            esac
            python3 $HOME/webmonitor/monitor.py --alert "settings_adjusted" "Account modified" & ;;
        2) manage_list "trigger_words" "Trigger Word" ;;
        3) manage_list "whitelist" "Whitelisted Site" ;;
        4) manage_alerts ;;
        5) pkill -f monitor.py; nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        6) pkill -f monitor.py; exit ;;
    esac
done
