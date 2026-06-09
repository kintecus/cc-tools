#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DAILY_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/Journal/Daily"

# --- Plan review rules (always injected) ---
cat <<RULES
## Plan Review — Base Rules

MANDATORY: A plan produced in plan mode is reviewed by a fresh-context subagent before any code is written.

- After \`ExitPlanMode\` is accepted (a plan was produced) → offer a fresh-context plan review BEFORE writing code: "Want a fresh-context review of this plan first?" — owed on EVERY acceptance, regardless of the edit-approval mode chosen. (A \`PostToolUse\` hook on \`ExitPlanMode\` reinforces this with a checkpoint reminder at the moment of acceptance — this rule is the in-context backstop.)
- The ExitPlanMode edit-approval mode ("auto-accept edits" vs "manually approve edits") is ORTHOGONAL to the review offer. Picking "auto-accept edits" controls only whether edits need manual approval — it is NOT a decline of the review and does not waive the offer. Never conflate the two; never treat acceptance or the edit mode as a prior decline.
- When the user accepts → read \`${PLUGIN_ROOT}/commands/review-plan/references/protocol.md\` and follow its protocol exactly. NEVER review the plan yourself in the same context — your context is biased by having authored the plan.
- When the user explicitly declines the review → proceed to implementation without nagging.
- The reviewer subagent receives ONLY the plan text — never the planning conversation, rationale, or chat history. Independence is the point.
- The review MUST produce, for the plan: (1) gaps, blind spots, and unclear points, (2) each finding tagged with a priority, (3) a concrete suggested change for EVERY finding — not just the top few.
- After the review returns → revise the plan with the findings, show the user the revised plan, then implement.
- Run \`/review-plan\` to review a plan manually — including a plan pasted from outside this session.
RULES

# --- Today's daily note (best effort; fail silently if Obsidian is unavailable) ---
# Run in a subshell so early exits here do not abort the whole hook.
(
  export PATH="$HOME/.claude/bin:$PATH"
  OUTPUT=$(obsidian-cli read daily 2>/dev/null) || true
  # obsidian-cli prints "Error: ..." to stdout with exit 0 when the daily plugin
  # is unavailable — treat that as no output so it falls back to a direct file read.
  [[ "$OUTPUT" == Error:* ]] && OUTPUT=""

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
)
