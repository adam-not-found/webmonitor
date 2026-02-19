import os, json, time, subprocess, smtplib, re, sys
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def send_email(subject, body, config, override_recipient=None):
    recipient = override_recipient if override_recipient else config['recipient_email']
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = subject
    msg['From'] = config['sender_email']
    msg['To'] = recipient
    if config.get('cc_email') and not override_recipient:
        msg['Cc'] = config['cc_email']
        
    try:
        # Using port 465 (SSL) which is generally more stable for Gmail App Passwords
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
    except Exception as e:
        # This will write errors to your log file (~/.webmonitor/log.txt)
        print(f"[{datetime.now()}] Email Error: {e}")

def handle_event(event_type, value="", old_val=""):
    if not os.path.exists(CONFIG_PATH): return
    with open(CONFIG_PATH, 'r') as f:
        config = json.load(f)
    
    # Mandatory bypass: Security alerts send regardless of toggles
    is_security = event_type in ["settings_adjusted", "recipient_changed"]
    if not is_security:
        if not config.get('alerts', {}).get(event_type, True): return

    subjects = {
        "word_found": f"⚠️ Trigger Detected: {value}",
        "added_trigger_words": "➕ Trigger Word Added",
        "removed_trigger_words": "➖ Trigger Word Removed",
        "added_whitelist": "⚪ Whitelist Added",
        "removed_whitelist": "⚫ Whitelist Removed",
        "service_restarted": "🔄 Service Restarted",
        "service_stopped": "🛑 Service Stopped",
        "recipient_changed": "📧 Recipient Email Changed",
        "settings_adjusted": "⚙️ Security Settings Modified"
    }
    
    subject = subjects.get(event_type, "🛡️ WebMonitor Notification")
    body = f"Alert: {subject}\nTime: {datetime.now()}\nDetails: {value}"
    
    if event_type == "recipient_changed":
        send_email(subject, f"Recipient changed from {old_val} to {value}", config, old_val)
        
    send_email(subject, body, config)

if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "", sys.argv[4] if len(sys.argv)>4 else "")
    sys.exit()

LAST_TITLE = ""
while True:
    try:
        with open(CONFIG_PATH, 'r') as f: config = json.load(f)
        cmd = 'tell application "Safari" to tell document 1 to return {name, URL}'
        out = subprocess.check_output(['osascript', '-e', cmd]).decode().strip().split(", ")
        title, url = out[0], out[1] if len(out)>1 else ""
        if title and title != LAST_TITLE:
            if not any(s.lower() in url.lower() for s in config.get('whitelist', [])):
                for word in config['trigger_words']:
                    if re.search(r'\b' + re.escape(word.lower()) + r'\b', title.lower()):
                        handle_event("word_found", f"Word: {word}\nTitle: {title}\nURL: {url}")
                        LAST_TITLE = title
                        break
    except: pass
    time.sleep(3)
