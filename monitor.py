import subprocess, time, json, smtplib, os, re, urllib.parse
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def send_email(subject, content):
    config = load_config()
    msg = EmailMessage()
    msg['Subject'] = f"🛡️ WebMonitor: {subject}"
    msg['From'] = config['sender_email']
    msg['To'] = config['recipient_email']
    msg['Cc'] = config['cc_email']
    msg.set_content(content)
    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
    except Exception as e:
        print(f"Email Error: {e}")

def get_active_browser_content():
    script = """
    tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
    end tell
    if frontApp is "Safari" then
        tell application "Safari" to return URL of front document
    else if frontApp is "Google Chrome" then
        tell application "Google Chrome" to return URL of active tab of front window
    else
        return "None"
    end if
    """
    try:
        res = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
        return res if res != "" else "None"
    except: return "None"

def clean_display_text(raw_content):
    if raw_content.startswith("http"):
        match = re.search(r'[?&](q|query)=([^&]+)', raw_content)
        if match:
            query = urllib.parse.unquote(match.group(2)).replace('+', ' ')
            return f"Search: {query}"
        try:
            domain = raw_content.split('/')[2]
            return f"Visit: {domain}"
        except: return raw_content
    return raw_content

last_flagged_content = set()

if __name__ == "__main__":
    print("🛡️  Live Monitor Engine Started (Window Detection)")
    while True:
        try:
            config = load_config()
            content = get_active_browser_content()
            
            if content != "None":
                content_lower = content.lower()
                
                # Check Whitelist
                if any(site in content_lower for site in config['whitelist'] if site):
                    time.sleep(4); continue

                # Check Keywords
                if content not in last_flagged_content:
                    for k in config['trigger_words']:
                        if not k: continue
                        
                        pattern = rf"(^|[^a-zA-Z0-9]){re.escape(k.lower())}($|[^a-zA-Z0-9])"
                        if re.search(pattern, content_lower):
                            activity = clean_display_text(content)
                            print(f"🎯 MATCH: {k}")
                            
                            # Desktop Notification
                            subprocess.run(['osascript', '-e', f'display notification "{activity}" with title "🚨 Triggered: {k}" sound name "Basso"'])
                            
                            # Email Alert
                            email_body = f"Activity: {activity}\nKeyword Detected: {k}\n\nFull Source:\n{content}"
                            send_email(f"🚨 ALERT: {k} Detected", email_body)
                            
                            last_flagged_content.add(content)
                            break
        except Exception as e:
            print(f"Loop Error: {e}")
        time.sleep(4)
