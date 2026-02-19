import os, json, time, subprocess, smtplib, re, sys
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def clean(text):
    return str(text).strip().replace('\n', '').replace('\r', '') if text else ""

def send_email(subject, body, config, target_email=None, alt_creds=None):
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
    
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(sender, password)
            smtp.send_message(msg)
            print(f"\n✅ Email Sent: {msg['Subject']}")
            return True
    except: return False

def handle_event(event_type, value="", old_val=""):
    if not os.path.exists(CONFIG_PATH): return
    with open(CONFIG_PATH, 'r') as f: config = json.load(f)
    
    mandatory = ["settings_adjusted", "recipient_changed", "service_restarted", "service_stopped"]
    if event_type not in mandatory:
        if not config.get('alerts', {}).get(event_type, True): return

    subjects = {
        "word_found": f"🚨 TRIGGER DETECTED: {value.splitlines()[0].split(': ')[1] if 'word_found' == event_type else ''}",
        "recipient_changed": "📧 ATTENTION: Alert Recipient Modified",
        "settings_adjusted": "⚙️ WebMonitor Configuration Changed",
        "service_restarted": "🔄 WebMonitor Engine Restarted",
        "service_stopped": "🛑 WARNING: WebMonitor Service Stopped"
    }
    
    raw_sub = subjects.get(event_type, "🛡️ WebMonitor Notification")
    now_str = datetime.now().strftime("%b %d at %I:%M%p")

    if event_type == "word_found":
        body = f"An automated scan detected a restricted keyword on {now_str}.\n\n{value}"
    elif event_type == "recipient_changed":
        body = f"The primary alert recipient was updated on {now_str}.\n\nOLD RECIPIENT: {old_val}\nNEW RECIPIENT: {value}\n\nNotifications will now be sent to the new address."
    elif event_type == "service_restarted":
        body = f"The WebMonitor engine was manually restarted on {now_str}. All monitoring is now active with the latest settings."
    else:
        body = f"A setting was adjusted on {now_str}.\n\n{value}"
    
    if event_type == "recipient_changed":
        send_email(raw_sub, body, config, target_email=old_val)
        send_email(raw_sub, body, config, target_email=value)
    else:
        send_email(raw_sub, body, config)

if len(sys.argv) > 1 and sys.argv[1] == "--test-creds":
    test_sender, test_pass, test_rec = sys.argv[2], sys.argv[3], sys.argv[4]
    with open(CONFIG_PATH, 'r') as f: cfg = json.load(f)
    success = send_email("🛡️ Connection Verified", "Credentials confirmed.", cfg, target_email=test_rec, alt_creds=(test_sender, test_pass))
    sys.exit(0 if success else 1)

if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>4 else "", sys.argv[4] if len(sys.argv)>4 else "")
    sys.exit()

LAST_TITLE = ""
while True:
    try:
        with open(CONFIG_PATH, 'r') as f: config = json.load(f)
        cmd = 'tell application "Safari" to tell front window to tell current tab to return {name, URL}'
        out = subprocess.check_output(['osascript', '-e', cmd]).decode().strip().split(", ")
        if len(out) < 2: continue
        title, url = out[0], out[1]
        
        if title != LAST_TITLE:
            LAST_TITLE = title
            is_whitelisted = any(clean(s).lower() in url.lower() for s in config.get('whitelist', []))
            if not is_whitelisted:
                for word in config.get('trigger_words', []):
                    clean_w = clean(word).lower()
                    if re.search(r'\b' + re.escape(clean_w) + r'\b', title.lower()):
                        os.system(f'osascript -e \'display notification "Trigger word detected: {word}" with title "🛡️ WebMonitor Alert" sound name "Glass"\'')
                        handle_event("word_found", f"Trigger Word: {word}\nPage Title: {title}\nURL: {url}")
                        break
    except: pass
    time.sleep(3)
