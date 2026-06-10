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
                        current_context = f"{clean_w}|{typed_text}"
                        
                        if current_context != last_trigger_context:
                            last_trigger_context = current_context
                            
                            # Grab the name of the active app for the email alert context
                            app_script = 'tell application "System Events" to get name of first application process whose frontmost is true'
                            active_app = subprocess.check_output(['osascript', '-e', app_script]).decode().strip()
                            
                            os.system(f'osascript -e \'display notification "Trigger: {word} in {active_app}" with title "🛡️ WebMonitor"\'')
                            handle_event("word_found", f"Trigger Word: {word}\nApplication: {active_app}\nCaptured Context: {typed_text}")
                        break
                        
        except Exception:
            pass
            
        time.sleep(1.5)  # Slightly faster response time for active typing fields

if __name__ == "__main__":
    monitor_loop()
