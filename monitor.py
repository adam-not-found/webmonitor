import os, json, smtplib, sys, subprocess, time, urllib.request
from datetime import datetime
from email.message import EmailMessage

CONFIG_PATH = os.path.expanduser("~/.webmonitor/config.json")

def load_config():
    with open(CONFIG_PATH, 'r') as f:
        return json.load(f)

def ensure_ollama():
    """Checks if Ollama is running; if not, starts the background service."""
    try:
        # Check if service is responsive
        urllib.request.urlopen("http://localhost:11434/api/tags", timeout=1)
    except:
        # Path to the internal binary to avoid needing the GUI app open
        binary_path = "/Applications/Ollama.app/Contents/Resources/ollama"
        if os.path.exists(binary_path):
            subprocess.Popen([binary_path, "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(5) # Give it a moment to wake up

def get_ai_analysis(word, context):
    """Asks local AI to analyze the risk level of a trigger word hit."""
    ensure_ollama()
    url = "http://localhost:11434/api/generate"
    prompt = f"Analyze this web activity. Trigger: '{word}'. Context: '{context}'. Is this a security/safety risk? 1-sentence assessment."
    
    data = json.dumps({
        "model": "llama3.2:3b",
        "prompt": prompt,
        "stream": False
    }).encode('utf-8')

    try:
        req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=15) as response:
            res = json.loads(response.read().decode('utf-8'))
            return res.get('response', 'Analysis complete.')
    except Exception as e:
        return f"AI Analysis currently offline: {e}"

def send_email(subject, body):
    conf = load_config()
    msg = EmailMessage()
    msg.set_content(body)
    msg['Subject'] = f"{subject} [{datetime.now().strftime('%H:%M:%S')}]"
    msg['From'] = conf['sender_email']
    msg['To'] = conf['recipient_email']
    if conf.get('cc_email'):
        msg['Cc'] = conf['cc_email']

    try:
        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(conf['sender_email'], conf['app_password'])
            smtp.send_message(msg)
    except Exception as e:
        with open(os.path.expanduser("~/.webmonitor/log.txt"), "a") as f:
            f.write(f"Email Error: {e}\n")

def handle_event(event_type, value="", detail="", toggle_key=None):
    conf = load_config()
    t_key = toggle_key or event_type
    if not conf.get('alerts', {}).get(t_key, True):
        return

    subjects = {
        "word_found": f"🚨 TRIGGER DETECTED: {value}",
        "settings_adjusted": "⚙️ Configuration Changed",
        "service_restarted": "🔄 Engine Restarted",
        "service_stopped": "🛑 Service Stopped",
        "recipient_changed": "📧 Recipient Updated"
    }

    content = f"Event: {event_type}\nDetail: {value}\nContext: {detail}"

    if event_type == "word_found":
        analysis = get_ai_analysis(value, detail)
        content += f"\n\n--- AI RISK ASSESSMENT ---\n{analysis}"

    send_email(subjects.get(event_type, "WebMonitor Alert"), content)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "--test-creds":
            try:
                with smtplib.SMTP_SSL('smtp.gmail.com', 465) as s:
                    s.login(sys.argv[2], sys.argv[3])
                sys.exit(0)
            except: sys.exit(1)
        elif sys.argv[1] == "--alert":
            handle_event(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv)>4 else "", toggle_key=sys.argv[5] if len(sys.argv)>5 else None)
