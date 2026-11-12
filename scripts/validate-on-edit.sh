#!/bin/bash
# PostToolUse hook (Write|Edit): validate Mermaid blocks in the edited .md file.
#
# Exit 0 with no output when the file is not markdown, has no invalid blocks, or
# Kroki is unreachable (fail-soft). Exit 2 with the errors on stderr when a block
# fails to parse: for PostToolUse that is the only plain-text channel Claude sees
# (exit-0 stdout goes to the debug log). The edit itself is never undone.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

FILE_PATH=$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))
except Exception: pass' 2>/dev/null)

[[ "$FILE_PATH" == *.md && -f "$FILE_PATH" ]] || exit 0

ERRORS=$(python3 "$PLUGIN_ROOT/scripts/validate-mermaid.py" "$FILE_PATH" 2>&1 >/dev/null)
if [ $? -eq 1 ]; then
  printf '%s\nFix the mermaid syntax above (see the mermaid-diagram-guide command).\n' "$ERRORS" >&2
  exit 2
fi
exit 0
