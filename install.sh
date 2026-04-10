#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HOME/.claude/scripts"
SETTINGS_FILE="$HOME/.claude/settings.json"
CONFIG_FILE="$SCRIPTS_DIR/wellness.config.json"

echo "Installing claude-pause..."

# 1. Create target directory
mkdir -p "$SCRIPTS_DIR"

# 2. Copy wellness.sh
cp "$REPO_DIR/wellness.sh" "$SCRIPTS_DIR/wellness.sh"
chmod +x "$SCRIPTS_DIR/wellness.sh"
echo "  Copied wellness.sh"

# 3. Copy cards
rm -rf "$SCRIPTS_DIR/cards"
cp -r "$REPO_DIR/cards" "$SCRIPTS_DIR/cards"
echo "  Copied cards/"

# 4. Copy config (preserve existing)
if [[ -f "$CONFIG_FILE" ]]; then
  echo "  Config already exists — skipping (your customizations are safe)"
else
  cp "$REPO_DIR/wellness.config.json" "$CONFIG_FILE"
  echo "  Created default config"
fi

# 5. Compile WellnessNotifier.app (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
  osacompile -o "$SCRIPTS_DIR/WellnessNotifier.app" <<'APPLESCRIPT'
on run
  set msgFile to (POSIX path of (path to home folder)) & ".claude/scripts/.wellness_message"
  set titleFile to (POSIX path of (path to home folder)) & ".claude/scripts/.wellness_title"
  set msg to read POSIX file msgFile as «class utf8»
  set ttl to read POSIX file titleFile as «class utf8»
  display notification msg with title ttl subtitle "Claude is working — take a moment 🌿"
end run
APPLESCRIPT
  echo "  Compiled WellnessNotifier.app"
else
  echo "  Skipped WellnessNotifier.app (macOS only — browser cards still work)"
fi

# 6. Merge hooks into settings.json
HOOKS_BASH=$(/usr/bin/python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print('True' if c.get('hooks',{}).get('bash',True) else 'False')")
HOOKS_AGENT=$(/usr/bin/python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print('True' if c.get('hooks',{}).get('agent',True) else 'False')")
HOOKS_MCP=$(/usr/bin/python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print('True' if c.get('hooks',{}).get('mcp',True) else 'False')")

/usr/bin/python3 <<PYEOF
import json, os

settings_path = "$SETTINGS_FILE"

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    os.makedirs(os.path.dirname(settings_path), exist_ok=True)
    settings = {}

hooks = settings.setdefault("hooks", {})
pre = hooks.setdefault("PreToolUse", [])

pre = [h for h in pre if not any("wellness.sh" in hook.get("command", "") for hook in h.get("hooks", []))]

if $HOOKS_BASH:
    pre.append({
        "matcher": "Bash",
        "hooks": [{"type": "command", "command": "bash ~/.claude/scripts/wellness.sh check", "timeout": 5}]
    })

if $HOOKS_AGENT:
    pre.append({
        "matcher": "Agent",
        "hooks": [{"type": "command", "command": "bash ~/.claude/scripts/wellness.sh", "timeout": 5}]
    })

if $HOOKS_MCP:
    pre.append({
        "matcher": "mcp__",
        "hooks": [{"type": "command", "command": "bash ~/.claude/scripts/wellness.sh", "timeout": 5}]
    })

hooks["PreToolUse"] = pre
settings["hooks"] = hooks

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
echo "  Merged hooks into settings.json"

echo ""
echo "claude-pause installed!"
echo ""
echo "  Config: $CONFIG_FILE"
echo "  Edit it to customize cooldown, prompts, and hooks."
echo ""
echo "  To uninstall: bash $REPO_DIR/uninstall.sh"
