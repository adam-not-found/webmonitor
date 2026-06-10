#!/bin/bash

# Visual Color Variables
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}===============================================${NC}"
echo -e "${CYAN}    🛡️  WEBMONITOR CORE DEPENDENCY CHECKER     ${NC}"
echo -e "${CYAN}===============================================${NC}"

# --- PRE-FLIGHT VERIFICATIONS ---

# 1. Verify OS environment context
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}❌ Error: WebMonitor requires Apple macOS architecture.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Environment Platform Match: macOS (${OSTYPE})${NC}"

# 2. Check architecture target to locate Homebrew framework binary strings
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PYTHON="/opt/homebrew/bin/python3"
else
    BREW_PYTHON="/usr/local/bin/python3"
fi

# 3. Verify Python 3 presence
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: Python 3 core interpreter missing. Install via Xcode or Homebrew.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Python 3 Environment Found: $(which python3)${NC}"

# 4. Verify SwiftBar UI presentation wrapper presence
if ! open -Ra "SwiftBar" &> /dev/null; then
    echo -e "${YELLOW}⚠ Notice: SwiftBar app manager not detected in global spaces.${NC}"
    if command -v brew &> /dev/null; then
        echo "Homebrew environment detected. Attempting automated SwiftBar cask layout..."
        brew install --cask swiftbar
    else
        echo -e "${RED}❌ Error: Please install SwiftBar manually (https://swiftbar.app) or install Homebrew.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✔ SwiftBar UI Handler Found.${NC}"

# --- ASSET STRUCTURE INITIALIZATION ---
echo -e "\n${CYAN}[ Installing System Components... ]${NC}"

TARGET_DIR="$HOME/.webmonitor"
PLUGIN_DIR="$TARGET_DIR/plugins"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"

mkdir -p "$TARGET_DIR"
mkdir -p "$PLUGIN_DIR"
mkdir -p "$LAUNCH_AGENT_DIR"

# Move executable files inside home deployment spaces
cp monitor.py "$TARGET_DIR/monitor.py"
cp webmonitor.sh "$TARGET_DIR/webmonitor.sh"
chmod +x "$TARGET_DIR/webmonitor.sh"

# Build the custom SwiftBar shell plugin loop
cat << 'EOF' > "$PLUGIN_DIR/webmonitor.3s.sh"
#!/bin/bash
CONFIG_PATH="$HOME/.webmonitor/config.json"
if pgrep -f "monitor.py" > /dev/null; then
    ICON=$(osascript -l JavaScript -e "JSON.parse(ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(os.path.expanduser('~/.webmonitor/config.json'), $.NSUTF8StringEncoding, null))).menu_bar_icon" 2>/dev/null)
    if [ -z "$ICON" ] || [ "$ICON" == "undefined" ]; then ICON="🦉"; fi
    echo "$ICON"
else
    echo "⚠️"
fi
echo "---"
echo "Open Dashboard | bash='$HOME/.webmonitor/webmonitor.sh' terminal=true"
EOF
chmod +x "$PLUGIN_DIR/webmonitor.3s.sh"

# Dynamically construct the specific LaunchAgent from the source template file
if [ -f "com.user.webmonitor.plist" ]; then
    sed -e "s|TARGET_PYTHON_PATH|$BREW_PYTHON|g" \
        -e "s|TARGET_HOME_DIR|$HOME|g" \
        com.user.webmonitor.plist > "$LAUNCH_AGENT_DIR/com.user.webmonitor.plist"
else
    echo -e "${RED}❌ Error: com.user.webmonitor.plist template file missing from directory root.${NC}"
    exit 1
fi

echo -e "${GREEN}✔ Component directories structured and mapped successfully.${NC}"

# --- PERMISSION SYSTEM INSTRUCTIONS ---
echo -e "\n${YELLOW}====================================================${NC}"
echo -e "${YELLOW}      CRITICAL REQUIRED ACTIONS (OS SECURITY)      ${NC}"
echo -e "${YELLOW}====================================================${NC}"
echo -e "Because WebMonitor analyzes input strings across systemic environments,"
echo -e "you MUST grant permissions to the core running terminal binary."
echo -e "\n1. Navigate to: ${CYAN}System Settings > Privacy & Security > Accessibility${NC}"
echo -e "2. Ensure your terminal app (${CYAN}Terminal${NC} or ${CYAN}iTerm2${NC}) is checked ${GREEN}ON${NC}."
echo -e "\n3. Navigate to: ${CYAN}System Settings > Privacy & Security > Screen Recording${NC}"
echo -e "4. Ensure your terminal app is checked ${GREEN}ON${NC}."
echo -e "${YELLOW}====================================================${NC}"
read -p "Press [Enter] once you have verified these security assignments..."

# --- AUTOMATED SWIFTBAR CONFIGURATION ---
echo -e "\n${CYAN}[ Automating SwiftBar Configuration... ]${NC}"

# 1. Kill any stale SwiftBar instances safely
pkill -x "SwiftBar" 2>/dev/null

# 2. Force-inject the preferences directly into the macOS defaults system
mkdir -p "$HOME/Library/Preferences"
cat << EOF > /tmp/app.swiftbar.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>pluginsFolder</key>
    <string>$TARGET_DIR/plugins</string>
</dict>
</plist>
EOF

defaults import app.swiftbar /tmp/app.swiftbar.plist
rm -f /tmp/app.swiftbar.plist

# 3. Force macOS to instantly commit the new preferences to disk
killall cfprefsd 2>/dev/null

# 4. Explicitly launch the binary directly to bypass first-open prompts
if [ -d "/Applications/SwiftBar.app" ]; then
    /Applications/SwiftBar.app/Contents/MacOS/SwiftBar --background &
fi

echo -e "${GREEN}✔ SwiftBar configuration successfully forced and initialized.${NC}"
