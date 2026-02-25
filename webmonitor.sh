#!/bin/bash
# Color Palette
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- SETUP WIZARD ---
if [ ! -f "$CONFIG" ] || [ "$(get_val sender_email)" == "" ] || [ "$(get_val sender_email)" == "None" ]; then
    echo -e "${CYAN}🛡️  WEBMONITOR FIRST-TIME SETUP${NC}"
    echo "=================================="
    mkdir -p "$HOME/.webmonitor"
    echo '{"sender_email":"","app_password":"","recipient_email":"","cc_email":"","whitelist":[],"trigger_words":[],"alerts":{"word_found":true,"added_trigger_words":false,"removed_trigger_words":true,"added_whitelist":true,"removed_whitelist":false,"service_restarted":true,"service_stopped":true,"recipient_changed":true}}' > "$CONFIG"
    
    # 1. RECIPIENT
    echo -e "\n${PURPLE}Step 1: The 'Recipient' Account${NC}"
    echo "This is the person who will receive the alerts (partner/parent)."
    read -p "Enter Recipient Email: " n_rec
    save_val "recipient_email" "'$n_rec'"
    
    # 2. SENDER GUIDE
    echo -e "\n${YELLOW}Step 2: The 'Sender' Account (Gmail)${NC}"
    echo "This account physically sends the emails."
    
    while true; do
        read -p "Enter SENDER Gmail: " n_snd
        echo "1. Go to: https://myaccount.google.com/apppasswords"
        echo "2. Create a name like 'WebMonitor'."
        echo "3. Copy the 16-character code."
        read -p "Enter App Password: " n_pw
        n_pw=$(echo $n_pw | tr -d ' ')
        if python3 monitor.py --test-creds "$n_snd" "$n_pw" "$n_rec"; then
            save_val "sender_email" "'$n_snd'"; save_val "app_password" "'$n_pw'"
            
            echo -e "\n${CYAN}Step 3: Visibility${NC}"
            read -p "CC yourself on all alerts? (y/n): " n_cc
            [[ "$n_cc" =~ ^[Yy]$ ]] && save_val "cc_email" "'$n_snd'"
            break
        else
            echo -e "${RED}❌ Connection Failed. Check 2FA and App Password.${NC}"
        fi
    done

    # 3. LISTS (COLOR CODED)
    # Triggers in RED
    while true; do
        echo -e "\n${RED}Step 4: Restricted Keywords (Type '0' to finish):${NC}"
        read -p "> " item
        [[ "$item" == "0" ]] && break
        python3 -c "import json; d=json.load(open('$CONFIG')); d['trigger_words'].append('$item'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
    done

    # Whitelist in GREEN
    while true; do
        echo -e "\n${GREEN}Step 5: Whitelisted Sites (Type '0' to finish):${NC}"
        read -p "> " item
        [[ "$item" == "0" ]] && break
        python3 -c "import json; d=json.load(open('$CONFIG')); d['whitelist'].append('$item'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
    done

    echo -e "\n${GREEN}✅ SETUP COMPLETE! Launching Dashboard...${NC}"
    pkill -f monitor.py; nohup python3 monitor.py >> "$HOME/.webmonitor/log.txt" 2>&1 &
fi

# --- FULL DASHBOARD ---
manage_list() {
    local key=$1; local name=$2
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        # Fetch current items and sort them for display
        items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
        for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
        
        echo -e "\nA) Add Multiple  R) Remove Multiple  0) Back"
        read -p "Selection: " subopt
        case $subopt in
            [Aa]*)
               while true; do
                   echo -e "${GREEN}Adding $name (Type '0' to stop)${NC}"
                   read -p "> " val
                   [[ "$val" == "0" ]] && break
                   python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].append('$val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                   python3 monitor.py --alert "settings_adjusted" "You added '$val' to the $name list." "" "added_$key"
               done ;;
            [Rr]*)
               while true; do
                   # Refresh list inside the loop so numbers stay accurate as you delete
                   items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))"))
                   echo -e "${RED}Removing $name (Type '0' to stop)${NC}"
                   for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
                   read -p "Enter number: " num
                   [[ "$num" == "0" ]] && break
                   
                   idx=$((num-1))
                   item_to_rm=${items[$idx]}
                   if [[ -n "$item_to_rm" ]]; then
                       python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                       python3 monitor.py --alert "settings_adjusted" "You removed '$item_to_rm' from the $name list." "" "removed_$key"
                       echo -e "Removed: $item_to_rm"
                   else
                       echo -e "Invalid number."
                   fi
               done ;;
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
        1) # ... [Settings Logic] ...
           while true; do
            cc_status="OFF"; [[ -n "$(get_val cc_email)" ]] && cc_status="ON"
            echo -e "\n${YELLOW}--- EMAIL SETTINGS ---${NC}"
            echo "1) Sender:    $(get_val sender_email)"
            echo "2) Recipient: $(get_val recipient_email)"
            echo "3) CC Mode:   $cc_status"
            echo "0) Back"
            read -p "Selection: " e_opt
            case $e_opt in
                1) read -p "New Sender: " n_em; read -p "New PW: " n_pw
                   if python3 monitor.py --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                   fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   save_val "recipient_email" "'$n_r'"; python3 monitor.py --alert "recipient_changed" "$n_r" "$old_r" ;;
                3) read -p "Enable CC? (y/n): " confirm; new_cc=""; [[ "$confirm" =~ ^[Yy]$ ]] && new_cc="$(get_val sender_email)"
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
            status=$(python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$key']=not d['alerts']['$key']; json.dump(d, open('$CONFIG', 'w'), indent=4); print('ON' if d['alerts']['$key'] else 'OFF')")
            python3 monitor.py --alert "settings_adjusted" "Alert toggle '$key' changed to: $status"
           done ;;
        4) pkill -f monitor.py; nohup python3 monitor.py >> "$HOME/.webmonitor/log.txt" 2>&1 &
           sleep 1; python3 monitor.py --alert "service_restarted"
           echo -e "${GREEN}✅ Engine Restarted.${NC}" ;;
        5) read -p "⚠️ ARE YOU SURE? This will stop the monitor and delete all settings. (y/n): " confirm
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               python3 monitor.py --alert "service_stopped" "The user has initiated a full uninstallation."
               pkill -f monitor.py; crontab -r 2>/dev/null; cd ~ && rm -rf "$HOME/.webmonitor"
               echo -e "${RED}🛑 Uninstalled. Folder deleted.${NC}"
               exit
           fi ;;
    esac
done
