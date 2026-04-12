#!/usr/bin/env bash
set -euo pipefail

HISTORY_FILE="$HOME/.claude/scripts/.wellness_history.json"
DASHBOARD_DIR="$HOME/.claude/scripts/cards"
DASHBOARD_FILE="$DASHBOARD_DIR/dashboard-live.html"

# Read history or use empty array
HISTORY="[]"
if [[ -f "$HISTORY_FILE" ]]; then
  HISTORY=$(cat "$HISTORY_FILE")
fi

# Read the dashboard template
TEMPLATE="$(dirname "$0")/cards/dashboard.html"
if [[ ! -f "$TEMPLATE" ]]; then
  TEMPLATE="$DASHBOARD_DIR/dashboard.html"
fi

# Inject history data directly into a copy of the dashboard
/usr/bin/python3 -c "
import sys
history = sys.argv[1]
template = sys.argv[2]
output = sys.argv[3]
with open(template) as f:
    html = f.read()
inject = '<script>window.__WELLNESS_HISTORY__ = ' + history + ';</script></head>'
html = html.replace('</head>', inject, 1)
with open(output, 'w') as f:
    f.write(html)
" "$HISTORY" "$TEMPLATE" "$DASHBOARD_FILE"

open "$DASHBOARD_FILE"
