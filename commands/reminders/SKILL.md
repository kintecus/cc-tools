---
name: reminders
description: >
  Read and write Apple Reminders (and synced iCloud/CalDAV lists). Reads via
  icalBuddy (fast, read-only). Writes (create reminders, mark complete, and a
  guided reconcile/cleanup pass) via AppleScript. Triggers: "reminders", "my
  reminders", "what's due", "due today", "overdue reminders", "remind me to",
  "add a reminder", "create reminder", "mark X done", "complete reminder",
  "tick off", "clean up reminders", "reconcile reminders", "stale reminders".
  Apple Reminders is the source; iCloud lists sync via macOS.
---

# Reminders

Reads tasks from Apple Reminders (and iCloud/CalDAV lists synced into it) using
`icalBuddy` — the same fast, read-only tool the `/calendar` skill uses for
events. Writes (create, complete, and a guided cleanup) go through AppleScript
(`osascript`).

Read is the safe default and is fast (~0.5s). Writes are gated behind
confirmation and carry two non-obvious failure modes documented below
("Reminders gotchas") — read that section before any write.

## Requirements

- macOS with `icalBuddy` installed: `brew install ical-buddy`
- Reminders permission granted to the terminal running Claude Code (System
  Settings → Privacy & Security → Reminders → enable your terminal app). The
  same permission covers AppleScript reads/writes.
- Reminders app opened at least once so lists are synced locally
- Allowlist `Bash(icalBuddy:*)` and `Bash(osascript:*)` in
  `~/.claude/settings.json` to skip per-command prompts (both are safe —
  Reminders access is gated by macOS itself; see Allowlisting below)

## Lists

Reminders are organized into lists. Name them verbatim as they appear (spaces,
apostrophes, and non-ASCII must match exactly — `For Kid's` uses a curly
apostrophe). Get the current list names with:

```bash
osascript -e 'tell application "Reminders" to get name of lists'
```

Ostap's lists (as of this writing — re-list if unsure):

- **Inbox** — default catch-all; unfiled reminders land here
- **Bills & regular payments** — recurring financial obligations, tax filings
- **Someday** — low-priority / aspirational; do not surface as urgent
- **Trójka Klasowa** — class-parent group logistics (cash, invoices, follow-ups)
- **For Kid's** — kid-related tasks

When a question is list-specific, target with `-ic` (icalBuddy) or
`tell list "<name>"` (AppleScript). Default reads scan all lists; `Someday`
items should never be reported as urgent.

## Read queries

Read via `icalBuddy`. It returns name, list, due date, priority, and notes in
one fast call. Prefer `-n` (blank line between items) and `-b "• "` (or `-b ""`)
for scan-friendly output.

### All open reminders (every list)

```bash
icalBuddy -n -b "• " uncompletedTasks
```

### Open reminders from specific lists

```bash
icalBuddy -ic "Bills & regular payments,Inbox" -n -b "• " uncompletedTasks
```

### Due before a date (the urgency view)

```bash
icalBuddy tasksDueBefore:tomorrow          # due today or overdue
icalBuddy tasksDueBefore:'today+7'         # due within a week
```

Note: `tasksDueBefore:` only returns reminders that HAVE a due date. Reminders
with no due date are invisible to it — use `uncompletedTasks` to see everything.

### Compact output for parsing

```bash
icalBuddy -nc -b "" -iep "title,due,priority" uncompletedTasks
```

### List the Reminders list names

```bash
osascript -e 'tell application "Reminders" to get name of lists'
```

Do NOT enumerate reminders with AppleScript `whose completed is false` for a
plain read — it is slow and times out on large stores. `icalBuddy` is the read
path. AppleScript is for writes only.

## Reminders gotchas (read before any write)

These two behaviors are specific to the Reminders AppleScript bridge and are NOT
present in the `/calendar` skill. They are load-bearing — ignoring them produces
hangs or silent duplicates.

### 1. Always wrap `tell application "Reminders"` in `with timeout`

The default AppleEvent timeout is 120s. A cold first call to Reminders (app
launch + EventKit store sync) can exceed it and fail with:

```
execution error: Reminders got an error: AppleEvent timed out. (-1712)
```

Wrap EVERY Reminders tell block in `with timeout of N seconds` (use 300):

```applescript
with timeout of 300 seconds
  tell application "Reminders"
    -- ...
  end tell
end timeout
```

Without the wrapper, the first write of a session reliably times out. Set the
Bash tool `timeout` generously too (300000ms+) so the harness doesn't kill it
before AppleScript finishes.

### 2. A timed-out write may have already succeeded

When a write hits the AppleEvent timeout, the reminder is often ALREADY CREATED
— only the return value (the id) was lost. Blindly retrying creates a duplicate.

After ANY write error, **verify via `icalBuddy` before retrying**:

```bash
icalBuddy -b "• " uncompletedTasks 2>&1 | grep -F "<the reminder name>"
```

If it is already there, do not retry the create — just recover the id (or
report success). If a retry did create a duplicate, dedupe by name:

```bash
osascript <<'EOF' 2>&1
with timeout of 300 seconds
  tell application "Reminders"
    set dupes to (reminders whose name is "<exact name>")
    repeat with i from (count of dupes) to 2 by -1
      delete (item i of dupes)
    end repeat
    return "kept 1, deleted " & ((count of dupes) - 1)
  end tell
end timeout
EOF
```

## Write operations

**Always confirm with the user before writing.** Show the resolved
name / list / due date / priority and ask for confirmation. Reminders writes
sync to all the user's devices via iCloud — they are not local-only.

### Create a reminder

`make new reminder` defaults to the Inbox unless you target a list with
`tell list "<name>"`. The script returns an `x-apple-reminder://UUID` id — the
durable handle for later complete/delete. Capture and report it.

```bash
osascript <<'EOF' 2>&1
with timeout of 300 seconds
  tell application "Reminders"
    tell list "Inbox"
      set newR to make new reminder with properties {name:"Pay home insurance", body:"Required by mBank, ends 11 June"}
      return id of newR
    end tell
  end tell
end timeout
EOF
```

Optional properties: `due date`, `remind me date` (triggers an alert),
`priority` (0 none, 1 high, 5 medium, 9 low — Apple's scale), `body` (notes).

### Create with a due date

Compute the date inside AppleScript so you avoid locale-dependent date-literal
misparses (same caution as the calendar skill):

```bash
osascript <<'EOF' 2>&1
with timeout of 300 seconds
  tell application "Reminders"
    set d to current date
    set hours of d to 9
    set minutes of d to 0
    set seconds of d to 0
    set d to d + (3 * days)   -- due in 3 days at 09:00
    tell list "Bills & regular payments"
      set newR to make new reminder with properties {name:"File ZUS DRA", due date:d, remind me date:d, priority:1}
      return id of newR
    end tell
  end tell
end timeout
EOF
```

For an absolute date, build it explicitly:

```applescript
set d to (current date)
set year of d to 2026
set month of d to 6
set day of d to 20
set hours of d to 9
set minutes of d to 0
set seconds of d to 0
```

### Mark a reminder complete (the reversible write)

Completing is preferred over deleting — it is reversible (the reminder moves to
the completed list, not gone). Target by id (exact) or by name (fallback).

By id (preferred — use the handle from create, or recover it from a read):

```bash
osascript <<'EOF' 2>&1
with timeout of 300 seconds
  tell application "Reminders"
    set completed of (first reminder whose id is "x-apple-reminder://UUID") to true
    return "completed"
  end tell
end timeout
EOF
```

By name (fallback when the id is unknown — confirm the name is unique first via
a read, or you may complete the wrong one):

```bash
osascript <<'EOF' 2>&1
with timeout of 300 seconds
  tell application "Reminders"
    set matches to (reminders whose name is "Withdraw cash for Solya's trip" and completed is false)
    if (count of matches) is 1 then
      set completed of (item 1 of matches) to true
      return "completed"
    else
      return "ambiguous: " & (count of matches) & " matches — resolve by id"
    end if
  end tell
end timeout
EOF
```

If the name match is ambiguous (>1), do NOT guess — read the candidates back to
the user and complete by id.

### Verify a write landed

After any create/complete, confirm via `icalBuddy` so the user sees it from a
second vantage point (and to catch silent or timed-out partial writes):

```bash
icalBuddy -b "• " uncompletedTasks 2>&1 | grep -F "<reminder name>"
```

A created reminder appears in `uncompletedTasks`; a completed one disappears
from it.

## Reconcile / cleanup mode

The "make the list stop lying to you" pass. Reminders rot: items get done in
real life but never ticked, due dates pass, and "expires in a week"-style text
ages into nonsense. This is a guided, batch-confirmed sweep — the ONLY place
this skill deletes (delete is not a standalone verb elsewhere).

Flow:

1. **Read everything:** `icalBuddy -n -b "• " uncompletedTasks` (include due
   dates and notes).
2. **Flag stale candidates** — surface, do not act:
   - due date in the past (overdue)
   - title text implies a deadline already gone ("expires in a week",
     "ends tomorrow", a year that has passed)
   - duplicates of the same task across lists
   - items that the daily notes / recent work show as already done (e.g. a
     cert already rotated, a bill already paid)
3. **Propose per item:** for each flagged reminder, propose ONE of:
   `complete` (done in reality — reversible, default), `delete` (never going to
   happen / obsolete), `keep` (still live, ignore the staleness signal), or
   `reschedule` (still live but the due date is wrong — set a new due date).
4. **Batch-confirm:** present the full proposed action list and get a single
   confirmation before applying anything. Do not apply item-by-item silently.
5. **Apply** with the snippets above (`set completed to true`, `delete`, or set
   a new `due date`), each in a `with timeout` wrapper.
6. **Verify:** re-read `uncompletedTasks` and report the before/after count.

Prefer `complete` over `delete` whenever the task was genuinely done — it keeps
the history and is reversible. Reserve `delete` for obsolete/never-happening
items.

## When to use this skill

- "What are my reminders" / "what's due" / "anything overdue"
- "Remind me to X" / "add a reminder to X" (create)
- "Mark X done" / "tick off X" / "complete the X reminder"
- "Clean up my reminders" / "reconcile reminders" / "what's stale"
- Surfacing dated obligations during weekly triage/planning (the cross-check
  that catches deadlines the daily notes never recorded)

## When NOT to use this skill

- Date-anchored events (meetings, appointments, "schedule a call") → `/calendar`
- Obsidian-internal task tracking / daily-note todos → `obsidian-vault` /
  `daily-note`
- GTD triage of the week's daily notes → `/triage-week` (which may CALL this
  skill to cross-check reminders, but the triage itself lives there)
- Editing a reminder's title or other properties → AppleScript can, but the
  failure surface is high; prefer complete-and-recreate, or tell the user to
  edit in Reminders.app

## Rules

- **Read is the default; writes need confirmation.** Show the resolved
  name/list/due/priority and confirm before create/complete/delete. Writes sync
  to all the user's devices.
- **Always `with timeout of N seconds`.** Every Reminders tell block. No
  exceptions — the cold call times out otherwise (gotcha 1).
- **Verify after write; never blind-retry.** A timed-out write may have
  succeeded; check `icalBuddy` before retrying or you duplicate (gotcha 2).
- **Capture the id.** When creating, report the `x-apple-reminder://UUID` so
  complete/delete later are unambiguous.
- **Read with `icalBuddy`, write with `osascript`.** Never enumerate reminders
  via AppleScript `whose completed is false` for a plain read — slow, times out.
- **Name lists verbatim.** Match exactly, including curly apostrophes and
  non-ASCII (`For Kid's`, `Trójka Klasowa`).
- **Complete, don't delete, when the task was done.** Completion is reversible;
  deletion is not. Reserve delete for obsolete items, inside reconcile mode.
- **Don't surface `Someday` as urgent.** It is the aspirational bucket.
- **Don't guess due dates.** Convert "next Friday" to an absolute date from the
  current date in context; compute it inside AppleScript, not as a locale
  string literal.
- **Disambiguate by id, not by guessing.** If a name matches >1 reminder, read
  the candidates back; never act on the first arbitrary match.
- **Respect privacy.** Reminders can hold sensitive info (medical, financial).
  Redact when summarizing unless the user asks for raw data.

## Allowlisting (for no-prompt access)

Add to `~/.claude/settings.json` (or project `.claude/settings.local.json`)
under `permissions.allow`:

```json
"Bash(icalBuddy:*)",
"Bash(osascript:*)"
```

`icalBuddy` is read-only by design. `osascript` is broader (it can drive any
macOS app), so the `:*` allowlist trades convenience for breadth — macOS still
gates Reminders access via the per-app permission, so this skill is bounded by
what Reminders.app itself allows.
