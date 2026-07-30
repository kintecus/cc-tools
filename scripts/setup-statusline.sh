#!/bin/bash
# SessionStart hook: keep ~/.claude/statusline-tools.sh in sync with the plugin.
# Copies the script when missing or stale. Never touches settings.json.
#
# Target filename note: this deliberately does NOT install to the conventional
# ~/.claude/statusline.sh. Other statusline plugins (notably statusline-compact
# from Tribe-Coding/claude-plugins, which this script is derived from) claim that
# path from their own SessionStart hook. Two plugins copying different scripts to
# one path race every session and whichever hook runs last silently wins. A
# distinct target lets both stay installed, with settings.json deciding which one
# actually renders.
#
# Fails open: any problem is reported to stderr and exits 0, so a broken copy can
# never block session start.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
SOURCE="$PLUGIN_ROOT/scripts/statusline.sh"
TARGET="$HOME/.claude/statusline-tools.sh"

[ -f "$SOURCE" ] || exit 0

mkdir -p "$HOME/.claude" 2>/dev/null

if [ ! -f "$TARGET" ] || ! diff -q "$SOURCE" "$TARGET" >/dev/null 2>&1; then
  if cp "$SOURCE" "$TARGET" 2>/dev/null && chmod +x "$TARGET" 2>/dev/null; then
    :
  else
    echo "tools@kintecus: failed to install statusline to $TARGET" >&2
  fi
fi

exit 0
