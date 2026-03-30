---
name: reflect
description: >
  End-of-day review: compare daily note plan vs actual activity, summarize to
  daily note, update auto-memory with durable insights. Run manually at end of
  day or when wrapping up. Keywords: reflect, review, end of day, wrap up day,
  what did I do today.
---

# End-of-day reflect

Review the day's plan vs actual activity, append a summary to the daily note, and update auto-memory with anything durable.

## Step 1: Gather inputs

Run these sequentially. All read-only.

### 1a. Read today's daily note

```bash
/Applications/Obsidian.app/Contents/MacOS/obsidian daily:read 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

### 1b. Scan git activity across active repos

```bash
for dir in ~/code/satori/walletsvc ~/code/satori/magnolia ~/code/satori/adcreator ~/code/xenoss/forecasting-api ~/code/personal/cc-tools ~/code/dotfiles ~/code/homelab ~/code/build ~/code/tribe-coding/claude-plugins; do
  COMMITS=$(git -C "$dir" log --since="00:00" --oneline --all 2>/dev/null)
  if [ -n "$COMMITS" ]; then
    echo "=== $(basename $(dirname $dir))/$(basename $dir) ==="
    echo "$COMMITS"
    echo
  fi
done
```

### 1c. Read current memory index

Read `~/.claude/projects/-Users-ostaps-code/memory/MEMORY.md` to know what memories exist.

### 1d. Read retroscope session stats

Use the retroscope session finder to get time and cost data. This is required - time tracking is a core output.

```bash
FINDER="$HOME/.claude/plugins/marketplaces/tribe-coding/plugins/retroscope/scripts/find-sessions.py"

# Get today's session files
SESSION_FILES=$(python3 "$FINDER" today --tz Europe/Warsaw 2>/dev/null)

# For each session, get stats
for f in $SESSION_FILES; do
  python3 "$FINDER" --stats "$f" 2>/dev/null
done
```

Stats JSON includes: `duration_seconds`, `total_input_tokens`, `total_output_tokens`, `estimated_cost_usd`, `naive_cost_usd`, `tool_counts`, `models`, `cwd`, `branches`.

Group sessions by project using the `cwd` field:
- `*/satori/*` -> `[[Satori Ads]]`
- `*/xenoss/*` -> `[[Xenoss]]`
- `*/personal/cc-tools*` -> `[[tools@kintecus]]`
- `*/dotfiles*` -> dotfiles
- `*/code/` (workspace root) -> global session
- Otherwise: use the folder name

## Step 2: Analyze

Compare the daily note's TODOs and NOTES against actual git activity and session data:

- **Plan vs actual**: which TODOs got checked off? Which are still open? Were they worked on at all?
- **Unlogged work**: git commits or session activity not reflected in the daily note
- **Time allocation**: how much time went to each project? Does this match stated priorities?
- **Carry-overs**: unchecked TODOs that are still relevant for tomorrow
- **Honesty check**: note procrastination, yak-shaving, and tangents without judgment. If 3 hours went to plugin setup instead of the P0 Satori work, say so.

## Step 3: Append to daily note

Use `obsidian daily:append` to add the review. Format:

```
## End of day review

### Plan vs actual
- [narrative summary: what got done, what didn't, surprises]

### Unplanned work
- [stuff that wasn't in the morning TODOs but consumed time]

### Time spent
- [[Project]] - Xh Ym across N sessions ($X.XX)
- [[Project]] - Xh Ym across N sessions ($X.XX)
- Total: Xh Ym, $X.XX

### Git activity
- [[Project]] - N commits: [brief summary of changes]

### Carry-overs for tomorrow
- [ ] [unchecked TODOs still relevant]
- [ ] [new items that surfaced today]
```

Use wikilinks for projects and people. Keep the tone direct and honest - this is a mirror, not a report card.

```bash
/Applications/Obsidian.app/Contents/MacOS/obsidian daily:append content="[formatted review]" 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

## Step 4: Update auto-memory

Review the day's activity for durable insights worth persisting to `~/.claude/projects/-Users-ostaps-code/memory/`. For each insight:

1. Check if an existing memory file covers it
2. Update if stale, create if new, skip if ephemeral
3. Update MEMORY.md index if files changed

**Save** (examples):
- New project decisions or deadlines discovered during work
- Workflow patterns validated by today's usage ("daily note + CC works well")
- User preferences confirmed by behavior

**Don't save**:
- Today's task list or TODO state (that's in the daily note)
- Current debugging context (ephemeral)
- Anything already in CLAUDE.md or derivable from git

## Rules

- Run all input gathering before analysis - don't interleave
- If retroscope session data is unavailable (no sessions, script not found), proceed without time tracking and note the gap
- If Obsidian is not running, display the review in the terminal instead and tell the user to copy it manually
- Never modify existing daily note content - only append
- Be honest about time allocation. The point is self-awareness, not self-congratulation.
