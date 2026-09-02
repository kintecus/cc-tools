#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
DAILY_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/Journal/Daily"

# --- Effort estimate rules (always injected) ---
# Single-quoted delimiter: no variables to interpolate, and the literal $ in the
# dollar figures must pass through verbatim. Kept terse for the SessionStart budget.
cat <<'ESTIMATE'
## Effort Estimate — Every Plan

When (and ONLY when) you produce a plan via ExitPlanMode in plan mode, end the plan with an effort estimate block as its last element. (Not producing a plan? Ignore this.)

Use this table SHAPE — the numbers below are placeholders, never copy them; compute each range for the specific plan:

> **Effort estimate** (rough — <session model> session)
>
> | | |
> |---|---|
> | ~token budget | <low>-<high> |
> | ~cost | $<low>-<high> |
> | ~Claude time | <low>-<high> min |
> | ~your time | <low>-<high> min |

Rules:
- Gut-checks, not precision. Always ranges (NNk tokens, $N-M, N-M min), never single numbers.
- Title names the CURRENT session model; base cost on its published per-Mtok rate. Don't guess the rate — map the model to the table below (or read the claude-api skill).
- token budget = total tokens the work burns (your reads + edits + tool calls + subagents), not just the diff.
- your time = the user's ACTIVE supervision only (reviewing diffs, answering questions, testing). Drive it off plan-intrinsic complexity, NOT off Claude's runtime or the edit-approval mode.
- cost = budget x blended rate. Rates per Mtok (verified claude-api 2026-06-04): Fable 5 $10/$50, Opus 4.8 $5/$25, Sonnet 4.6 $3/$15, Haiku 4.5 $1/$5. On Opus, input-heavy work with caching lands ~$3-6 per 100k tokens; scale to the session model (Fable 2x Opus, Sonnet ~0.6x, Haiku ~0.2x).
- Sizing reference: trivial/single-file ~30-80k, ~min(s), ~5-10 min you. Medium feature ~150-400k, ~$5-24 on Opus, 10-30 min, ~20-40 min you. Large/cross-cutting 500k-1M+, 30-90 min+, 1h+ you — flag low confidence above this.
ESTIMATE

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
