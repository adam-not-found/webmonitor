#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

manage_list() {
    local key=$1
    local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        echo "1) View All (A-Z)"
        echo "2) Add $name"
        echo "3) Remove $name"
        echo "4) Back to Main Menu"
        echo "--------------------------"
        read -p "Selection: " subopt
        case $subopt in
            1)
                echo -e "\n${YELLOW}Current ${name}s:${NC}"
                python3 -c "import json; d=json.load(open('$CONFIG')); items=sorted(d['$key']); [print(f' • {i}') for i in items] if items else print(' (List is empty)')"
                echo "--------------------------" ;;
            2)
                read -p "Enter $name to add: " new_item
                python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$new_item'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                echo -e "${GREEN}Added successfully.${NC}" ;;
            3)
                echo -e "\n${YELLOW}Select item to remove:${NC}"
                items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
                if [ ${#items[@]} -eq 0 ]; then echo "Nothing to remove."; else
                    for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
                    read -p "Enter number: " num
                    idx=$((num-1))
                    if [[ $idx -ge 0 && $idx -lt ${#items[@]} ]]; then
                        item_to_rm=${items[$idx]}
                        python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                        echo -e "${GREEN}Removed $item_to_rm.${NC}"
                    else echo -e "${YELLOW}Invalid selection.${NC}"; fi
                fi ;;
            4) break ;;
        esac
    done
}

while true; do
    echo -e "\n${BLUE}================================"
    echo -e "   🛡️  WEB MONITOR DASHBOARD"
    echo -e "================================${NC}"
    echo "1) Manage Gmail & Passwords"
    echo "2) Manage Trigger Words"
    echo "3) Manage Whitelisted Sites"
    echo "4) Restart Engine / Apply Changes"
    echo "5) View Live Logs (Debug)"
    echo "6) Stop Monitoring & Exit"
    echo "--------------------------------"
    read -p "Select option: " opt

    case $opt in
        1)
            echo -e "\n${YELLOW}Current Configuration:${NC}"
            echo -e "1) Sender:    $(get_val sender_email)"
            echo -e "2) App Pass:  ********"
            echo -e "3) Recipient: $(get_val recipient_email)"
            echo -e "4) CC Mode:   $(get_val cc_email)"
            echo "--------------------------"
            read -p "Change which? (1-4 or 0 to cancel): " c_opt
            [[ "$c_opt" == "0" ]] && continue
            read -p "Enter new value: " n_val
            case $c_opt in
                1) save_val "sender_email" "'$n_val'" ;;
                2) save_val "app_password" "'$(echo $n_val | tr -d ' ')'" ;;
                3) save_val "recipient_email" "'$n_val'" ;;
                4) [[ "$n_val" =~ ^[Yy]$ ]] && save_val "cc_email" "'$(get_val sender_email)'" || save_val "cc_email" "''" ;;
            esac
            echo -e "${GREEN}Setting updated.${NC}" ;;
        2) manage_list "trigger_words" "Trigger Word" ;;
        3) manage_list "whitelist" "Whitelisted Site" ;;
        4) pkill -f monitor.py; nohup python3 $HOME/webmonitor/monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "\n${GREEN}✅ Engine Restarted. Changes applied.${NC}" ;;
        5) echo -e "\n${YELLOW}Showing live activity (Ctrl+C to stop)...${NC}"
           tail -f ~/.webmonitor/log.txt ;;
        6) pkill -f monitor.py; echo -e "${YELLOW}Monitoring stopped. Goodbye!${NC}"; exit ;;
    esac
done
