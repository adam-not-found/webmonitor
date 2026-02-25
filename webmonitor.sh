#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- FULL DASHBOARD ---
manage_list() {
    local key=$1; local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
        for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
        echo -e "\nA) Add $name  R) Remove $name  0) Back"
        read -p "Selection: " subopt
        case $subopt in
            [Aa]*) read -p "Enter $name: " val
               python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
               python3 monitor.py --alert "settings_adjusted" "You added '$val' to the $name list." "" "added_$key" ;;
            [Rr]*) read -p "Enter number to remove: " num
               idx=$((num-1)); item_to_rm=${items[$idx]}
               if [[ -n "$item_to_rm" ]]; then
                   python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                   python3 monitor.py --alert "settings_adjusted" "You removed '$item_to_rm' from the $name list." "" "removed_$key"
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
            cc_status="OFF"; [[ -n "$(get_val cc_email)" ]] && cc_status="ON"
            echo -e "\n${YELLOW}--- EMAIL SETTINGS ---${NC}"
            echo "1) Sender:    $(get_val sender_email)"
            echo "2) Recipient: $(get_val recipient_email)"
            echo "3) CC Mode:   $cc_status"
            echo "0) Back"
            read -p "Selection: " e_opt
            case $e_opt in
                1) read -p "New Sender: " n_em; read -p "New PW: " n_pw
                   n_pw=$(echo $n_pw | tr -d ' ')
                   if python3 monitor.py --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                   fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   save_val "recipient_email" "'$n_r'"; python3 monitor.py --alert "recipient_changed" "$n_r" "$old_r" ;;
                3) read -p "Enable CC? (y/n): " confirm; new_cc=""; [[ "$confirm" =~ ^[Yy]$ ]] && new_cc="$(get_val sender_email)"
                   save_val "cc_email" "'$new_cc'"; python3 monitor.py --alert "settings_adjusted" "CC Mode changed to $confirm." ;;
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
            read -p "Toggle (0 to back): " t_opt
            [[ "$t_opt" == "0" ]] && break
            key=$(python3 -c "import json; d=json.load(open('$CONFIG')); keys=[k for k in d['alerts'].keys() if k != 'settings_adjusted']; print(keys[$t_opt-1])")
            python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; val=d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4); print(f'SETTING:{key}:{val}')" > .tmp_toggle
            t_info=$(cat .tmp_toggle | grep "SETTING:")
            python3 monitor.py --alert "settings_adjusted" "Alert toggle changed: ${t_info#SETTING:}"
            rm .tmp_toggle
           done ;;
        4) pkill -f monitor.py; nohup python3 monitor.py >> "$HOME/.webmonitor/log.txt" 2>&1 &
           python3 monitor.py --alert "service_restarted"
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) cd ~ && rm -rf "$HOME/.webmonitor" && exit ;;
    esac
done
