#!/bin/bash
set -uo pipefail

# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) hook.
#
# If a plan was accepted this session but no fresh-context review has been
# resolved yet (the marker exists), HARD-BLOCK the first code edit with exit 2.
#
# Why exit 2 and not permissionDecision:"ask": on Claude Code 2.1.x an "ask"
# from a plugin hook is overridden by `permissions.allow` rules (every plan
# edits files the user has allow-listed) and is unreliably honored anyway
# (issues #52822/#13339/#39344). Exit 2 blocks the tool BEFORE permission rules
# are evaluated, so it overrides allow-rules — the only mechanism that reliably
# stops the edit. The stderr is fed back to Claude as the block reason.
#
# Loop avoidance: a blocked edit never reaches plan-review-clear.sh, so the
# marker can't auto-clear. The stderr therefore instructs Claude to clear it
# explicitly when the user resolves the block — /review-plan (review path) or an
# `rm -f` of the marker (decline path) — then retry. The next attempt sees no
# marker and passes.
#
# FAIL-OPEN: any error (no helper, malformed stdin, no session id, no marker)
# must exit 0 with NO output, so a legitimate edit is never blocked by a broken
# hook. Only the marker-present branch exits 2. No `set -e` — a failed command
# must never produce an unintended nonzero exit the harness reads as a block.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck source=/dev/null
source "${PLUGIN_ROOT}/scripts/plan-review-marker.sh" 2>/dev/null || exit 0

INPUT="$(cat 2>/dev/null || true)"
SID="$(plan_review_session_id "$INPUT")"
MARKER="$(plan_review_marker_path "$SID")" || exit 0

[[ -e "$MARKER" ]] || exit 0

# Marker present: hard-block this edit and tell Claude how to resolve it.
cat >&2 <<EOF
PLAN-REVIEW GATE: a plan was accepted in plan mode but no fresh-context review
has happened yet. This edit is blocked on purpose.

Do NOT retry the edit blindly. First, offer the user a fresh-context plan review
("Want a fresh-context review of this plan first?"), then resolve this gate:
  - If they want the review: run /review-plan (its Step 0 clears this gate).
  - If they decline: run exactly this, then retry the edit:
      rm -f "$MARKER"

The gate clears once the marker is gone; the next edit will proceed normally.
EOF
exit 2
