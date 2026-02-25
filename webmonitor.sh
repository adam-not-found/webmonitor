#!/bin/bash
BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
CONFIG="$HOME/.webmonitor/config.json"

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- SETUP WIZARD (Only runs if config is missing or sender is empty) ---
if [ ! -f "$CONFIG" ] || [ "$(get_val sender_email)" == "" ] || [ "$(get_val sender_email)" == "None" ]; then
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
    echo -e "\n${GREEN}✅ SETUP COMPLETE! Launching Dashboard...${NC}"
fi

# --- FULL DASHBOARD LOGIC STARTS HERE ---
# (Rest of the dashboard code follows...)
