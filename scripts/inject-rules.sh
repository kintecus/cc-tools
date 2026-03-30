#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OBSIDIAN="/Applications/Obsidian.app/Contents/MacOS/obsidian"
VAULT="Obsidian Vault"
DAILY_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/Journal/Daily"

# Inject today's daily note. Fail silently if Obsidian is not running.
# Try CLI first (vault-pinned), fall back to direct iCloud file read.
OUTPUT=$("$OBSIDIAN" daily:read vault="$VAULT" 2>&1 | grep -v "Loading updated\|out of date\|better CLI") || true

if [[ -z "$OUTPUT" ]]; then
  TODAY=$(date +%Y-%m-%d)
  DAILY_FILE="$DAILY_DIR/$TODAY.md"
  [[ -f "$DAILY_FILE" ]] && OUTPUT=$(cat "$DAILY_FILE") || exit 0
fi

[[ -z "$OUTPUT" ]] && exit 0

TODAY=$(date "+%A, %B %d, %Y")

cat <<EOF
## Today is $TODAY

$OUTPUT
EOF
