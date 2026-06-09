---
name: horizon
description: >
  Long-horizon retrospective over Claude Code sessions. v1 = weekly: aggregates
  7 days of activity via cheap Haiku per-day summaries + Sonnet synthesis
  (Opus with --deep). Output sections: themes, shipped vs stalled, tangents,
  decisions, open loops. Writes to retroscope storage repo + mirrors a
  proxy note in the Obsidian vault. Triggers: "weekly retro", "horizon
  week", "how was my week". Explicit-only.
disable-model-invocation: true
---

# Horizon — long-horizon retrospective

Aggregates Claude Code session activity over a week (later: month, quarter).
Built on top of the retroscope plugin's session extraction; adds stricter
text cleanup, parallel Haiku per-day summaries, and a Sonnet/Opus synthesis.

**See also:** `/harvest-memory` (promotes cross-project facts into the global
memory store). Horizon is its upstream signal source — after writing the retro,
Step 10.5 nudges toward `/harvest-memory` for any durable cross-project facts the
week surfaced, and harvest-memory reads these weekly retros back as corroboration
for which facts are durable enough to promote.

## When to invoke

Only on explicit user request: "weekly retro", "horizon week", "how was my
week", "/horizon week". Do not auto-invoke.

## Step 1: Resolve config and scope

Load the retroscope config with the same cascade retroscope itself uses:

1. `$CLAUDE_PROJECT_DIR/.claude-plugin/retroscope.json`
2. `$CLAUDE_PROJECT_DIR/.claude/retroscope.json`
3. `~/.claude/retroscope.json`

First match wins per key. Required keys: `storageDir`, `timezone`. Optional
overrides (under a `horizon` block, with defaults):

```json
{ "horizon": {
    "weekly": { "model": "sonnet", "deepModel": "opus" },
    "bulkModel": "haiku"
} }
```

Resolve the week:

- `--week YYYY-Www` (ISO 8601) or `--from / --to` flags
- Default: current ISO week in the configured timezone
- Reject future weeks with a clear error (exit 3)

Resolve scope from config (`scope: "project"` or `"all"`, default `"project"`).
Cross-project (`"all"`) routes output under `_cross-project/`.

## Step 2: Resolve retroscope script

Resolution chain. First executable wins. Hard error if none.

```bash
RETROSCOPE_SCRIPT="${RETROSCOPE_SCRIPT:-}"
if [ -z "$RETROSCOPE_SCRIPT" ]; then
  for candidate in \
    "$HOME/.claude/plugins/marketplaces/tribe-coding/plugins/retroscope/scripts/find-sessions.py" \
    "$HOME/code/tribe-coding/claude-plugins/plugins/retroscope/scripts/find-sessions.py"; do
    if [ -x "$candidate" ]; then RETROSCOPE_SCRIPT="$candidate"; break; fi
  done
fi
[ -n "$RETROSCOPE_SCRIPT" ] || { echo "retroscope not found (install tribe-coding/retroscope)"; exit 2; }
```

## Step 3: Cache check

Weekly summary lives at:

- `scope=all`: `{storageDir}/reports/_cross-project/weekly/{YYYY}-W{ww}/summary.md`
- `scope=project`: `{storageDir}/reports/{project}/weekly/{YYYY}-W{ww}/summary.md`

If `summary.md` exists AND its mtime > max mtime across all sessions in the
7-day window AND all daily summaries in the 7-day window, and `--force` was
not passed, print the path and exit. Re-check after collection in case a
session landed mid-run.

## Step 4: Run the collector

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/commands/horizon/scripts/horizon-collect.py" \
  --week "$WEEK" \
  --scope "$SCOPE" \
  --tz "$TZ" \
  --storage-dir "$STORAGE_DIR" \
  --retroscope-script "$RETROSCOPE_SCRIPT" \
  ${DEBUG:+--debug}
```

The collector produces a tempdir at `${TMPDIR:-/tmp}/horizon-{YYYY-Www}-{pid}/`
containing:

- `day-{0..6}.txt` — clean prose (concatenated session extracts for that day)
- `day-{0..6}.stats.json` — aggregated per-day stats
- `week-stats.json` — week-level aggregation
- `manifest.json` — date → source mapping (daily | raw | empty)

See `references/cli-contracts.md` for the script's full CLI.

## Step 5: Fan out Haiku per-part summaries

Read `manifest.json`. Each day has a `parts: [filename, ...]` array. For days
with `source != "empty"`, launch one Haiku Task call **per part** in a single
parallel message. Total call count = sum of part counts across the week
(typically 7-20 calls; a single message can carry all of them).

Subagent prompt (use `general-purpose` subagent type with model `haiku`):

```
You are summarizing one chunk of a developer's Claude Code activity into a
structured JSON record. This may be a full day or one part of a multi-part
day; the schema is the same either way. Output ONLY a JSON object matching:

{
  "intent": "1-2 sentences on what the user was trying to do in this chunk",
  "shipped": ["concrete outcomes that moved (≤5 bullets)"],
  "stalled": ["started but didn't land + likely reason (≤3 bullets) — user-blocked only"],
  "waiting_on": ["artifact ready on user side, blocked on counterparty (≤2)"],
  "decisions": ["tech / project / personal choices worth remembering (≤3)"],
  "surprises": ["unexpected finds, bugs, insights (≤2)"],
  "narrative": "≤300-token prose. No activity logging."
}

If a section is empty, return [].

DAY: {date} ({weekday})
PART: {part_index+1} of {total_parts}    (omit this line if total_parts == 1)
PROSE:
{clean_prose_for_this_part}

STATS (whole-day, not per-part):
{stats_json}
```

For days with `source == "empty"`, skip the LLM call and emit:
`{"intent": "no recorded activity", "shipped": [], "stalled": [], "waiting_on": [], "decisions": [], "surprises": [], "narrative": ""}`.

## Step 5b: Merge multi-part days into single day-records

For any day with >1 part, run **one additional Haiku Task call** to merge the
N part-records into a single day-record matching the same schema. This runs
sequentially after Step 5 completes for that day's parts (it depends on their
output). Single-part days skip this step — the part-record IS the day-record.

Merge prompt:

```
You are merging N part-summaries from a single day into one day-record. The
parts cover the same day in chronological order. Combine them into one JSON
record matching the same schema as the parts, deduplicating overlapping items
and preserving distinct ones. Aim for the same bullet caps (≤5 shipped, ≤3
stalled, etc.) — if the parts collectively exceed those caps, keep the most
load-bearing items and drop near-duplicates.

Output ONLY the merged JSON object.

DAY: {date} ({weekday})
PART RECORDS (JSON, in order):
{part_records_json_array}
```

## Step 5c: Compute the timesheet (deterministic, no LLM)

Run the timesheet script to get defensible per-project **active engaged time**
for the week. This is pure data — it reads message timestamps from the session
JSONLs and sums inter-message gaps, capping idle stretches — so it runs here,
before synthesis, alongside the other deterministic collection.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/commands/horizon/scripts/horizon-timesheet.py" \
  --week "$WEEK" --tz "$TZ" --format json
```

Parse the JSON `rows`. This is **not** the same as the Footer `Hours` line:

- Footer `Hours` = `week-stats.duration_minutes`, the sum of session wall-clock
  spans across all (often concurrent) sessions. It massively overcounts and is
  labeled as overlapping wall-clock.
- Timesheet `active_h` = inter-message gaps capped at 5 min per project. The
  **billable floor**: hands-on-CC time with idle removed. Conservative.

Feed the timesheet rows into the synthesis as `{timesheet}` (see Step 6). The
synthesis renders them into the `## Timesheet` section of the template. Do NOT
let the synthesis invent or round these numbers — pass them through verbatim,
same rule as the Footer.

Caveats the section must carry (the template wording already does this):

- `active_h` counts CC's own compute time (long agent runs) as user time, so
  it is an **upper bound** on keyboard-presence. The 5-min cap keeps it
  conservative; a `--cap 10` variant is the looser bound.
- It excludes all off-CC work (calls, phone review, thinking away from the
  keyboard) — it is a floor for hands-on-CC time, not total project time.
- `union_h` per project dedupes that project's own overlapping sessions. If it
  lags `active_h`, bill the smaller. **Cross-project** concurrency (two clients
  in the same minute) is a human judgment call the script does not resolve.

If the user passes `--no-timesheet`, skip this step and omit the `## Timesheet`
section from the template (and drop `{timesheet}` from the synthesis prompt).

The script is also directly invocable outside a retro for ad-hoc billing:
`horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw --project satori
--format csv` (see `references/cli-contracts.md`).

## Step 6: Synthesis (Sonnet 4.6 or Opus 4.7)

Single Task call. Model: from config (`horizon.weekly.model`, default
`sonnet`) or `horizon.weekly.deepModel` (default `opus`) when `--deep`.

Inputs:

- All 7 day-records (JSON, dated)
- `week-stats.json` aggregated
- Prior week's retro proxy note from vault (if it exists, capped at 4K tokens)
  - Resolution: previous ISO week; W01 → last week of previous year via
    `isocalendar()`
- Optional MEMORY.md profile snippet
  - Resolution: `~/.claude/projects/$(encoded-cwd)/memory/MEMORY.md`
  - Cap at 2K tokens
  - Skip if missing
- Output template (see `references/output-template.md`)

Synthesis prompt (use `general-purpose` subagent with the resolved model):

```
You are writing a weekly retrospective for the user. The 7 per-day records
below are pre-summarized; combine them into a coherent narrative that
surfaces patterns, drift, and useful signals — not an activity log.

Output strictly to this Markdown template (no preamble, no postscript):

{output_template}

Honest tone, not punitive. Naming the user's project wikilinks (e.g.
[[Satori Ads]]) is encouraged. Use the stats block for the Footer numbers
verbatim — do not invent or recompute. Likewise render the `## Timesheet`
section from the timesheet rows verbatim — do not round or re-derive the
active_h / union_h numbers. If no timesheet block is provided, omit the
`## Timesheet` section entirely.

Anti-confabulation rules (load-bearing):
- Do NOT invent artifacts not mentioned in the day records. If a record
  says "X is ready" or "Y not sent," restrict open loops to those literal
  artifacts. Do not synthesize a containing process (e.g. "form to fill")
  around a mentioned artifact.
- Distinguish user-blocked from counterparty-blocked. The day records carry
  a `waiting_on` field for counterparty-blocked items — pull those into the
  template's "Waiting on others" subsection, NOT "Stalled." "Deck ready,
  waiting on their panel-date" → Waiting on others. "CV done, hasn't
  submitted yet" → Stalled (user bottleneck).
- Do not collapse two unrelated open items into one shared cause. If
  artifact A is blocked on counterparty X and artifact B is blocked on
  user time, that is two separate Stalled/Waiting lines, not one.
- When in doubt about an artifact's existence or state, omit it. A shorter
  honest retro beats a confident wrong one.
- Omit the "Waiting on others" subsection entirely when no day-record
  contributed a `waiting_on` item.

WEEK: {YYYY-Www} ({Mon date}–{Sun date})
DAY RECORDS (JSON, in order):
{day_records}

WEEK STATS (JSON):
{week_stats}

TIMESHEET (JSON rows, may be absent if --no-timesheet):
{timesheet}

PRIOR WEEK (markdown, may be empty):
{prior_week}

USER PROFILE (markdown, may be empty):
{memory_snippet}
```

## Step 7: Render + write to storage repo

Compute teaser (first non-empty bullet from synthesis output's `## Themes`).

Write the synthesis output to the storage-repo path via Read first → Edit/Write
(matches retroscope's safety pattern).

## Step 8: Mirror to vault proxy

Write the same Markdown to:

```
$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/02 - AREAS/Retros/weekly/{YYYY-Www}.md
```

Create directories if missing. This makes the wikilink `[[YYYY-Www weekly retro]]`
resolvable inside Obsidian.

## Step 9: Append wikilink to the daily note

Sunday-of-week is the canonical anchor. Resolve the daily note file path:

```
$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/Journal/Daily/{SUNDAY-YYYY-MM-DD}.md
```

If the Sunday note exists, append a line under `# NOTES`:

```
- **HH:MM** [[{YYYY-Www} weekly retro]] - {teaser}
```

If Sunday's note doesn't exist, walk back through the week to find the most
recent daily note that exists; append there. If none exist, skip with a
stderr warning. Never create a new daily note.

Use the Edit tool with the existing `# NOTES` heading as the anchor.

## Step 10: Git commit (with portable lock)

macOS does not ship `flock(1)`. Use a portable `mkdir`-based lock that works on
both macOS and Linux:

```bash
LOCK_DIR="$STORAGE_DIR/.git/horizon.lock.d"
acquire_lock() {
  local tries=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 20 ]; then
      echo "horizon: could not acquire git lock at $LOCK_DIR after 10s" >&2
      return 1
    fi
    sleep 0.5
  done
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
}

acquire_lock || exit 6
cd "$STORAGE_DIR"
# Also wait for any in-flight git operation that holds index.lock.
for _ in 1 2 3 4 5; do
  [ -f .git/index.lock ] || break
  sleep 1
done
git add reports/
git commit -m "retro(${PROJECT_LABEL}): ${WEEK} weekly summary"
if [ "$AUTO_PUSH" = "true" ]; then git push; fi
rmdir "$LOCK_DIR" 2>/dev/null
```

Where `PROJECT_LABEL` = the project basename or `_cross-project`.

If `flock` is available (Linux), it can be substituted by wrapping the
`cd/git add/commit/push` block in `flock -w 10 "$STORAGE_DIR/.git/horizon.lock"`.
The mkdir path is the portable default.

## Step 10.5: Suggest harvest candidates (`/harvest-memory` nudge)

The retro just surfaced the week's `## Decisions`, `## Themes`, and cross-project
patterns — the same raw material `/harvest-memory` promotes into the global memory
store. Scan the 7 day-records (already in hand) for facts that look **cross-project
or workspace-level and durable**, and print a pointer so the user can promote them
deliberately. This is a **nudge only — no writes, no auto-invocation.**

A day-record item is harvest-worthy when it:

- touches **2+ projects** or is **workspace-level** (a git-workflow rule, a tool
  preference, an environment quirk, a recurring interview/process lesson), AND
- reads as **durable**, not week-specific state (a one-off bug fix, a single PR
  merge, or "X is launched this week" does NOT qualify — those are project-local).

Cheap corroboration if it helps: a decision that also appears in the prior week's
retro (already read in Step 6 as `{prior_week}`) is a strong durable signal — call
that out in the nudge.

Emit at most ~3-5 candidates, each one line, e.g.:

```
Harvest candidates (cross-project, durable) — run /harvest-memory to promote:
  - Comp-negotiation rule: state number plainly, ask for their band (job-hunt, recurring)
  - obsidian-cli vault=PIN must precede the subcommand (tooling, affects daily-note + clippings)
```

If nothing qualifies, print nothing (do not manufacture candidates — a silent step
is correct when the week was all project-local work). The user decides whether to act;
`/harvest-memory` runs its own propose-then-confirm flow and re-derives candidates
from the per-project stores, so this nudge never needs to be exhaustive or precise —
it is a reminder, not an input.

## Step 11: Confirm

Print one line:

```
Wrote weekly retro: {storage_path}
Mirrored to vault: {vault_path}
```

If Step 10.5 found harvest candidates, the confirm output already showed them above;
no need to repeat. The retro and the nudge are the two deliverables of a `/horizon` run.

## Flags reference

- `--week YYYY-Www`        ISO 8601 week (default: current)
- `--from / --to`          alternative date window
- `--deep`                 use `deepModel` (Opus) for synthesis
- `--force`                skip cache
- `--no-timesheet`         skip Step 5c; omit the `## Timesheet` section
- `--dry-run`              compute + print result, no commit, no vault write
- `--debug`                log resolved paths, byte ratios, dropped block counts

When called with no args, default to `week` and emit stderr note:
`(defaulting to week; future: /horizon month, /horizon quarter)`.

## Rules

- Run all data collection before LLM calls — don't interleave
- Fail loud on missing retroscope, missing storageDir, future weeks
- Never silently fall back from `scope=all` to `scope=project`
- Never auto-create daily notes (matches `daily-note` skill posture)
- Respect `autoPush: false` by default
- On `--dry-run`: do not commit, do not push, do not write the vault proxy

## See also

- `references/extract-spec.md` — the exact text-cleanup algorithm
- `references/output-template.md` — synthesis output template
- `references/config-schema.md` — config cascade and key reference
- `references/cli-contracts.md` — script CLIs, exit codes
