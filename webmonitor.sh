#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# Alert Toggling Logic
manage_alerts() {
    while true; do
        echo -e "\n${BLUE}--- MANAGE ALERTS (Toggle On/Off) ---${NC}"
        python3 -c "import json; d=json.load(open('$CONFIG')); [print(f'{i+1}) [{\"ON\" if v else \"OFF\"}] {k}') for i, (k, v) in enumerate(d['alerts'].items())]"
        echo "0) Back to Main Menu"
        read -p "Select a number to toggle: " alert_num
        [[ "$alert_num" == "0" ]] && break
        python3 -c "import json; d=json.load(open('$CONFIG')); keys=list(d['alerts'].keys()); k=keys[$alert_num-1]; d['alerts'][k]=not d['alerts'][k]; json.dump(d, open('$CONFIG', 'w'), indent=4)"
    done
}

manage_list() {
    local key=$1; local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        echo "1) View All"; echo "2) Add $name"; echo "3) Remove $name"; echo "4) Back"
        read -p "Selection: " subopt
        case $subopt in
            1) python3 -c "import json; d=json.load(open('$CONFIG')); items=sorted(d['$key']); [print(f' • {i}') for i in items] if items else print('Empty')" ;;
            2) read -p "Enter $name: " val
               python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
               # TRIGGER ALERT LOGIC (Add)
               python3 $HOME/webmonitor/monitor.py --alert "added_$key" "$val" & ;;
            3) items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
               for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
               read -p "Number: " num
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
            old_recipient=$(get_val recipient_email)
            echo -e "\n1) Sender: $(get_val sender_email)\n3) Recipient: $old_recipient"
            read -p "Change? (1-4): " c_opt
            read -p "New Value: " n_val
            if [[ "$c_opt" == "3" ]]; then
                python3 $HOME/webmonitor/monitor.py --alert "recipient_changed" "$n_val" "$old_recipient"
            fi
            case $c_opt in
                1) save_val "sender_email" "'$n_val'" ;;
                2) save_val "app_password" "'$(echo $n_val | tr -d ' ')'" ;;
                3) save_val "recipient_email" "'$n_val'" ;;
                4) [[ "$n_val" =~ ^[Yy]$ ]] && save_val "cc_email" "'$(get_val sender_email)'" || save_val "cc_email" "''" ;;
            esac ;;
        2) manage_list "trigger_words" "Trigger Word" ;;
        3) manage_list "whitelist" "Whitelisted Site" ;;
        4) manage_alerts ;;
        5) python3 $HOME/webmonitor/monitor.py --alert "service_restarted" "" &
           pkill -f monitor.py; nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 & ;;
        6) python3 $HOME/webmonitor/monitor.py --alert "service_stopped" ""
           pkill -f monitor.py; exit ;;
    esac
done
