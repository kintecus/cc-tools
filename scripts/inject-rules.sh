#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
OBSIDIAN="/Applications/Obsidian.app/Contents/MacOS/obsidian"

# Inject today's daily note. Fail silently if Obsidian is not running.
OUTPUT=$("$OBSIDIAN" daily:read 2>&1 | grep -v "Loading updated\|out of date\|better CLI") || exit 0

[[ -z "$OUTPUT" ]] && exit 0

cat <<EOF
## Today's daily note

$OUTPUT
EOF
