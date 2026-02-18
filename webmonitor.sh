#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

# Helper function to read JSON values
get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }

# Helper function to save JSON values
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

manage_list() {
    local key=$1
    local name=$2
    while true; do
        echo -e "\n--- Manage $name ---"
        echo "1) View All (A-Z)"
        echo "2) Add $name"
        echo "3) Remove $name"
        echo "4) Back"
        read -p "Selection: " subopt
        case $subopt in
            1) python3 -c "import json; d=json.load(open('$CONFIG')); print('\n'.join(sorted(d['$key'])))" ;;
            2) read -p "Enter $name to add: " new_item
               python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$new_item'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
               echo "Added." ;;
            3)
               items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
               for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
               read -p "Enter number to remove: " num
               idx=$((num-1))
               if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
                   item_to_rm=${items[$idx]}
                   python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                   echo "Removed $item_to_rm."
               else echo "Invalid number."; fi ;;
            4) break ;;
        esac
    done
}

while true; do
    echo -e "\n${BLUE}🛡️  WebMonitor Command Center${NC}"
    echo "1) Manage Gmail & Passwords"
    echo "2) Manage Trigger Words"
    echo "3) Manage Whitelisted Sites"
    echo "4) Restart Engine / Apply Changes"
    echo "5) View Live Logs"
    echo "6) Stop Monitoring & Exit"
    read -p "Select option: " opt

    case $opt in
        1)
            echo -e "1) Sender: $(get_val sender_email)\n2) App Pass: ********\n3) Recipient: $(get_val recipient_email)\n4) CC: $(get_val cc_email)"
            read -p "Which to change? (1-4): " c_opt
            read -p "Enter new value: " n_val
            case $c_opt in
                1) save_val "sender_email" "'$n_val'" ;;
                2) save_val "app_password" "'$(echo $n_val | tr -d ' ')'" ;;
                3) save_val "recipient_email" "'$n_val'" ;;
                4) [[ "$n_val" =~ ^[Yy]$ ]] && save_val "cc_email" "'$(get_val sender_email)'" || save_val "cc_email" "''" ;;
            esac ;;
        2) manage_list "trigger_words" "Trigger Word" ;;
        3) manage_list "whitelist" "Whitelisted Site" ;;
        4) pkill -f monitor.py; nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) tail -f ~/.webmonitor/log.txt ;;
        6) pkill -f monitor.py; exit ;;
    esac
done
