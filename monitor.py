import sqlite3
import os
import time
import json
import smtplib
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")
HISTORY_PATH = os.path.expanduser("~/Library/Safari/History.db")

def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def send_alert(url, title, trigger):
    config = load_config()
    msg = EmailMessage()
    msg.set_content(f"⚠️ TRIGGER DETECTED\n\nTrigger Word: {trigger}\nURL: {url}\nTitle: {title}\nTime: {time.ctime()}")
    msg['Subject'] = f"🚨 WebMonitor Alert: {trigger}"
    msg['From'] = config['sender_email']
    msg['To'] = config['recipient_email']
    msg['Cc'] = config['cc_email']

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
            print(f"✅ Alert sent for: {trigger}")
    except Exception as e:
        print(f"❌ Alert failed: {e}")

def check_history():
    config = load_config()
    try:
        conn = sqlite3.connect(HISTORY_PATH)
        cursor = conn.cursor()
        # Look for visits in the last 2 minutes
        query = """
        SELECT history_items.url, history_visits.title 
        FROM history_items 
        JOIN history_visits ON history_items.id = history_visits.history_item
        WHERE history_visits.visit_time > (strftime('%s', 'now') - 120 + 978307200)
        """
        cursor.execute(query)
        results = cursor.fetchall()
        conn.close()

        for url, title in results:
            # Skip whitelisted items
            if any(site in url for site in config['whitelist']):
                continue
            
            # Check for trigger words
            for word in config['trigger_words']:
                if word.lower() in url.lower() or (title and word.lower() in title.lower()):
                    send_alert(url, title, word)
                    return # Alert once per check to avoid spam
    except Exception as e:
        print(f"Database error: {e}")

if __name__ == "__main__":
    print("🛡️ Monitoring Engine active. Press Ctrl+C to stop.")
    while True:
        check_history()
        time.sleep(60)
