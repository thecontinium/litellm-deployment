#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "🛠️ LiteLLM User-Space Deployment (Centralized Tools)"
echo "=================================================="

# 1. Enforce validation of centralized tools
if ! command -v uv &>/dev/null; then
  echo "❌ Error: 'uv' was not found in the path." >&2
  echo "Please have the Central Homebrew Owner run: brew install uv" >&2
  exit 1
fi

# 2. Build isolated user-space storage directories
LOCAL_BIN="$HOME/.local/bin"
VENV_DIR="$HOME/.local/share/litellm/.venv"
CONFIG_DIR="$HOME/.config/litellm"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

mkdir -p "$LOCAL_BIN"
mkdir -p "$VENV_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

# 3. Compile localized virtual environment tracking central uv
echo "📦 Creating isolated Python environment at $VENV_DIR..."
uv venv "$VENV_DIR"

echo "🐍 Installing LiteLLM package layers into user environment..."
"$VENV_DIR/bin/uv" pip install "litellm[proxy]"

# 4. Deploy local launcher script
echo "🚚 Installing litellm-service to $LOCAL_BIN..."
cp litellm-service "$LOCAL_BIN/litellm-service"
chmod +x "$LOCAL_BIN/litellm-service"

# 5. Safe template initialization
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  echo "📝 Creating configuration profile skeleton..."
  cp config.default.yaml "$CONFIG_DIR/config.yaml"
else
  echo "skip: Existing configuration layout detected."
fi

# 6. Process and Deploy the launchd Plist
echo "🚀 Configuring launchd service template..."
TARGET_PLIST="$LAUNCH_AGENTS_DIR/local.litellm.plist"

# Boot out any pre-existing instance to prevent registration locks
launchctl bootout gui/"$(id -u)" "$TARGET_PLIST" 2>/dev/null || true

# Swap the HOME_DIR token with the real absolute path and write to the system target
sed "s|HOME_DIR|$HOME|g" local.litellm.plist >"$TARGET_PLIST"

# Register and start the background agent cleanly
echo "⚙️ Bootstrapping launchd background service..."
launchctl bootstrap gui/"$(id -u)" "$TARGET_PLIST"

echo "=================================================="
echo "🎉 User-Space Installation Complete!"
echo "=================================================="
echo "👉 Post-Installation Steps for $USER:"
echo "1. Run: security add-generic-password -U -a \"$USER\" -s GEMINI_API_KEY -w 'your_key'"
echo "2. Stream runtime daemon console outputs using:"
echo "   tail -f ~/Library/Logs/litellm.log"
echo "=================================================="
