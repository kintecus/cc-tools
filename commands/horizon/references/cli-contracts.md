# CLI contracts

Exact stdin/stdout/exit-code contracts for the three scripts. Useful when one
script invokes the other and when SKILL.md orchestrates them.

## `horizon-collect.py`

Hybrid collector. Walks 7 days; per day picks cached daily summary or runs
extraction over raw session JSONL.

### Flags

```
--week YYYY-Www                    # OR --from + --to
--from YYYY-MM-DD
--to   YYYY-MM-DD
--scope {project,all}              # default from config
--project-dir PATH                 # default $CLAUDE_PROJECT_DIR or cwd
--tz IANA-TZ                       # default from config
--storage-dir PATH                 # default from config
--retroscope-script PATH           # default: env $RETROSCOPE_SCRIPT then chain
--out-dir PATH                     # default ${TMPDIR:-/tmp}/horizon-{YYYY-Www}-{pid}
--max-day-bytes N                  # default 200000 (≈ 50K tokens); split per-day prose into parts
--debug
```

### Output

Writes to `--out-dir`:

```
day-{0..6}.txt                       # master clean prose; one per day, Mon=0..Sun=6
day-{i}-part-{0..N-1}.txt            # ONLY for oversized days; split at turn boundaries
day-{0..6}.stats.json                # aggregated per-day stats
week-stats.json                      # week-level aggregation
manifest.json                        # date → source mapping with `parts` field
```

Per-day prose is split when it exceeds `--max-day-bytes` (UTF-8). Splits
respect message turn boundaries — each part starts at a `[timestamp | role]`
header. The master `day-{i}.txt` is retained for debug and idempotency; the
orchestrator should iterate over `manifest.json`'s `parts` field, not the
master file.

Prints to stdout: the absolute path of `--out-dir`. Nothing else.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | OK |
| 2 | retroscope `find-sessions.py` not found / not executable |
| 3 | invalid week (future, ill-formed, before session-history start) |
| 4 | `storageDir` missing or not a directory |
| 5 | one or more session files unreadable (manifest will mark them) |

### Manifest format

```json
{
  "week": "2026-W21",
  "scope": "all",
  "tz": "Europe/Warsaw",
  "days": [
    { "date": "2026-05-18", "weekday": "Mon", "source": "daily",
      "summary_path": "…/daily/2026/05/18/summary.md",
      "session_count": 9,
      "parts": ["day-0.txt"] },
    { "date": "2026-05-19", "weekday": "Tue", "source": "raw",
      "session_files": ["…/abc.jsonl", "…/def.jsonl"],
      "parts": ["day-1-part-0.txt", "day-1-part-1.txt", "day-1-part-2.txt"] },
    { "date": "2026-05-20", "weekday": "Wed", "source": "empty",
      "session_files": [],
      "parts": [] }
  ]
}
```

The `parts` field is always present (uniform iteration for the orchestrator).
For single-part days it contains one entry — usually `day-{i}.txt`. For empty
days it is `[]`. For chunked days it lists each `day-{i}-part-{j}.txt`.

## `horizon-extract.py`

Per-session clean-prose extractor + stats sidecar.

### Flags

```
--session FILE                     # repeatable (one or many sessions)
--date YYYY-MM-DD                  # filter messages by local date
--tz IANA-TZ
--stats-out PATH                   # optional; write aggregated stats sidecar
--max-asst-chars N                 # default 3000
--debug                            # log raw/extracted byte ratio + drop counts to stderr
```

### Output

- **stdout**: concatenated clean prose. Per-turn header
  `[ISO-timestamp | role]\n` followed by joined text blocks, double newline
  between turns.
- **stderr** (when `--debug`): byte-ratio line + top-5 dropped block-type
  counts.
- **stats sidecar** (when `--stats-out`): JSON aggregating across all
  `--session` files. Uses the upstream `find-sessions.py --stats` schema:

```json
{
  "session_count": 4,
  "cwd_list": ["/Users/ostaps/code/satori", "/Users/ostaps/code/cc-tools"],
  "branches": ["main", "feature/x"],
  "models": ["claude-opus-4-7", "claude-haiku-4-5-20251001"],
  "time_range": { "duration_minutes": 187 },
  "token_usage": {
    "input_tokens": ...,
    "output_tokens": ...,
    "cache_creation_input_tokens": ...,
    "cache_read_input_tokens": ...
  },
  "tool_counts": { "Bash": 47, "Read": 31, "Edit": 12 },
  "estimated_cost_usd": 0.43,
  "naive_cost_usd": 1.21
}
```

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | OK |
| 2 | one or more `--session` files unreadable or unparseable |
| 3 | no content after filtering (all turns dropped) |

## How the collector calls the extractor

For a `--scope all` day with sessions from multiple projects:

```bash
horizon-extract.py \
  --session /path/to/proj-a/session1.jsonl \
  --session /path/to/proj-a/session2.jsonl \
  --session /path/to/proj-b/session3.jsonl \
  --date 2026-05-19 \
  --tz Europe/Warsaw \
  --stats-out /tmp/horizon-2026-W21-12345/day-1.stats.json \
  > /tmp/horizon-2026-W21-12345/day-1.txt
```

The collector inserts project-marker headers between sessions in the output
prose:

```
### {project-basename} — session {short-hash}

[2026-05-19T09:15:00+02:00 | user]
…
```

## `horizon-timesheet.py`

Deterministic per-project **active engaged time** for hourly billing. Reads
message timestamps from session JSONLs and sums inter-message gaps, capping
idle stretches. Independent of the collector — it goes straight to the raw
session logs and resolves each session's project from its in-file `cwd` field
(not the lossy dash-encoded dir name). Invoked at SKILL.md Step 5c, and usable
standalone for ad-hoc billing.

### Flags

```
--week YYYY-Www                    # OR --from + --to
--from YYYY-MM-DD                  # inclusive
--to   YYYY-MM-DD                  # inclusive
--tz IANA-TZ                       # required
--project LABEL                    # restrict to one project label (e.g. satori)
--cap MINUTES                      # idle-gap cap, default 5
--projects-dir PATH                # default ~/.claude/projects
--format {table,csv,json}          # default table
```

### Output

- **table** (default): human-readable, with a method/caveat footer.
- **csv**: one header row + one row per project. Columns:
  `window,project,active_hours,union_hours,sessions,messages,cap_minutes`.
  This is the invoice audit trail.
- **json**: `{"window","rows":[{project,active_h,union_h,sessions,messages}],"cap_minutes"}`.

Field meanings:

- `active_h` — sum of inter-message gaps, each capped at `--cap` minutes. The
  **billable floor**: hands-on-CC time with idle removed. Conservative (5-min
  cap drops thinking time over 5 min; counts long agent runs as user time, so
  it is an upper bound on keyboard-presence — `--cap 10` is the looser bound).
- `union_h` — deduped wall-clock the project's own sessions occupied
  (overlapping concurrent sessions of the SAME project counted once). If it
  lags `active_h`, the project's sessions overlapped each other — bill the
  smaller. **Cross-project** concurrency (two clients in one minute) is a human
  judgment call this script does not resolve.

### Exit codes

| Code | Meaning |
| --- | --- |
| 0 | OK |
| 2 | bad args (missing/invalid `--tz`, no window, malformed `--week`/`--from`/`--to`) |
| 3 | empty or future window (no in-window activity, or window starts in the future) |

### Standalone examples

```bash
# Whole-week breakdown, all projects
horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw

# One client, CSV for an invoice
horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw --project satori --format csv

# Looser keyboard-presence bound
horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw --project satori --cap 10

# Arbitrary date range
horizon-timesheet.py --from 2026-06-01 --to 2026-06-07 --tz Europe/Warsaw --format json
```
