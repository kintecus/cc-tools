#!/bin/bash
set -uo pipefail

# PostToolUse(ExitPlanMode) hook: fired the moment a plan is accepted.
# Two jobs:
#   1. Emit a fresh checkpoint reminder so Claude offers a plan review before
#      writing code — the SessionStart rule is stale by this point in context.
#   2. SET the session-keyed pending-review marker so the PreToolUse edit-gate
#      (plan-review-gate.sh) prompts the user before the first code edit. This
#      makes the offer deterministic even when Claude would rationalize past the
#      text reminder.
# Output is the hook JSON contract: systemMessage + hookSpecificOutput.
#
# No `set -e`: the marker step is best-effort and must NEVER abort the critical
# context emission below.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PROTOCOL="${PLUGIN_ROOT}/commands/review-plan/references/protocol.md"

# --- Set the pending-review marker (best-effort) ---
# Consume stdin once here; the context output below does not need it.
INPUT="$(cat 2>/dev/null || true)"
# shellcheck source=/dev/null
if source "${PLUGIN_ROOT}/scripts/plan-review-marker.sh" 2>/dev/null; then
  SID="$(plan_review_session_id "$INPUT")"
  if MARKER="$(plan_review_marker_path "$SID")"; then
    : >"$MARKER" 2>/dev/null || true
  fi
fi

CONTEXT="PLAN-REVIEW CHECKPOINT: A plan was just accepted via ExitPlanMode. \
Per the Plan Review base rules, BEFORE writing any code you MUST offer the \
user a fresh-context plan review: ask \"Want a fresh-context review of this \
plan first?\". \
\
CRITICAL — the edit-approval mode the user just picked in the ExitPlanMode \
menu (\"auto-accept edits\", \"manually approve edits\", etc.) is a SEPARATE \
decision from the plan review. It only controls whether individual edits need \
manual approval; it says NOTHING about whether they want the review. Choosing \
\"auto-accept edits\" is NOT a decline of the review — do NOT treat the \
acceptance itself, the chosen edit mode, or any earlier offer as a decline. \
You owe this offer NOW unless, in this very turn, the user explicitly said no \
to a review specifically. Do not rationalize past it. \
\
If they accept, follow the protocol at ${PROTOCOL} exactly (a fresh subagent \
that receives ONLY the plan text, never this conversation). If they explicitly \
decline the review, proceed to implementation without nagging. Do not skip this offer."

jq -n --arg ctx "$CONTEXT" '{
  systemMessage: "Plan accepted (any edit mode) — still offer a fresh-context plan review before writing code.",
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}'
