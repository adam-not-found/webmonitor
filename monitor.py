import os, json, time, subprocess, smtplib, re
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")
LAST_ALERT_TITLE = ""

def send_desktop_alert(word, title):
    script = f'display notification "{title}" with title "Trigger word: {word}" sound name "Glass"'
    subprocess.run(['osascript', '-e', script])

def send_email(word, title, url, timestamp, config):
    msg = EmailMessage()
    content = f"⚠️ WebMonitor Alert Details:\n--------------------------\nTrigger Word: {word}\nWindow Title: {title}\nURL:          {url}\nTime:         {timestamp}\n--------------------------"
    msg.set_content(content)
    msg['Subject'] = f"⚠️ WebMonitor Alert: {word}"
    msg['From'] = config['sender_email']
    msg['To'] = config['recipient_email']
    if config.get('cc_email'): msg['Cc'] = config['cc_email']
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
    except Exception as e:
        with open(os.path.expanduser("~/.webmonitor/error.txt"), "a") as f:
            f.write(f"Email failed: {e}\n")

def get_safari_data():
    cmd = 'tell application "Safari" to tell document 1 to return {name, URL}'
    try:
        output = subprocess.check_output(['osascript', '-e', cmd]).decode().strip()
        parts = output.split(", ")
        return parts[0], parts[1] if len(parts) > 1 else "Unknown URL"
    except: return "", ""

while True:
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                config = json.load(f)
            
            title, url = get_safari_data()
            
            if title and title != LAST_ALERT_TITLE:
                for word in config['trigger_words']:
                    # regex \b matches "word boundaries" (spaces, dots, start/end of line)
                    if re.search(r'\b' + re.escape(word.lower()) + r'\b', title.lower()):
                        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        send_desktop_alert(word, title)
                        send_email(word, title, url, timestamp, config)
                        LAST_ALERT_TITLE = title
                        break 
    except Exception: pass
    time.sleep(3)
