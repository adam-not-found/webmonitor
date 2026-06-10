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

# Kill any running instances of SwiftBar to safely update preferences
pkill -x "SwiftBar" 2>/dev/null

# Force SwiftBar to use your specific directory without prompting the user
defaults write app.swiftbar pluginsFolder "$TARGET_DIR/plugins"

# Tell macOS to register the preference change instantly
killall cfprefsd 2>/dev/null

# Open SwiftBar silently in the background
open -a "SwiftBar" --args --background

echo -e "${GREEN}✔ SwiftBar automatically configured to read your plugins directory.${NC}"

# Launch the Onboarding Profile Configuration Wizard to set credentials
echo -e "\n${CYAN}[ Starting Onboarding Profile Configuration Wizard... ]${NC}"
clear
bash "$TARGET_DIR/webmonitor.sh"

echo -e "\n${GREEN}🚀 INSTALLATION COMPLETE! Everything is running silently in the background.${NC}"
