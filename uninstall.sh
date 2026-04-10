#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$HOME/.claude/scripts"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Uninstalling claude-pause..."

# 1. Remove files
rm -f "$SCRIPTS_DIR/wellness.sh"
echo "  Removed wellness.sh"

rm -rf "$SCRIPTS_DIR/cards"
echo "  Removed cards/"

rm -f "$SCRIPTS_DIR/wellness.config.json"
echo "  Removed config"

rm -rf "$SCRIPTS_DIR/WellnessNotifier.app"
echo "  Removed WellnessNotifier.app"

# 2. Remove state files
rm -f "$SCRIPTS_DIR/.wellness_index"
rm -f "$SCRIPTS_DIR/.wellness_last_fired"
rm -f "$SCRIPTS_DIR/.wellness_message"
rm -f "$SCRIPTS_DIR/.wellness_title"
echo "  Removed state files"

# 3. Remove hooks from settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
  /usr/bin/python3 <<PYEOF
import json

with open("$SETTINGS_FILE") as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
pre = hooks.get("PreToolUse", [])

pre = [h for h in pre if not any("wellness.sh" in hook.get("command", "") for hook in h.get("hooks", []))]

if pre:
    hooks["PreToolUse"] = pre
else:
    hooks.pop("PreToolUse", None)

if hooks:
    settings["hooks"] = hooks
else:
    settings.pop("hooks", None)

with open("$SETTINGS_FILE", "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
  echo "  Cleaned hooks from settings.json"
fi

echo ""
echo "claude-pause uninstalled."
