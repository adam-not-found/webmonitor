#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- SETUP WIZARD (Runs only if config is missing or empty) ---
if [ ! -f "$CONFIG" ] || [ "$(get_val sender_email)" == "temp" ] || [ -z "$(get_val sender_email)" ] || [ "$(get_val sender_email)" == "None" ]; then
    echo -e "${BLUE}🛡️  WEBMONITOR FIRST-TIME SETUP${NC}"
    mkdir -p "$HOME/.webmonitor"
    echo '{"sender_email":"","app_password":"","recipient_email":"","cc_email":"","whitelist":[],"trigger_words":[],"alerts":{"word_found":true,"added_trigger_words":true,"removed_trigger_words":true,"added_whitelist":true,"removed_whitelist":true,"service_restarted":true,"service_stopped":true,"recipient_changed":true}}' > "$CONFIG"

    read -p "Enter the RECIPIENT email: " n_rec
    save_val "recipient_email" "'$n_rec'"

    while true; do
        echo -e "\n${YELLOW}Sender Setup (Need 2FA + App Password):${NC}"
        read -p "Enter SENDER Gmail: " n_snd
        read -p "Enter App Password: " n_pw
        n_pw=$(echo $n_pw | tr -d ' ')
        if python3 monitor.py --test-creds "$n_snd" "$n_pw" "$n_rec"; then
            save_val "sender_email" "'$n_snd'"; save_val "app_password" "'$n_pw'"
            read -p "Enable CC Mode (Send copies to yourself)? (y/n): " n_cc
            [[ "$n_cc" =~ ^[Yy]$ ]] && save_val "cc_email" "'$n_snd'"
            break
        else echo -e "${RED}❌ Verification failed.${NC}"; fi
    done

    for listname in "trigger_words" "whitelist"; do
        while true; do
            echo -e "\n${YELLOW}Add to $listname (Type '0' to finish):${NC}"
            read -p "> " item
            [[ "$item" == "0" ]] && break
            python3 -c "import json; d=json.load(open('$CONFIG')); d['$listname'].append('$item'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
        done
    done

    while true; do
        echo -e "\n${YELLOW}Toggle Alerts (Type '0' to finish):${NC}"
        python3 -c "import json; d=json.load(open('$CONFIG')); [print(f'{i+1}) [{\"ON\" if v else \"OFF\"}] {k}') for i, (k, v) in enumerate(d['alerts'].items()) if k != 'settings_adjusted']"
        read -p "> " t_opt
        [[ "$t_opt" == "0" ]] || [[ -z "$t_opt" ]] && break
        key=$(python3 -c "import json; d=json.load(open('$CONFIG')); keys=[k for k in d['alerts'].keys() if k != 'settings_adjusted']; print(keys[$t_opt-1])")
        python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4)"
    done

    echo -e "\n${GREEN}✅ SETUP COMPLETE!${NC}"
    echo "To access this menu later, run: cd ~/.webmonitor && ./webmonitor.sh"
    python3 monitor.py --alert "service_restarted"
    nohup python3 monitor.py >> "$HOME/.webmonitor/log.txt" 2>&1 &
fi

# --- FULL DASHBOARD LOGIC ---
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
                1) read -p "New Sender Gmail: " n_em; read -p "New App Password: " n_pw
                   n_pw=$(echo $n_pw | tr -d ' ')
                   if python3 monitor.py --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                   else echo -e "${RED}❌ Verification failed.${NC}"; fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   save_val "recipient_email" "'$n_r'"; python3 monitor.py --alert "recipient_changed" "$n_r" "$old_r" ;;
                3) read -p "Enable CC Mode? (y/n): " confirm; new_cc=""; [[ "$confirm" =~ ^[Yy]$ ]] && new_cc="$(get_val sender_email)"
                   save_val "cc_email" "'$new_cc'"; python3 monitor.py --alert "settings_adjusted" "CC Mode changed." ;;
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
            python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4)"
           done ;;
        4) python3 monitor.py --alert "service_restarted"; pkill -f monitor.py; nohup python3 monitor.py >> "$HOME/.webmonitor/log.txt" 2>&1 &
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) echo -e "${RED}⚠️  UNINSTALLATION${NC}"; read -p "Delete everything? (y/n): " un
           if [[ "$un" =~ ^[Yy]$ ]]; then
               pkill -f monitor.py; crontab -r; rm -rf "$HOME/.webmonitor"; exit
           fi ;;
    esac
done
