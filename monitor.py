import os, json, time, subprocess, smtplib
from email.message import EmailMessage

# Configuration paths
CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")
LAST_ALERT = {}

def send_email(word, title, config):
    msg = EmailMessage()
    msg.set_content(f"Trigger word '{word}' detected in browser window: {title}")
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

def get_window_title():
    # Detects title from Safari or Chrome
    cmd = 'tell application "System Events" to get name of (processes where background read only is false and name is "Safari" or name is "Google Chrome")'
    try:
        # Simplified for testing; focuses on active Safari window
        safari_cmd = 'tell application "Safari" to get name of window 1'
        return subprocess.check_output(['osascript', '-e', safari_cmd]).decode().strip()
    except: return ""

while True:
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                config = json.load(f)
            
            title = get_window_title()
            for word in config['trigger_words']:
                if word.lower() in title.lower():
                    now = time.time()
                    # Only alert if word hasn't been seen in the last 60 seconds
                    if word not in LAST_ALERT or (now - LAST_ALERT[word]) > 60:
                        print(f"🎯 MATCH: {word}")
                        send_email(word, title, config)
                        LAST_ALERT[word] = now
    except Exception as e: pass
    time.sleep(5)
