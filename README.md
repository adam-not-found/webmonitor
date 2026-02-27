# webmonitor

🛡️ WebMonitor Setup Guide

This project monitors Safari activity for restricted keywords and sends instant email alerts when a trigger word is detected.

🚀 Quick Installation

To install or run the dashboard, open your Terminal and run:

cd ~ && git clone https://github.com/adam-not-found/webmonitor.git ~/.webmonitor && cd ~/.webmonitor && chmod +x webmonitor.sh && ./webmonitor.sh

📋 Setup Wizard Instructions

When you run the script for the first time, it will guide you through these sections:

Recipient Email: Enter the email address that should receive the alerts (e.g., a parent or partner).

Sender Account: Enter a Gmail address and its 16-character App Password. This account acts as the "messenger" that physically sends the emails.

Trigger Words: Add words you want to flag (e.g., from the List of Dirty Words file in this repo).

Whitelist: Add domains you trust (like google.com or apple.com) to prevent unnecessary alerts from those specific sites.

⚙️ Dashboard Sections Explained

Once setup is complete, you can manage the system through the main dashboard:

Email & Account Settings: Update who receives alerts or change the sending account credentials.

Trigger Words & Whitelist: Add or remove words and trusted sites. The new "Multiple" mode allows you to enter a long list of words at once—just type 0 when you are finished.

Alert Toggles: Turn specific notifications ON or OFF. For example, you can stop getting emails every time you add a new word by toggling added_trigger_words to OFF.

Restart Engine: Always select this after making changes to your word lists to ensure the background scanner (the "Engine") is using your newest settings.

Stop & Uninstall: Completely stops the monitoring service and deletes the local configuration folder.
