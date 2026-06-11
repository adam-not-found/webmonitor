#!/bin/bash
clear

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
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.webmonitor.plist"

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- SETUP WIZARD ---
if [ ! -f "$CONFIG" ] || [ "$(get_val sender_email)" == "" ] || [ "$(get_val sender_email)" == "None" ]; then
    echo -e "${CYAN}🛡️  WEBMONITOR FIRST-TIME SETUP${NC}"
    echo "=================================="
    mkdir -p "$HOME/.webmonitor"
    echo '{"menu_bar_icon": "🦉", "sender_email":"","app_password":"","recipient_email":"","cc_email":"","whitelist":[],"trigger_words":[],"alerts":{"word_found":true,"added_trigger_words":true,"removed_trigger_words":true,"added_whitelist":true,"removed_whitelist":true,"service_restarted":true,"service_stopped":true,"recipient_changed":true}}' > "$CONFIG"
    
    # 1. RECIPIENT
    echo -e "\n${PURPLE}Step 1: The 'Recipient' Account${NC}"
    echo "This is the person who will receive the alerts."
    read -p "Enter Recipient Email: " n_rec
    save_val "recipient_email" "'$n_rec'"
    
    # 2. SENDER GUIDE
    echo -e "\n${YELLOW}Step 2: The 'Sender' Account (Gmail)${NC}"
    echo "This account physically sends the emails."
    
    while true; do
        read -p "Enter SENDER Gmail: " n_snd
        echo "1. Go to: https://myaccount.google.com/apppasswords"
        echo "2. Create an App Password named 'WebMonitor'."
        echo "3. Copy the 16-character code."
        read -p "Enter App Password: " n_pw
        n_pw=$(echo $n_pw | tr -d ' ')
        
        if python3 "$HOME/.webmonitor/monitor.py" --test-creds "$n_snd" "$n_pw" "$n_rec"; then
            save_val "sender_email" "'$n_snd'"; save_val "app_password" "'$n_pw'"
            
            echo -e "\n${CYAN}Step 3: Visibility${NC}"
            read -p "CC yourself on all alerts? (y/n): " n_cc
            [[ "$n_cc" =~ ^[Yy]$ ]] && save_val "cc_email" "'$n_snd'"
            break
        else
            echo -e "${RED}❌ Connection Failed. Check your App Password configuration.${NC}"
        fi
    done

    echo -e "${GREEN}✅ First-time setup complete!${NC}"
    
    # Automatically bootstrap the engine with the fresh config
    echo -e "${YELLOW}Initializing daemon with new configuration...${NC}"
    launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
    sleep 1.5
    launchctl bootstrap gui/$(id -u) "$PLIST_PATH"
    open -g "swiftbar://refreshall"
fi # Closes the inner setup block

# --- SWIFTBAR FIRST-LAUNCH ACTIVATION ---
echo -e "\n${CYAN}[ Finalizing SwiftBar Automation... ]${NC}"
pkill -x "SwiftBar" 2>/dev/null

# Inject preferences directly
mkdir -p "$HOME/Library/Preferences"
cat << EOF > /tmp/app.swiftbar.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CheckForUpdates</key>
    <false/>
    <key>MakeSharedPluginsFolder</key>
    <false/>
    <key>PluginDirectory</key>
    <string>~/.webmonitor</string>
    <key>StreamlineSwiftBarMenu</key>
    <true/>
</dict>
</plist>
EOF

defaults import app.swiftbar /tmp/app.swiftbar.plist
rm -f /tmp/app.swiftbar.plist
killall cfprefsd 2>/dev/null
open -a "SwiftBar" 2>/dev/null

echo -e "${GREEN}✔ SwiftBar configuration successfully mapped.${NC}"
echo -e "${YELLOW}====================================================${NC}"
echo -e " NOTICE: If your owl (🦉) is not visible in the menu bar:"
echo -e " Press ${CYAN}Cmd + Space${NC}, type ${GREEN}SwiftBar${NC}, and press Enter to wake it."
echo -e "${YELLOW}====================================================${NC}"
read -p "Press [Enter] to open your new WebMonitor Dashboard..."
fi # Closes the outer first-time setup block

# --- FULL DASHBOARD ---
manage_list() {
    local key=$1; local name=$2
    local toggle_add="added_$key"
    local toggle_rm="removed_$key"
    
    while true; do
        echo -e "\n${BLUE}--- MANAGE $name ---${NC}"
        items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))" 2>/dev/null))
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
                   python3 "$HOME/.webmonitor/monitor.py" --alert "settings_adjusted" "You added '$val' to the $name list." "" "$toggle_add"
               done ;;
            [Rr]*)
               while true; do
                   items=($(python3 -c "import json; d=json.load(open('$CONFIG')); print(' '.join(sorted(d['$key'])))" 2>/dev/null))
                   echo -e "${RED}Removing $name (Type '0' to stop)${NC}"
                   for i in "${!items[@]}"; do echo "$((i+1))) ${items[$i]}"; done
                   read -p "Enter number: " num
                   [[ "$num" == "0" ]] && break
                   
                   idx=$((num-1))
                   item_to_rm=${items[$idx]}
                   if [[ -n "$item_to_rm" ]]; then
                       python3 -c "import json; d=json.load(open('$CONFIG')); d['$key'].remove('$item_to_rm'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                       python3 "$HOME/.webmonitor/monitor.py" --alert "settings_adjusted" "You removed '$item_to_rm' from the $name list." "" "$toggle_rm"
                       echo -e "Removed: $item_to_rm"
                   else
                       echo -e "Invalid selection."
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
                   if python3 "$HOME/.webmonitor/monitor.py" --test-creds "$n_em" "$n_pw" "$(get_val recipient_email)"; then
                       save_val "sender_email" "'$n_em'"; save_val "app_password" "'$n_pw'"
                   fi ;;
                2) old_r=$(get_val recipient_email); read -p "New Recipient: " n_r
                   save_val "recipient_email" "'$n_r'"
                   python3 "$HOME/.webmonitor/monitor.py" --alert "recipient_changed" "$n_r" "$old_r" ;;
                3) read -p "Enable CC? (y/n): " confirm; new_cc=""; [[ "$confirm" =~ ^[Yy]$ ]] && new_cc="$(get_val sender_email)"
                   save_val "cc_email" "'$new_cc'"
                   python3 "$HOME/.webmonitor/monitor.py" --alert "settings_adjusted" "CC Mode modified." ;;
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
            python3 "$HOME/.webmonitor/monitor.py" --alert "settings_adjusted" "Alert toggle '$key' changed to: $status"
           done ;;
        4) echo -e "${YELLOW}Cycling native daemon service...${NC}"
           # 1. Ensure the LaunchAgents directory physically exists (critical for fresh Macs)
           mkdir -p "$(dirname "$PLIST_PATH")"
           
           # 2. Dynamically locate the correct Python interpreter path
           TARGET_PYTHON=$(which python3)
           if [[ "$TARGET_PYTHON" == "/usr/bin/python3" ]] && [ -f "/Library/Frameworks/Python.framework/Versions/Current/bin/python3" ]; then
               TARGET_PYTHON="/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
           fi

           # 3. Dynamically build/refresh the plist file to guarantee it exists and is accurate
           cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.webmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_PYTHON</string>
        <string>${HOME}/.webmonitor/monitor.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.webmonitor/output.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.webmonitor/error.log</string>
</dict>
</plist>
EOF
           chmod 644 "$PLIST_PATH"

           # 4. Cleanly cycle the launchd engine slot
           launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
           sleep 1.5
           launchctl bootstrap gui/$(id -u) "$PLIST_PATH"
           
           # 5. Fire telemetry alert using the matching executable context
           $TARGET_PYTHON "$HOME/.webmonitor/monitor.py" --alert "service_restarted"
           echo -e "${GREEN}✅ Engine Successfully Restarted.${NC}" ;;
           
        5) read -p "⚠️ ARE YOU SURE? This will stop the monitor and delete all settings. (y/n): " confirm
           if [[ "$confirm" =~ ^[Yy]$ ]]; then
               python3 "$HOME/.webmonitor/monitor.py" --alert "service_stopped" "The user has initiated a full uninstallation."
               launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
               rm -f "$PLIST_PATH"
               rm -rf "$HOME/.webmonitor"
               echo -e "${RED}🛑 Engine stopped and local assets removed.${NC}"
               exit
           fi ;;
    esac
done
