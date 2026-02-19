#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json,os; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

manage_list() {
    local key=$1; local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
        if [ ${#items[@]} -eq 0 ]; then echo "List is currently empty."; else
            for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
        fi
        echo -e "\nA) Add $name  R) Remove $name  0) Back"
        read -p "Selection: " subopt
        case $subopt in
            [Aa]*) read -p "Enter $name: " val
               python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
               python3 monitor.py --alert "settings_adjusted" "Added '$val' to the $name list." ;;
            [Rr]*) read -p "Enter number to remove: " num
               idx=$((num-1)); item_to_rm=${items[$idx]}
               if [[ -n "$item_to_rm" ]]; then
                   python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                   python3 monitor.py --alert "settings_adjusted" "Removed '$item_to_rm' from the $name list."
               fi ;;
            0) break ;;
        esac
    done
}

while true; do
    echo -e "\n${BLUE}🛡️  WEB MONITOR DASHBOARD${NC}"
    echo "1) Email & Account Settings"
    echo "2) Trigger Words & Whitelist"
    echo "3) Alert Toggles (On/Off)"
    echo "4) Restart Engine (Apply Changes)"
    echo "5) Stop & Uninstall Options"
    read -p "Select option: " opt

    case $opt in
        1) while true; do
            cc_val=$(get_val cc_email); cc_status="OFF"; [[ -n "$cc_val" ]] && cc_status="ON"
            echo -e "\n${YELLOW}--- EMAIL SETTINGS ---${NC}"
            echo "1) Sender:    $(get_val sender_email)"
            echo "2) Recipient: $(get_val recipient_email)"
            echo "3) CC Mode:   $cc_status"
            echo "0) Back"
            read -p "Change which? " e_opt
            case $e_opt in
                1) echo -e "\n${BLUE}How to get an App Password:${NC}\n1. Go to Google Account > Security\n2. Enable 2-Step Verification\n3. Search 'App Passwords' at the top\n4. Create one named 'WebMonitor'\n"
                   read -p "New Sender Gmail: " n_em; read -p "New App Password: " n_pw
                   n_pw=$(echo $n_pw | tr -d ' ')
                   echo "Verifying..."
                   if python3 monitor.py --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                   else echo -e "${RED}❌ Verification failed. Check your App Password and try again.${NC}"; fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   if [[ "$n_r" != "$old_r" ]]; then
                       save_val "recipient_email" "'$n_r'"
                       python3 monitor.py --alert "recipient_changed" "$n_r" "$old_r"
                   fi ;;
                3) read -p "Should sender be CC'd on all alerts? (y/n): " confirm
                   new_cc=""; [[ "$confirm" =~ ^[Yy]$ ]] && new_cc="$(get_val sender_email)"
                   if [[ "$new_cc" != "$cc_val" ]]; then
                       save_val "cc_email" "'$new_cc'"
                       msg="Enabled CC mode (Sender will receive copies of all alerts)."
                       [[ -z "$new_cc" ]] && msg="Disabled CC mode (Sender will no longer receive copies)."
                       python3 monitor.py --alert "settings_adjusted" "$msg"
                   fi ;;
                0) break ;;
            esac
           done ;;
        2) while true; do
            echo -e "\n1) Trigger Words  2) Whitelist  0) Back"
            read -p "> " l_opt
            [[ "$l_opt" == "1" ]] && manage_list "trigger_words" "Trigger Word"
            [[ "$l_opt" == "2" ]] && manage_list "whitelist" "Whitelisted Site"
            [[ "$l_opt" == "0" ]] && break
           done ;;
        3) while true; do
            python3 -c "import json; d=json.load(open('$CONFIG')); [print(f'{i+1}) [{\"ON\" if v else \"OFF\"}] {k}') for i, (k, v) in enumerate(d['alerts'].items()) if k != 'settings_adjusted']"
            read -p "Toggle which (0 to back): " t_opt
            [[ "$t_opt" == "0" ]] && break
            key=$(python3 -c "import json; d=json.load(open('$CONFIG')); keys=[k for k in d['alerts'].keys() if k != 'settings_adjusted']; print(keys[$t_opt-1])")
            python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4)"
            status=$(get_val alerts | python3 -c "import sys, json; print('enabled' if json.load(sys.stdin)['$key'] else 'disabled')")
            python3 monitor.py --alert "settings_adjusted" "The alert for '$key' was $status. You will now be notified accordingly."
           done ;;
        4) python3 monitor.py --alert "service_restarted"; pkill -f monitor.py; nohup python3 monitor.py >> $HOME/.webmonitor/log.txt 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) pkill -f monitor.py 2>/dev/null; echo -e "${YELLOW}Stopped.${NC}"
           read -p "Uninstall? (y/n): " un; [[ "$un" =~ ^[Yy]$ ]] && read -p "Type 'confirm deletion': " c && [[ "$c" == "confirm deletion" ]] && rm -rf "$HOME/.webmonitor" && cd ~ && rm -rf "$HOME/webmonitor" && exit ;;
    esac
done
