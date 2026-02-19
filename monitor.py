import os, json, time, subprocess, smtplib, re, sys
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def send_email(subject, body, config, override_recipient=None):
    recipient = override_recipient if override_recipient else config.get('recipient_email')
    if not recipient or "@" not in recipient: return
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = subject
    msg['From'] = config['sender_email']
    msg['To'] = recipient
    if config.get('cc_email') and not override_recipient: msg['Cc'] = config['cc_email']
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
    except: pass

def handle_event(event_type, value="", old_val=""):
    if not os.path.exists(CONFIG_PATH): return
    with open(CONFIG_PATH, 'r') as f: config = json.load(f)
    if event_type not in ["settings_adjusted", "recipient_changed"]:
        if not config.get('alerts', {}).get(event_type, True): return
    subjects = {
        "word_found": f"⚠️ Trigger: {value}",
        "settings_adjusted": "⚙️ Security Modified",
        "service_restarted": "🔄 Service Restarted"
    }
    subject = subjects.get(event_type, "🛡️ WebMonitor Alert")
    send_email(subject, f"Event: {subject}\nDetails: {value}\nTime: {datetime.now()}", config)

if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "", sys.argv[4] if len(sys.argv)>4 else "")
    sys.exit()

LAST_TITLE = ""
while True:
    try:
        with open(CONFIG_PATH, 'r') as f: config = json.load(f)
        # More robust AppleScript to get frontmost window
        cmd = 'tell application "Safari" to tell front window to tell current tab to return {name, URL}'
        out = subprocess.check_output(['osascript', '-e', cmd]).decode().strip().split(", ")
        if len(out) < 2: continue
        title, url = out[0], out[1]
        
        if title != LAST_TITLE:
            # Check if site is whitelisted
            is_whitelisted = any(s.lower() in url.lower() for s in config.get('whitelist', []))
            
            if not is_whitelisted:
                for word in config.get('trigger_words', []):
                    # REMOVED \b for broader matching
                    if word.lower() in title.lower():
                        handle_event("word_found", f"Found: {word}\nIn: {title}\nURL: {url}")
                        # Play system alert sound
                        os.system('afplay /System/Library/Sounds/Glass.aiff')
                        LAST_TITLE = title
                        break
            LAST_TITLE = title
    except Exception as e:
        pass
    time.sleep(3)
