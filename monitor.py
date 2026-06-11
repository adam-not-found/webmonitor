import os
import json
import time
import subprocess
import smtplib
import re
import sys
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def clean(text):
    return str(text).strip().replace('\n', '').replace('\r', '') if text else ""

def send_email(subject, body, config, target_email=None, alt_creds=None, image_path=None):
    sender = clean(alt_creds[0] if alt_creds else config.get('sender_email'))
    password = clean(alt_creds[1] if alt_creds else config.get('app_password'))
    recipient = clean(target_email) if target_email else clean(config.get('recipient_email'))
    if not recipient or "@" not in recipient: return False
    
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = f"{clean(subject)} [{datetime.now().strftime('%H:%M:%S')}]"
    msg['From'] = sender
    msg['To'] = recipient
    if config.get('cc_email') and not target_email: msg['Cc'] = clean(config['cc_email'])
    
    if image_path and os.path.exists(image_path):
        with open(image_path, 'rb') as f:
            file_data = f.read()
        msg.add_attachment(file_data, maintype='image', subtype='png', filename="screenshot.png")
    
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(sender, password)
            smtp.send_message(msg)
            return True
    except: return False

def handle_event(event_type, value="", old_val="", toggle_key=None):
    if not os.path.exists(CONFIG_PATH): return
    with open(CONFIG_PATH, 'r') as f: config = json.load(f)
    
    target = toggle_key if toggle_key else event_type
    mandatory = ["recipient_changed", "service_restarted", "service_stopped", "settings_adjusted"]
    
    if target not in mandatory:
        if not config.get('alerts', {}).get(target, True):
            return

    # Expanded subjects for specific configuration tracking
    subjects = {
        "word_found": f"🚨 TRIGGER DETECTED: {value.splitlines()[0].split(': ')[1] if 'word_found' == event_type and value else ''}",
        "recipient_changed": "📧 ATTENTION: Alert Recipient Modified",
        "settings_adjusted": "⚙️ WebMonitor Configuration Changed",
        "service_restarted": "🔄 WebMonitor Engine Restarted",
        "service_stopped": "🛑 WARNING: WebMonitor Service Stopped",
        "added_trigger_words": "➕ WebMonitor: Trigger Word Added",
        "removed_trigger_words": "➖ WebMonitor: Trigger Word Removed",
        "added_whitelist": "⚪ WebMonitor: Whitelist Domain Added",
        "removed_whitelist": "⚫ WebMonitor: Whitelist Domain Removed"
    }
    
    raw_sub = subjects.get(event_type, "🛡️ WebMonitor Notification")
    now_str = datetime.now().strftime("%b %d at %I:%M%p")

    shot_path = None
    if event_type == "word_found":
        body = f"An automated scan detected a restricted keyword on {now_str}.\n\n{value}"
        shot_path = os.path.expanduser("~/.webmonitor/alert.png")
        os.system(f"/usr/sbin/screencapture -x {shot_path}")
    elif event_type == "recipient_changed":
        body = f"The primary alert recipient was updated on {now_str}.\n\nOLD RECIPIENT: {old_val}\nNEW RECIPIENT: {value}"
    elif event_type == "service_restarted":
        body = f"The WebMonitor engine was manually restarted on {now_str}."
    elif event_type in ["added_trigger_words", "removed_trigger_words", "added_whitelist", "removed_whitelist"]:
        action_map = {
            "added_trigger_words": "Added Trigger Word(s)",
            "removed_trigger_words": "Removed Trigger Word",
            "added_whitelist": "Added Whitelist Domain(s)",
            "removed_whitelist": "Removed Whitelist Domain"
        }
        body = f"A manual list modification occurred on {now_str}.\n\nAction: {action_map[event_type]}\nDetail/Value: {value}"
    else:
        body = f"A manual configuration update occurred on {now_str}.\n\n{value}"
    
    if event_type == "recipient_changed":
        send_email(raw_sub, body, config, target_email=old_val)
        send_email(raw_sub, body, config, target_email=value)
    else:
        send_email(raw_sub, body, config, image_path=shot_path)
    
    if shot_path and os.path.exists(shot_path):
        os.remove(shot_path)
```[cite: 39]

---

### 2. Update `webmonitor_9.sh`
To handle structural input sanitization, value extraction, and a quiet daemon bounce, declare a silent engine restart function at the top of your script next to your environment functions[cite: 43]:

```bash
silent_engine_restart() {
    launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null
    sleep 1.0
    launchctl bootstrap gui/$(id -u) "$PLIST_PATH" 2>/dev/null
    open -g "swiftbar://refreshall" 2>/dev/null
}
```[cite: 43]

Then, swap your entire Option `2` block case section inside `webmonitor_9.sh` with the following routine:

```bash
        2)
            while true; do
                clear
                echo -e "\n${CYAN}[ Trigger Words & Whitelist ]${NC}"
                echo "0) Go Back to Main Menu"
                echo "1) View Lists"
                echo "2) Add Trigger Word(s)"
                echo "3) Remove Trigger Word (by number)"
                echo "4) Add Whitelist Domain(s)"
                echo "5) Remove Whitelist Domain (by number)"
                read -p "Choose sub-option (0-5): " sub_opt
                
                if [ "$sub_opt" == "0" ]; then
                    break
                elif [ "$sub_opt" == "1" ]; then
                    echo -e "\n${YELLOW}Trigger Words:${NC}"
                    python3 -c "import json; [print(f'{i+1}) {w}') for i,w in enumerate(json.load(open('$CONFIG'))['trigger_words'])]"
                    echo -e "\n${YELLOW}Whitelist:${NC}"
                    python3 -c "import json; [print(f'{i+1}) {w}') for i,w in enumerate(json.load(open('$CONFIG'))['whitelist'])]"
                    read -p "Press [Enter] to return..."
                elif [ "$sub_opt" == "2" ]; then
                    echo "Enter words to add (type '0' when finished):"
                    added_words=""
                    while true; do
                        read -p "Word: " new_word
                        if [ "$new_word" == "0" ] || [ -z "$new_word" ]; then break; fi
                        
                        # Input Sanitization: strip spaces, convert to uniform lowercase
                        clean_word=$(echo "$new_word" | xargs | tr '[:upper:]' '[:lower:]')
                        if [ ! -z "$clean_word" ]; then
                            python3 -c "import json; d=json.load(open('$CONFIG')); d['trigger_words'].append('$clean_word') if '$clean_word' not in d['trigger_words'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
                            added_words="$added_words $clean_word"
                        fi
                    done
                    if [ ! -z "$added_words" ]; then
                        added_words=$(echo "$added_words" | xargs)
                        python3 "$HOME/.webmonitor/monitor.py" --alert "added_trigger_words" "$added_words" 2>/dev/null
                        silent_engine_restart
                    fi
                elif [ "$sub_opt" == "3" ]; then
                    while true; do
                        clear
                        echo -e "\n${YELLOW}Trigger Words:${NC}"
                        python3 -c "import json; [print(f'{i+1}) {w}') for i,w in enumerate(json.load(open('$CONFIG'))['trigger_words'])]"
                        read -p "Enter number to remove (or 0 to go back): " rem_num
                        if [ "$rem_num" == "0" ] || [ -z "$rem_num" ]; then break; fi
                        if [[ "$rem_num" =~ ^[0-9]+$ ]]; then
                            # Extract targeted token prior to deletion step to pass into alert context payload
                            target_val=$(python3 -c "import json; d=json.load(open('$CONFIG')); w=d['trigger_words']; print(w[$rem_num-1]) if 0<=$rem_num-1<len(w) else print('')")
                            if [ ! -z "$target_val" ]; then
                                python3 -c "import json; d=json.load(open('$CONFIG')); w=d['trigger_words']; w.remove('$target_val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                                python3 "$HOME/.webmonitor/monitor.py" --alert "removed_trigger_words" "$target_val" 2>/dev/null
                                silent_engine_restart
                                echo -e "${GREEN}✅ Word '$target_val' removed & engine refreshed.${NC}"
                                sleep 1.5
                            else
                                echo -e "${RED}Invalid index selected.${NC}"
                                sleep 1
                            fi
                        fi
                    done
                elif [ "$sub_opt" == "4" ]; then
                    echo "Enter domains to whitelist (type '0' when finished):"
                    added_doms=""
                    while true; do
                        read -p "Domain: " wl_dom
                        if [ "$wl_dom" == "0" ] || [ -z "$wl_dom" ]; then break; fi
                        
                        # Input Sanitization: strip outer whitespace, normalize domain case entries
                        clean_dom=$(echo "$wl_dom" | xargs | tr '[:upper:]' '[:lower:]')
                        if [ ! -z "$clean_dom" ]; then
                            python3 -c "import json; d=json.load(open('$CONFIG')); d['whitelist'].append('$clean_dom') if '$clean_dom' not in d['whitelist'] else None; json.dump(d, open('$CONFIG', 'w'), indent=4)"
                            added_doms="$added_doms $clean_dom"
                        fi
                    done
                    if [ ! -z "$added_doms" ]; then
                        added_doms=$(echo "$added_doms" | xargs)
                        python3 "$HOME/.webmonitor/monitor.py" --alert "added_whitelist" "$added_doms" 2>/dev/null
                        silent_engine_restart
                    fi
                elif [ "$sub_opt" == "5" ]; then
                    while true; do
                        clear
                        echo -e "\n${YELLOW}Whitelist:${NC}"
                        python3 -c "import json; [print(f'{i+1}) {w}') for i,w in enumerate(json.load(open('$CONFIG'))['whitelist'])]"
                        read -p "Enter number to remove (or 0 to go back): " rem_num
                        if [ "$rem_num" == "0" ] || [ -z "$rem_num" ]; then break; fi
                        if [[ "$rem_num" =~ ^[0-9]+$ ]]; then
                            target_val=$(python3 -c "import json; d=json.load(open('$CONFIG')); w=d['whitelist']; print(w[$rem_num-1]) if 0<=$rem_num-1<len(w) else print('')")
                            if [ ! -z "$target_val" ]; then
                                python3 -c "import json; d=json.load(open('$CONFIG')); w=d['whitelist']; w.remove('$target_val'); json.dump(d, open('$CONFIG', 'w'), indent=4)"
                                python3 "$HOME/.webmonitor/monitor.py" --alert "removed_whitelist" "$target_val" 2>/dev/null
                                silent_engine_restart
                                echo -e "${GREEN}✅ Domain '$target_val' removed & engine refreshed.${NC}"
                                sleep 1.5
                            else
                                echo -e "${RED}Invalid index selected.${NC}"
                                sleep 1
                            fi
                        fi
                    done
                fi
            done
            ;;
```[cite: 43]

# Credentials Test Route
if len(sys.argv) > 1 and sys.argv[1] == "--test-creds":
    test_sender, test_pass, test_rec = sys.argv[2], sys.argv[3], sys.argv[4]
    with open(CONFIG_PATH, 'r') as f: cfg = json.load(f)
    success = send_email("🛡️ WebMonitor: System Enabled", "Connection confirmed.\n\nMonitoring is now active.", cfg, target_email=test_rec, alt_creds=(test_sender, test_pass))
    sys.exit(0 if success else 1)

# CLI Alert Route
if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    t_key = sys.argv[5] if len(sys.argv) > 5 else None
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "", sys.argv[4] if len(sys.argv)>4 else "", toggle_key=t_key)
    sys.exit()

# ================= HEADLESS BACKGROUND LOOP =================

def monitor_loop():
    last_text = ""
    last_trigger_context = ""
    
    while True:
        try:
            with open(CONFIG_PATH, 'r') as f: config = json.load(f)
            
            # Universal AppleScript to grab text from whatever UI element currently has keyboard focus
            ascript = '''
            try
                tell application "System Events"
                    set frontProcess to first application process whose frontmost is true
                    tell frontProcess
                        set focusedElement to value of attribute "AXFocusedUIElement"
                        if class of focusedElement is text field or class of focusedElement is text area then
                            return value of focusedElement as string
                        else if exists (value of attribute "AXFocusedUIElement") then
                            return value of attribute "AXFocusedUIElement" as string
                        end if
                    end tell
                end tell
            on error
                return ""
            end try
            '''
            
            typed_text = subprocess.check_output(['osascript', '-e', ascript]).decode().strip()
            
            # Skip empty evaluations
            if not typed_text or len(typed_text) < 3:
                time.sleep(1.5)
                continue
                
            if typed_text != last_text:
                last_text = typed_text
                
                for word in config.get('trigger_words', []):
                    clean_w = clean(word).lower()
                    pattern = r'\b' + re.escape(clean_w) + r'\b'
                    
                    if re.search(pattern, typed_text.lower()):
                        try:
                            app_script = 'tell application "System Events" to get name of first application process whose frontmost is true'
                            active_app = subprocess.check_output(['osascript', '-e', app_script]).decode().strip()
                        except Exception:
                            active_app = "Active Window"

                        # Track unique triggers by mapping to the application context instead of live strings
                        current_context = f"{clean_w}|{active_app}"
                        
                        if current_context != last_trigger_context:
                            last_trigger_context = current_context
                            
                            os.system(f'osascript -e \'display notification "Trigger: {word} in {active_app}" with title "🛡️ WebMonitor"\'')
                            handle_event("word_found", f"Trigger Word: {word}\nApplication: {active_app}\nCaptured Context: {typed_text}")
                        break
                        
        except Exception:
            pass
            
        time.sleep(1.5)  # Slightly faster response time for active typing fields

if __name__ == "__main__":
    monitor_loop()
