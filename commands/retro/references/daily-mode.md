<!-- Derived from the `retroscope` plugin (0.3.1) in Tribe Coding claude-plugins, MIT License,
     Copyright (c) 2025 Tribe Coding. https://github.com/artem-from-ua/claude-plugins/tree/bcc769c14690b8d9da0230f8b3b34d551bb016e9/plugins/retroscope -->

# Daily Mode — Implementation Reference (today/yesterday)

## Step 4: Find Sessions

Where `{SCRIPT_DIR}` = `{PLUGIN_ROOT}/scripts`.

**If config `scope` is `"project"` (default):**

```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py {today|yesterday} \
  --project-dir "{CLAUDE_PROJECT_DIR}" \
  --tz "{config.timezone}"
```

Output: one file path per line.

**If config `scope` is `"all"` (cross-project):**

```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py {today|yesterday} \
  --all-projects \
  --tz "{config.timezone}"
```

Output: tab-separated `project_name\tfile_path`, one per line. Parse into a map: `{project_name: [file1, file2, ...]}`.

If no sessions found: inform user and stop.

**Resolve the report date.** `{YYYY-MM-DD}` is the day being reported (today, or today minus one day for `yesterday`) in `config.timezone`. Compute it instead of guessing; pass `0` for today or `1` for yesterday (an empty timezone argument means the system timezone):
```bash
PYTHONPATH="" python3 -c "import sys; from datetime import datetime, timedelta; from zoneinfo import ZoneInfo; tz = ZoneInfo(sys.argv[2]) if sys.argv[2] else None; print((datetime.now(tz) - timedelta(days=int(sys.argv[1]))).date())" {0|1} "{config.timezone}"
```
The session lists above include every session whose first-to-last span overlaps the day, so a session resumed weeks later is listed on days it was never touched. Steps 6 and 7 therefore scope all numbers and content to this date.

## Step 5: Check Cache

**If scope is `"project"` (default):**

Determine report output path:
```
{storageDir}/reports/{project_name}/daily/{YYYY}/{MM}/{DD}/summary.md
```

Where `{project_name}` = basename of `CLAUDE_PROJECT_DIR`.

**If scope is `"all"` (cross-project):**

```
{storageDir}/reports/_cross-project/daily/{YYYY}/{MM}/{DD}/summary.md
```

If `force` is set: skip cache check entirely, always regenerate.

Otherwise, if the file exists:
- Get modification time of summary.md
- Get modification times of all session files (across all projects if scope is `"all"`)
- If summary.md is newer than ALL session files → display cached report and stop

## Step 6: Gather Stats

For each session file, run:
```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --stats "{session_file}" \
  --date "{YYYY-MM-DD}" --tz "{config.timezone}"
```

`--date` limits the stats to records timestamped on that day (local to `--tz`; omit `--tz` if no timezone is configured). Without it, a session resumed across several days reports its whole multi-day span, tokens, and cost on every day it is listed.

**Drop sessions with no in-day Claude reply.** If a session's stats show `message_counts.assistant` of `0`, nothing happened in it on this day (typically a stray record on a resumed session). Remove it from the session count, every total, the per-project aggregates, and the Step 7 extraction.

Collect: token totals, tool counts, duration (`time_range.duration_minutes`), branches, models.

From each stats JSON, collect both `estimated_cost_usd` (actual cost with cache discounts) and `naive_cost_usd` (all input tokens at full rate, matches Claude Code UI display). Show both in the Productivity Metrics section.

Aggregate across all sessions for the Overview and Productivity Metrics sections.

**If scope is `"all"` (cross-project):** additionally track per-project aggregates: session count, total duration, estimated cost, and token counts per project. These feed the per-project breakdown table in the Overview section.

## Step 7: Extract Session Content

**If `extractMode: true` (default):**

For each session file, run:
```bash
PYTHONPATH="" python3 {SCRIPT_DIR}/find-sessions.py --extract "{session_file}" --date "{YYYY-MM-DD}"
```

Concatenate all extracted text (with session separators). **If scope is `"all"`:** include the project name in each session separator, e.g. `--- Session 2/5 (project: claude-plugins) ---`.

**If `extractMode: false`:**

Parse JSONL files via Bash — **never use the Read tool on `.jsonl` files** (they can exceed 256 KB / 25K tokens):
```bash
PYTHONPATH="" python3 -c "
import json, sys
for line in open(sys.argv[1]):
    obj = json.loads(line)
    if obj.get('type') in ('user', 'assistant'):
        print(json.dumps(obj))
" "{session_file}"
```

**If combined content exceeds ~100K tokens:**
- Warn user about large session size
- Process only the most recent 50% of exchanges

## Step 8: Generate Report

1. Read `{PLUGIN_ROOT}/commands/retro/references/report-template.md`
2. Generate report content based on the template and extracted session data. **If scope is `"all"`:** pass `is_cross_project: true` and the per-project breakdown data (from Step 6) to the report generator. The template title becomes `Cross-Project` instead of `{project_name}`, and the Overview includes a per-project breakdown table.
3. **If config `model` is `haiku`**: use the Task tool with `subagent_type: general-purpose` and `model: haiku` to generate the report body. Pass the extracted session text and template as context.
4. **If config `model` is `sonnet`**: use the Task tool with `subagent_type: general-purpose` and `model: sonnet` to generate the report body. Pass the extracted session text and template as context.
5. **If config `model` is `inherit`**: generate directly (current session model)

## Step 9: Save Report

1. Create directory structure. Use `{project_name}` for single-project scope, `_cross-project` for `"all"` scope:
   ```bash
   mkdir -p "{storageDir}/reports/{project_name|_cross-project}/daily/{YYYY}/{MM}/{DD}"
   ```

2. Write report to `summary.md`:
   ```
   {storageDir}/reports/{project_name|_cross-project}/daily/{YYYY}/{MM}/{DD}/summary.md
   ```
   **If the file already exists: Read it first, then use Edit to replace the content.** The Write tool blocks overwriting an unread file. Never skip the Read step when the file may exist from a previous run.

3. Git commit in storage repo:
   ```bash
   git -C "{storageDir}" add reports/{project_name|_cross-project}/daily/{YYYY}/{MM}/{DD}/summary.md
   git -C "{storageDir}" commit -m "retro({project_name|cross-project}): {YYYY-MM-DD} daily summary"
   ```

4. If `autoPush: true`:
   ```bash
   git -C "{storageDir}" push
   ```

## Step 10: Display

Show the generated report in the terminal. Include the file path where it was saved.

## Error Handling

- **No sessions found**: `No {today|yesterday} sessions found for project {name}. Sessions are stored per-project directory.`
- **Storage dir doesn't exist**: `Storage directory '{dir}' not found. Set `storageDir` in `~/.claude/retroscope.json` (see the cc-tools README, /retro section).`
- **Git not initialized**: `Storage directory is not a git repo. Run: git -C '{dir}' init`
- **Large session**: warn and offer to process with extract mode ON even if configured OFF
