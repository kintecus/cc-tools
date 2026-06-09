#!/bin/bash
set -uo pipefail

# PostToolUse(Edit|Write|MultiEdit|NotebookEdit) hook.
#
# Fires after a code edit succeeds. If the user Allowed the edit through the
# plan-review gate (or edits are flowing normally), the pending-review marker
# for this session has served its purpose — remove it so later edits in the
# same turn don't re-prompt. The gate is therefore at most a single prompt per
# accepted plan.
#
# Always exits 0 with no output. Removing a nonexistent marker is a no-op, so
# this is safe to run after every edit regardless of whether a plan was pending.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/scripts/plan-review-marker.sh" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
SID="$(plan_review_session_id "$INPUT")"
MARKER="$(plan_review_marker_path "$SID")" || exit 0

rm -f "$MARKER" 2>/dev/null || true
exit 0
