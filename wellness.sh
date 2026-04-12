#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="$HOME/.claude/scripts"
CONFIG_FILE="$SCRIPTS_DIR/wellness.config.json"
INDEX_FILE="$SCRIPTS_DIR/.wellness_index"
LAST_FIRED="$SCRIPTS_DIR/.wellness_last_fired"
CARDS_DIR="$SCRIPTS_DIR/cards"
NOTIFIER_APP="$SCRIPTS_DIR/WellnessNotifier.app"
HISTORY_FILE="$SCRIPTS_DIR/.wellness_history.json"
SESSION_FILE="$SCRIPTS_DIR/.wellness_session_start"

# Bail if no config
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Read config and decide whether to fire, all in one Python call.
# Outputs: slug\ttitle\tmessage\tnext_index\topen_browser
# Exits non-zero if we should skip (cooldown, keyword mismatch, etc.)
STDIN_DATA=""
if [[ "${1:-}" == "check" ]]; then
  STDIN_DATA=$(cat)
fi

RESULT=$(/usr/bin/python3 -c "
import sys, json, os, time

config_path = '$CONFIG_FILE'
index_path = '$INDEX_FILE'
last_fired_path = '$LAST_FIRED'
session_path = '$SESSION_FILE'
check_mode = '${1:-}' == 'check'
stdin_data = '''$STDIN_DATA'''

with open(config_path) as f:
    config = json.load(f)

# Smart cooldown: scale based on session length
# < 30 min session: no breaks (you just started)
# 30-60 min: use configured cooldown
# 2+ hours: cooldown halved (you need more breaks)
base_cooldown = config.get('cooldown_minutes', 60) * 60

# Track session start
now = time.time()
if not os.path.exists(session_path):
    with open(session_path, 'w') as f:
        f.write(str(int(now)))

session_start = now
if os.path.exists(session_path):
    with open(session_path) as f:
        try:
            session_start = int(f.read().strip())
        except ValueError:
            session_start = now

session_minutes = (now - session_start) / 60

if session_minutes < 30:
    sys.exit(1)  # Too early in session
elif session_minutes > 120:
    cooldown = base_cooldown // 2  # More frequent after 2 hours
else:
    cooldown = base_cooldown

# Check cooldown
if os.path.exists(last_fired_path):
    with open(last_fired_path) as f:
        last = int(f.read().strip())
    if now - last < cooldown:
        sys.exit(1)

# Check slow keywords in check mode
if check_mode:
    if not stdin_data.strip():
        sys.exit(1)
    try:
        hook_input = json.loads(stdin_data)
        command = hook_input.get('tool_input', {}).get('command', '')
    except (json.JSONDecodeError, AttributeError):
        sys.exit(1)
    if not command:
        sys.exit(1)
    keywords = config.get('slow_keywords', [])
    cmd_lower = command.lower()
    if not any(kw.lower() in cmd_lower for kw in keywords):
        sys.exit(1)

# Get current prompt
prompts = config.get('prompts', [])
if not prompts:
    sys.exit(1)

idx = 0
if os.path.exists(index_path):
    with open(index_path) as f:
        try:
            idx = int(f.read().strip())
        except ValueError:
            idx = 0

idx = idx % len(prompts)
prompt = prompts[idx]
next_idx = (idx + 1) % len(prompts)
open_browser = 'true' if config.get('open_browser_card', True) else 'false'

print(f\"{prompt['slug']}\t{prompt['title']}\t{prompt['message']}\t{next_idx}\t{open_browser}\")
" 2>/dev/null) || exit 0

# Parse result
IFS=$'\t' read -r slug title message next_idx open_browser <<< "$RESULT"

# Advance index
echo "$next_idx" > "$INDEX_FILE"

# Record fire time
date +%s > "$LAST_FIRED"

# Log to history
/usr/bin/python3 -c "
import json, os, time
history_path = '$HISTORY_FILE'
history = []
if os.path.exists(history_path):
    try:
        with open(history_path) as f:
            history = json.load(f)
    except (json.JSONDecodeError, ValueError):
        history = []
history.append({
    'slug': '$slug',
    'title': '$title',
    'timestamp': time.strftime('%Y-%m-%dT%H:%M:%S'),
    'epoch': int(time.time())
})
with open(history_path, 'w') as f:
    json.dump(history, f, indent=2)
    f.write('\n')
" 2>/dev/null || true

# Fire macOS notification
if [[ -d "$NOTIFIER_APP" ]]; then
  echo -n "$message" > "$SCRIPTS_DIR/.wellness_message"
  echo -n "$title" > "$SCRIPTS_DIR/.wellness_title"
  open "$NOTIFIER_APP" &>/dev/null || true
else
  osascript -e "display notification \"$message\" with title \"$title\" subtitle \"Claude is working — take a moment\"" &>/dev/null || true
fi

# Open browser card
if [[ "$open_browser" == "true" ]]; then
  card_file="$CARDS_DIR/$slug.html"
  if [[ -f "$card_file" ]]; then
    open "$card_file" &>/dev/null || true
  fi
fi

exit 0
