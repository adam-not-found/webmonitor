#!/bin/bash

CONFIG_PATH="/Users/adam.erickson/.webmonitor/config.json"

# Check if the python monitor loop is actively running
if pgrep -f "monitor.py" > /dev/null; then
    # Dynamically extract the custom icon from config.json, fallback to 🦉 if missing
    ICON=$(osascript -l JavaScript -e "JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError('$CONFIG_PATH', $.NSUTF8StringEncoding, null))).menu_bar_icon" 2>/dev/null)
    
    if [ -z "$ICON" ] || [ "$ICON" == "undefined" ]; then
        ICON="🦉"
    fi
    echo "$ICON"
else
    # Show the warning icon if the process is down
    echo "⚠️"
fi

echo "---"
echo "Open Dashboard | bash='~/.webmonitor/webmonitor.sh' terminal=true"
