import os, json, time, subprocess, smtplib, re, sys, uuid
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
    
    unique_body = f"{body}\n\nReference ID: {uuid.uuid4().hex[:8]}"
    msg = EmailMessage()
    msg.set_content(unique_body)
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
    subjects = {
        "word_found": "🚨 SECURITY ALERT: Restricted Content Detected",
        "recipient_changed": "📧 ATTENTION: Alert Recipient Modified",
        "settings_adjusted": "⚙️ WebMonitor Configuration Changed",
        "service_restarted": "🔄 WebMonitor Engine Restarted",
        "service_stopped": "🛑 WARNING: WebMonitor Service Stopped"
    }
    subject = subjects.get(event_type, "🛡️ WebMonitor Notification")
    if event_type == "word_found":
        body = f"CONTENT DETECTED:\n{value}\n\nTime of Event: {datetime.now()}"
    else:
        body = f"DETAILS: {value}\n\nTime: {datetime.now()}"
    
    if event_type == "recipient_changed":
        send_email(subject, body, config, target_email=old_val)
        send_email(subject, body, config, target_email=value)
    else:
        send_email(subject, body, config)

if len(sys.argv) > 1 and sys.argv[1] == "--test-creds":
    test_sender, test_pass, test_rec = sys.argv[2], sys.argv[3], sys.argv[4]
    with open(CONFIG_PATH, 'r') as f: cfg = json.load(f)
    success = send_email("🛡️ WebMonitor: Connection Verified", "Credentials confirmed.", cfg, target_email=test_rec, alt_creds=(test_sender, test_pass))
    sys.exit(0 if success else 1)

if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "", sys.argv[4] if len(sys.argv)>4 else "")
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
                    if clean(word).lower() in title.lower():
                        # UNIFIED NOTIFICATION AND SOUND
                        os.system(f'osascript -e \'display notification "Trigger word detected: {word}" with title "🛡️ WebMonitor Alert" sound name "Glass"\'')
                        
                        # BACKGROUND EMAIL
                        handle_event("word_found", f"Trigger Word: {word}\nPage Title: {title}\nURL: {url}")
                        break
    except: pass
    time.sleep(3)
