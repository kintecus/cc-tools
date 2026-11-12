#!/bin/bash
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

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

# --- Mermaid and /retro rules (static; folded in from the former mermaid and
# retroscope plugins). Keep the "## Mermaid Diagrams" and "## Retroscope"
# headings: horizon-extract.py drops hook banners by those prefixes.
cat <<'MERMAID'

## Mermaid Diagrams in Markdown — Base Rules

Mermaid renders natively in GitHub, Obsidian, VS Code, and most markdown viewers: write a fenced ```mermaid code block with the diagram source and nothing else (no image link after it).

- When creating/updating `.md` docs, proactively add Mermaid diagrams for flowcharts, sequences, state machines, class relationships, ER schemas, and gantt timelines.
- Terminal rendering is NOT supported. For in-terminal diagrams use ASCII; with Mermaid, write to `.md` and point the user at GitHub/Obsidian/IDE.
- Every diagram MUST include a title where the type supports it (`title: ...` for sequence, class, state; `title ...` for gantt; a first-line `%% Title: ...` comment otherwise), plus `accTitle: ...` and `accDescr: ...` where supported (flowchart, sequence, class, state, ER).
- For flowcharts, use shapes semantically (cylinder = storage, hexagon = orchestrator, stadium = actor, rhombus = decision), `linkStyle` colors for meaning (blue = data, orange = control, green = storage, purple = feedback), and reusable `classDef` entries instead of inline styling.
- **ALWAYS invoke the `tools:mermaid-diagram-guide` skill BEFORE creating any Mermaid diagram** to pick the diagram type and review its Styling & Semantics section. Other types (pie, journey, mindmap, timeline): see https://mermaid.js.org.
- After Write/Edit on a `.md` file, a PostToolUse hook validates every `mermaid` block against Kroki (`MERMAID_KROKI_URL`, default https://kroki.io). Parse errors come back as hook feedback with file and line; fix them. On network failure validation is skipped silently.
MERMAID

cat <<'RETRO'

## Retroscope — Session Retrospective Reports

`/retro session` summarizes the current session (display only). `/retro today` and `/retro yesterday` write a daily report to the `storageDir` set in `~/.claude/retroscope.json`.
RETRO

# The daily note is no longer injected at SessionStart (removed in 0.26.0) — use
# /daily-note to pull it in on demand.
