#!/bin/bash

cd "$(dirname "$0")"

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

# ====================================================================
# CRITICAL FIX: Define Python Path FIRST before using it
# ====================================================================
TARGET_PYTHON=$(which python3)
if [[ "$TARGET_PYTHON" == "/usr/bin/python3" ]] && [ -f "/Library/Frameworks/Python.framework/Versions/Current/bin/python3" ]; then
    TARGET_PYTHON="/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
fi

# 2. Check architecture target to locate Homebrew framework binary strings
if [[ "$(uname -m)" == "arm64" ]]; then
    BREW_PYTHON="/opt/homebrew/bin/python3"
else
    BREW_PYTHON="/usr/local/bin/python3"
fi

# 3. Verify Python 3 & Command Line Tools Presence
if ! xcode-select -p &>/dev/null; then
    echo -e "${YELLOW}📦 macOS Command Line Tools missing. Triggering automated installation...${NC}"
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    PROD=$(softwareupdate -l | grep "\*.*Command Line" | head -n 1 | awk -F"*" '{print $2}' | sed -e 's/^ *//' | tr -d '\n')
    if [ -n "$PROD" ]; then
        softwareupdate -i "$PROD" --verbose
    else
        echo -e "${RED}❌ Please click 'Install' on the macOS popup to continue, then re-run this script.${NC}"
        exit 1
    fi
    rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: Python 3 core interpreter missing.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Python 3 Environment Found.${NC}"

# Ensure required Python networking libraries are installed globally/locally
echo "Checking Python library dependencies..."
$TARGET_PYTHON -m pip install --upgrade pip &>/dev/null
$TARGET_PYTHON -m pip install --break-system-packages requests secure-smtplib &>/dev/null

# 4. Verify SwiftBar UI presentation wrapper presence
if ! open -Ra "SwiftBar" &> /dev/null; then
    echo -e "${YELLOW}⚠ Notice: SwiftBar app manager not detected in global spaces.${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}📦 Homebrew not found. Installing Homebrew framework automatically...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null
        if [[ "$(uname -m)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
    echo "Installing SwiftBar via Homebrew..."
    brew install --cask swiftbar
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

# Compile the fast visual scanning daemon binary directly into the engine directory
echo "Compiling native ScreenCaptureKit backend engine..."
swiftc monitor.swift -o "$TARGET_DIR/scanner"
codesign -s - --force "$TARGET_DIR/scanner"

# Build the custom SwiftBar shell plugin loop
cat << 'EOF' > "$PLUGIN_DIR/webmonitor.3s.sh"
#!/bin/bash
if pgrep -f ".webmonitor/scanner" > /dev/null; then
    ICON=$(python3 -c "import json, os; print(json.load(open(os.path.expanduser('~/.webmonitor/config.json')))['menu_bar_icon'])" 2>/dev/null)
    if [ -z "$ICON" ] || [ "$ICON" == "None" ]; then ICON="🦉"; fi
    echo "$ICON"
else
    echo "⚠️"
fi
echo "---"
echo "Open Dashboard | bash='$HOME/.webmonitor/webmonitor.sh' terminal=true"
EOF
chmod +x "$PLUGIN_DIR/webmonitor.3s.sh"

# Force load cycle clearance by unloading any existing active profile instances
launchctl bootout gui/$(id -u) "$LAUNCH_AGENT_DIR/com.user.webmonitor.plist" 2>/dev/null

# Dynamically construct the LaunchAgent file targeting the native binary executable
cat << EOF > "$LAUNCH_AGENT_DIR/com.user.webmonitor.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.webmonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>${TARGET_DIR}/scanner</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${TARGET_DIR}/output.log</string>
    <key>StandardErrorPath</key>
    <string>${TARGET_DIR}/error.log</string>
</dict>
</plist>
EOF

chmod 644 "$LAUNCH_AGENT_DIR/com.user.webmonitor.plist"
launchctl bootstrap gui/$(id -u) "$LAUNCH_AGENT_DIR/com.user.webmonitor.plist"

echo -e "${GREEN}✔ Component directories structured and mapped successfully.${NC}"

# --- PERMISSION SYSTEM INSTRUCTIONS ---
echo -e "\n${YELLOW}====================================================${NC}"
echo -e "${YELLOW}      CRITICAL REQUIRED ACTIONS (OS SECURITY)      ${NC}"
echo -e "${YELLOW}====================================================${NC}"
echo -e "Because WebMonitor analyzes input strings across systemic environments,"
echo -e "you MUST grant permissions to the core running terminal binary."
echo -e "\n1. Navigate to: System Settings > Privacy & Security > Accessibility"
echo -e "2. Ensure your terminal app (Terminal or iTerm2) is checked ON."
echo -e "\n3. Navigate to: System Settings > Privacy & Security > Screen Recording"
echo -e "4. Ensure your terminal app is checked ON."
echo -e "===================================================="
read -p "Press [Enter] once you have verified these security assignments..."

# Launch the Onboarding Profile Configuration Wizard directly
echo -e "\n${CYAN}[ Starting Onboarding Profile Configuration Wizard... ]${NC}"
clear
bash "$TARGET_DIR/webmonitor.sh"

# Force SwiftBar to refresh its UI and show the owl
open -g "swiftbar://refreshall"
