import os, json, time, subprocess, smtplib
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")
LAST_ALERT = {}

def send_desktop_alert(word, title):
    # This creates the macOS notification banner
    apple_script = f'display notification "{title}" with title "⚠️ Trigger Detected: {word}"'
    subprocess.run(['osascript', '-e', apple_script])

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
    safari_cmd = 'tell application "Safari" to get name of window 1'
    try:
        return subprocess.check_output(['osascript', '-e', safari_cmd]).decode().strip()
    except: return ""

while True:
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                config = json.load(f)
            
            current_title = get_window_title()
            for word in config['trigger_words']:
                if word.lower() in current_title.lower():
                    now = time.time()
                    # COOLDOWN REDUCED TO 5 SECONDS
                    if word not in LAST_ALERT or (now - LAST_ALERT[word]) > 5:
                        print(f"🎯 MATCH: {word}")
                        send_desktop_alert(word, current_title)
                        send_email(word, current_title, config)
                        LAST_ALERT[word] = now
    except Exception as e: pass
    time.sleep(2) # Checks every 2 seconds for snappier response
