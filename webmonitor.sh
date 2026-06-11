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

# Dynamically discover Python path to ensure it is available inside this script
TARGET_PYTHON=$(which python3)
if [[ "$TARGET_PYTHON" == "/usr/bin/python3" ]] && [ -f "/Library/Frameworks/Python.framework/Versions/Current/bin/python3" ]; then
    TARGET_PYTHON="/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
fi

get_val() { python3 -c "import json; print(json.load(open('$CONFIG'))['$1'])" 2>/dev/null; }
save_val() { python3 -c "import json; d=json.load(open('$CONFIG')); d['$1']=$2; json.dump(d, open('$CONFIG', 'w'), indent=4)" ; }

# --- SETUP WIZARD ---
if [ ! -f "$CONFIG" ] || [ "$(get_val sender_email)" == "" ] || [ "$(get_val sender_email)" == "None" ]; then
    echo -e "${CYAN}🛡️  WEBMONITOR FIRST-TIME SETUP${NC}"
    echo "=================================="
    mkdir -p "$HOME/.webmonitor"
    echo '{"menu_bar_icon": "🦉", "sender_email":"","app_password":"","recipient_email":"","cc_email":"","whitelist":[],"trigger_words":[],"alerts":{"word_found":true,"added_trigger_words":true,"removed_trigger_words":true,"service_restarted":true,"service_stopped":true,"settings_adjusted":true}}' > "$CONFIG"

    # Step 1: Emails
    read -p "Enter Sender Gmail: " s_email
    save_val "sender_email" "\"$s_email\""
    read -p "Enter Sender Gmail App Password: " s_pass
    save_val "app_password" "\"$s_pass\""
    read -p "Enter Recipient Email: " r_email
    save_val "recipient_email" "\"$r_email\""
    
    # Step 2: CC Choice
    read -p "CC yourself on all alerts? (y/n): " cc_choice
    if [[ "$cc_choice" =~ ^[Yy]$ ]]; then
        save_val "cc_email" "\"$s_email\""
    else
        save_val "cc_email" "\"\""
    fi

    echo -e "${GREEN}✅ First-time setup complete!${NC}"
    
    # Automatically bootstrap the engine with the fresh config
    echo -e "${YELLOW}Initializing daemon with new configuration...${NC}"
    launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
    sleep 1.5
    launchctl bootstrap gui/$(id -u) "$PLIST_PATH" 2>/dev/null
    open -g "swiftbar://refreshall" 2>/dev/null

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

# --- MAIN DASHBOARD LOOP ---
while true; do
    clear
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}           🛡️  WEBMONITOR DASHBOARD            ${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo -e "1) Email & Account Settings"
    echo -e "2) Trigger Words & Whitelist"
    echo -e "3) Alert Toggles"
    echo -e "4) Restart Engine"
    echo -e "5) Stop & Uninstall"
    echo -e "6) Exit"
    echo -e "${BLUE}===============================================${NC}"
    read -p "Choose an option (1-6): " opt

    case "$opt" in
        1)
            echo -e "\n${CYAN}[ Email & Account Settings ]${NC}"
            read -p "New Sender Gmail (leave blank to keep current): " s_email
            if [ ! -z "$s_email" ]; then save_val "sender_email" "\"$s_email\""; fi
            
            read -p "New App Password (leave blank to keep current): " s_pass
            if [ ! -z "$s_pass" ]; then save_val "app_password" "\"$s_pass\""; fi
            
            read -p "New Recipient Email (leave blank to keep current): " r_email
            if [ ! -z "$r_email" ]; then save_val "recipient_email" "\"$r_email\""; fi
            
            read -p "CC yourself on all alerts? (y/n): " cc_choice
            if [[ "$cc_choice" =~ ^[Yy]$ ]]; then
                curr_sender=$(get_val sender_email)
                save_val "cc_email" "\"$curr_sender\""
            elif [[ "$cc_choice" =~ ^[Nn]$ ]]; then
                save_val "cc_email" "\"\""
            fi
            echo -e "${GREEN}✅ Account settings updated.${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${CYAN}[ Trigger Words & Whitelist ]${NC}"
            echo "1) Add Trigger Word(s)"
            echo "2) Remove Trigger Word"
            echo "3) Add Whitelist Domain"
            echo "4) Remove Whitelist Domain"
            read -p "Choose sub-option (1-4): " sub_opt
            if [ "$sub_opt" == "1" ]; then
                echo "Enter words to add (type '0' when finished):"
                while true; do
                    read -p "Word: " new_word
                    if [ "$new_word" == "0" ] || [ -z "$new_word" ]; then break; fi
                    python3 -c "import json; d=json.load(open('$CONFIG')); d['trigger_words'].append('$new_word') if '$new_word' not in d['trigger_words'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
                done
                python3 "$HOME/.webmonitor/monitor.py" --alert "added_trigger_words" 2>/dev/null
            elif [ "$sub_opt" == "2" ]; then
                read -p "Enter word to remove: " rem_word
                python3 -c "import json; d=json.load(open('$CONFIG')); d['trigger_words'].remove('$rem_word') if '$rem_word' in d['trigger_words'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
                python3 "$HOME/.webmonitor/monitor.py" --alert "removed_trigger_words" 2>/dev/null
            elif [ "$sub_opt" == "3" ]; then
                read -p "Enter domain to whitelist (e.g. google.com): " wl_dom
                python3 -c "import json; d=json.load(open('$CONFIG')); d['whitelist'].append('$wl_dom') if '$wl_dom' not in d['whitelist'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
            elif [ "$sub_opt" == "4" ]; then
                read -p "Enter domain to remove from whitelist: " rem_dom
                python3 -c "import json; d=json.load(open('$CONFIG')); d['whitelist'].remove('$rem_dom') if '$rem_dom' in d['whitelist'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
            fi
            echo -e "${GREEN}✅ Word/Whitelist updates complete.${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${CYAN}[ Alert Toggles ]${NC}"
            python3 -c "import json; d=json.load(open('$CONFIG'))['alerts']; [print(f'- {k}: {\"ON\" if v else \"OFF\"}') for k,v in d.items()]"
            read -p "Enter the exact alert name to toggle: " alert_name
            python3 -c "import json; d=json.load(open('$CONFIG')); d['alerts']['$alert_name'] = not d['alerts'].get('$alert_name', True) if '$alert_name' in d['alerts'] else True; json.dump(d, open('$CONFIG', 'w'), indent=4)" 2>/dev/null
            status=$(python3 -c "import json; d=json.load(open('$CONFIG')); print('ON' if d['alerts'].get('$alert_name', False) else 'OFF')")
            python3 "$HOME/.webmonitor/monitor.py" --alert "settings_adjusted" "Alert toggle '$alert_name' changed to: $status" 2>/dev/null
            echo -e "${GREEN}✅ Alert toggle updated.${NC}"
            sleep 2
            ;;
        4)
            echo -e "\n${YELLOW}Cycling native daemon service...${NC}"
            
            # Re-generate the plist to make sure it contains the active discovered Python path
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

            # Cleanly cycle the launchd engine slot
            launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
            sleep 1.5
            launchctl bootstrap gui/$(id -u) "$PLIST_PATH" 2>/dev/null
            
            # Fire telemetry alert using the matching executable context
            $TARGET_PYTHON "$HOME/.webmonitor/monitor.py" --alert "service_restarted" 2>/dev/null
            echo -e "${GREEN}✅ Engine Successfully Restarted.${NC}"
            sleep 2
            ;;
        5)
            read -p "⚠️ ARE YOU SURE? This will stop the monitor and delete all settings. (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                $TARGET_PYTHON "$HOME/.webmonitor/monitor.py" --alert "service_stopped" "The user has initiated a full uninstallation." 2>/dev/null
                launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
                rm -f "$PLIST_PATH"
                rm -rf "$HOME/.webmonitor"
                echo -e "${RED}🛑 Engine stopped and uninstalled.${NC}"
                exit 0
            fi
            ;;
        6)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            sleep 1.5
            ;;
    esac
done
