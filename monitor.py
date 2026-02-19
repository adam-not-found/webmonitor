import os, json, time, subprocess, smtplib, re, sys
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def clean(text):
    """Removes invisible newlines/spaces that cause SMTP errors."""
    return str(text).strip() if text else ""

def send_email(subject, body, config):
    recipient = clean(config.get('recipient_email'))
    sender = clean(config.get('sender_email'))
    password = clean(config.get('app_password'))
    
    if not recipient or "@" not in recipient:
        print("❌ Error: Valid recipient email missing.")
        return
    
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = clean(subject)
    msg['From'] = sender
    msg['To'] = recipient
    if config.get('cc_email'): 
        msg['Cc'] = clean(config['cc_email'])
    
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(sender, password)
            smtp.send_message(msg)
            print(f"✅ Email Sent: {subject}")
    except Exception as e:
        print(f"❌ SMTP Error: {e}")

def handle_event(event_type, value=""):
    with open(CONFIG_PATH, 'r') as f: config = json.load(f)
    if event_type not in ["settings_adjusted", "service_restarted"]:
        if not config.get('alerts', {}).get(event_type, True): return
    
    subjects = {"word_found": f"⚠️ Trigger: {value[:30]}", "service_restarted": "🔄 Service Restarted"}
    subject = subjects.get(event_type, "🛡️ WebMonitor Alert")
    send_email(subject, f"Time: {datetime.now()}\nDetails: {value}", config)

if len(sys.argv) > 1 and sys.argv[1] == "--alert":
    handle_event(sys.argv[2], sys.argv[3] if len(sys.argv)>3 else "")
    sys.exit()

print("🚀 Engine Started. Watching Safari... (Ctrl+C to stop)")
LAST_TITLE = ""
while True:
    try:
        with open(CONFIG_PATH, 'r') as f: config = json.load(f)
        cmd = 'tell application "Safari" to tell front window to tell current tab to return {name, URL}'
        out = subprocess.check_output(['osascript', '-e', cmd]).decode().strip().split(", ")
        if len(out) < 2: continue
        title, url = out[0], out[1]
        
        if title != LAST_TITLE:
            print(f"👀 Scanning: {title[:50]}...")
            is_whitelisted = any(clean(s).lower() in url.lower() for s in config.get('whitelist', []))
            
            if not is_whitelisted:
                for word in config.get('trigger_words', []):
                    clean_word = clean(word).lower()
                    if clean_word and clean_word in title.lower():
                        print(f"🎯 MATCH FOUND: {clean_word}")
                        os.system('afplay /System/Library/Sounds/Glass.aiff')
                        handle_event("word_found", f"Word: {clean_word}\nURL: {url}")
                        break
            LAST_TITLE = title
    except Exception as e:
        print(f"⚠️ Loop Error: {e}")
    time.sleep(2)
