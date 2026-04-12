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
# Replace the closing </head> with an inline script that sets the data
cat "$TEMPLATE" | sed "s|</head>|<script>window.__WELLNESS_HISTORY__ = $HISTORY;</script></head>|" > "$DASHBOARD_FILE"

open "$DASHBOARD_FILE"
