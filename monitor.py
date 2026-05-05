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

    subjects = {
        "word_found": f"🚨 TRIGGER DETECTED: {value.splitlines()[0].split(': ')[1] if 'word_found' == event_type else ''}",
        "recipient_changed": "📧 ATTENTION: Alert Recipient Modified",
        "settings_adjusted": "⚙️ WebMonitor Configuration Changed",
        "service_restarted": "🔄 WebMonitor Engine Restarted",
        "service_stopped": "🛑 WARNING: WebMonitor Service Stopped"
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
    else:
        body = f"A manual configuration update occurred on {now_str}.\n\n{value}"
    
    if event_type == "recipient_changed":
        send_email(raw_sub, body, config, target_email=old_val)
        send_email(raw_sub, body, config, target_email=value)
    else:
        send_email(raw_sub, body, config, image_path=shot_path)
    
    if shot_path and os.path.exists(shot_path):
        os.remove(shot_path)

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
    last_title = ""
    last_typed = ""
    last_trigger_context = ""
    
    while True:
        try:
            with open(CONFIG_PATH, 'r') as f: config = json.load(f)
            
            ascript = '''
            tell application "Safari"
                if it is running and (count windows) > 0 then
                    tell front window to tell current tab
                        set theTitle to name
                        set theURL to URL
                        set theTyped to ""
                        try
                            tell application "System Events" to tell process "Safari"
                                set focusedElement to value of attribute "AXFocusedUIElement"
                                set theTyped to value of focusedElement as string
                            end tell
                        end try
                        return theTitle & "||" & theURL & "||" & theTyped
                    end tell
                else
                    return ""
                end if
            end tell
            '''
            
            out_raw = subprocess.check_output(['osascript', '-e', ascript]).decode().strip()
            if not out_raw:
                time.sleep(3)
                continue
                
            parts = out_raw.split("||")
            title, url, typed_text = parts[0], parts[1], parts[2] if len(parts) > 2 else ""

            is_new_page = title != last_title
            is_new_typing = typed_text != last_typed and typed_text != ""
            
            if is_new_page or is_new_typing:
                last_title = title
                last_typed = typed_text
                
                is_whitelisted = any(clean(s).lower() in url.lower() for s in config.get('whitelist', []))
                
                if not is_whitelisted:
                    for word in config.get('trigger_words', []):
                        clean_w = clean(word).lower()
                        pattern = r'\b' + re.escape(clean_w) + r'\b'
                        
                        found_in_title = re.search(pattern, title.lower())
                        found_in_url = re.search(pattern, url.lower())
                        
                        found_in_typing = False
                        if typed_text:
                            found_in_typing = re.search(pattern, typed_text.lower())
                        
                        if found_in_title or found_in_url or found_in_typing:
                            current_context = f"{clean_w}|{url if not found_in_typing else typed_text}"
                            
                            if current_context != last_trigger_context:
                                last_trigger_context = current_context
                                
                                loc = "Title/URL" if (found_in_title or found_in_url) else "Typed Text"
                                os.system(f'osascript -e \'display notification "Trigger: {word}" with title "🛡️ WebMonitor"\'')
                                handle_event("word_found", f"Trigger Word: {word}\nLocation: {loc}\nPage: {title}\nURL: {url}\nInput: {typed_text}")
                            break
                else:
                    last_trigger_context = ""
            
        except Exception:
            pass
            
        time.sleep(3)

if __name__ == "__main__":
    monitor_loop()
