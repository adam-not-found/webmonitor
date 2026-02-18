import json, os, smtplib, sys
from email.message import EmailMessage
from datetime import datetime

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def load_config():
    if not os.path.exists(CONFIG_PATH):
        print("❌ Config not found. Please run install.sh first.")
        sys.exit(1)
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def save_config(config):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4)

def send_integrity_alert(action, value):
    config = load_config()
    msg = EmailMessage()
    msg.set_content(f"🛡️ WebMonitor Security Alert\n\nAction: {action}\nValue: {value}\nTime: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\nThis is an automated integrity report.")
    msg['Subject'] = f"🛡️ WebMonitor Change: {action}"
    msg['From'] = config['sender_email']
    msg['To'] = config['recipient_email']
    msg['Cc'] = config['cc_email']

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(config['sender_email'], config['app_password'])
            smtp.send_message(msg)
            print(f"✅ Alert sent: {action}")
    except Exception as e:
        print(f"❌ Failed to send alert: {e}")

def dashboard():
    config = load_config()
    while True:
        print(f"\n--- 🛡️  WEBMONITOR DASHBOARD ---")
        print(f"1) Add Trigger Word")
        print(f"2) Remove Trigger Word")
        print(f"3) View Current Lists")
        print(f"4) Exit")
        choice = input("Select an option: ")

        if choice == '1':
            word = input("Enter word to add: ")
            if word not in config['trigger_words']:
                config['trigger_words'].append(word)
                save_config(config)
                send_integrity_alert("Trigger Word Added", word)
        elif choice == '2':
            word = input("Enter word to remove: ")
            if word in config['trigger_words']:
                config['trigger_words'].remove(word)
                save_config(config)
                send_integrity_alert("Trigger Word REMOVED", word)
            else:
                print("Word not found.")
        elif choice == '3':
            print(f"\nTrigger Words: {config['trigger_words']}")
            print(f"Whitelist: {config['whitelist']}")
        elif choice == '4':
            break

if __name__ == "__main__":
    dashboard()
