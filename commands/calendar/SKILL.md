---
name: calendar
description: >
  Read and write Apple Calendar (and synced Google/CalDAV calendars).
  Reads via icalBuddy. Writes (create/delete events, including recurring)
  via AppleScript. Triggers: "calendar", "schedule", "what's on today",
  "my events", "next meeting", "free this week", "agenda", "what do I have",
  "busy tomorrow", "add to calendar", "create event", "schedule recurring",
  "remove from calendar", "delete event". Apple Calendar is the primary
  source; Google Calendars are pulled in via macOS sync.
---

# Calendar

Reads events from Apple Calendar (and Google/CalDAV calendars synced into it) using `icalBuddy`. Writes events (one-off and recurring) and deletes events via AppleScript (`osascript`).

## Requirements

- macOS with `icalBuddy` installed: `brew install ical-buddy`
- Calendar permission granted to the terminal running Claude Code (System Settings → Privacy & Security → Calendar → enable your terminal app). The same permission covers AppleScript reads/writes.
- Apple Calendar app open at least once, so calendars are synced locally
- Allowlist `Bash(icalBuddy:*)` and `Bash(osascript:*)` in `~/.claude/settings.json` to skip per-command prompts (both are safe — calendar permission is gated by macOS itself)

## Calendar groupings

If you subscribe to many calendars (personal + work + family + schedule feeds), grouping them into logical buckets keeps queries focused. Schedule feeds (bus timetables, school schedules, holiday calendars) will drown real events if you default to "all calendars".

The recommended buckets:

- **Core** — what you want for most work/life questions. Mix of personal + work + family.
- **Work-only** — only work calendars. Useful for focused planning.
- **Family-only** — only home/family/kid calendars. Useful for weekend planning or pickup logistics.
- **Noise** — schedule feeds (buses, schools, holiday calendars, bin-collection reminders). Always exclude unless explicitly asked.
- **On-demand** — list-style calendars (groceries, gifts, someday, maintenance). Include only when the question calls for it.

Configure your own calendar names for each bucket by editing this file or passing them directly via `-ic` (include) flags. Example: if you have work calendars named `you@work.com` and `Work Projects`, put them in the work-only bucket.

Note: macOS Reminders lists show up in `icalBuddy calendars` because Reminders shares the EventKit store. For tasks, use `icalBuddy uncompletedTasks` (see Tasks section below).

## Read queries

Prefer `-n` (no newlines between events) for compact output and `-b ""` to suppress the default bullet so output is scan-friendly. Use `-ic` (include) for targeted groupings and `-ec` (exclude) to filter noise from broad queries.

### Today's events (core calendars)

```bash
icalBuddy -ic "Home,Family,Work,you@work.com" -n eventsToday
```

### Remaining events today (from now)

```bash
icalBuddy -ic "<core calendars>" eventsFrom:now to:'today 23:59'
```

### Next 7 days (core calendars)

```bash
icalBuddy -ic "<core calendars>" eventsFrom:today to:'today+7'
```

### Work-only view (today or next 7 days)

```bash
icalBuddy -ic "Work,you@work.com" -n eventsToday
icalBuddy -ic "Work,you@work.com" eventsFrom:today to:'today+7'
```

### Family/kid schedule

```bash
icalBuddy -ic "Home,Family" eventsFrom:today to:'today+7'
```

### Everything, no filters (firehose — use sparingly)

```bash
icalBuddy -n eventsToday
```

### List all calendars

```bash
icalBuddy calendars 2>&1 | grep "^•" | sed 's/^• //'
```

## Write operations

Writes go through Calendar.app via `osascript`. The pattern: `tell application "Calendar"` → `tell calendar "<name>"` → `make new event with properties {...}`. The script returns the event UID, which you save and report back to the user — UID is the only handle for later deletion.

**Always confirm with the user before writing.** Show the resolved date/time/calendar/recurrence and ask for confirmation. Calendar writes are visible across all the user's devices (iCloud sync) and are not silent local-only operations.

### Create a one-off event

```bash
osascript <<'EOF'
tell application "Calendar"
  tell calendar "Ostap's Tasks"
    set newEvent to make new event with properties {summary:"Event title", start date:date "Monday, May 4, 2026 at 09:00:00", end date:date "Monday, May 4, 2026 at 09:30:00", description:"Optional notes"}
    return uid of newEvent
  end tell
end tell
EOF
```

The `date "..."` literal accepts macOS's local date format. Safer to compute dates programmatically (next snippet).

### Create an event at a computed time

When the user says "next Monday at 09:00" or "tomorrow at 3pm," compute the date inside AppleScript so you don't have to format a locale-dependent string:

```bash
osascript <<'EOF'
tell application "Calendar"
  tell calendar "Ostap's Tasks"
    set d to current date
    set hours of d to 9
    set minutes of d to 0
    set seconds of d to 0
    -- Roll forward to next Monday (weekday: 1=Sun..7=Sat, want 2=Mon)
    set wd to weekday of d as integer
    if wd is greater than or equal to 2 then
      set d to d + ((9 - wd) * days)
    else
      set d to d + ((2 - wd) * days)
    end if
    set newEvent to make new event with properties {summary:"Title", start date:d, end date:d + 30 * minutes}
    return uid of newEvent
  end tell
end tell
EOF
```

### Create a recurring event

Use the `recurrence` property with an RFC 5545 RRULE string (without the `RRULE:` prefix). Common patterns:

- Weekly on Monday: `"FREQ=WEEKLY;BYDAY=MO"`
- Weekdays only: `"FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"`
- Every other Friday: `"FREQ=WEEKLY;INTERVAL=2;BYDAY=FR"`
- Monthly on the 15th: `"FREQ=MONTHLY;BYMONTHDAY=15"`
- First Monday of each month: `"FREQ=MONTHLY;BYDAY=1MO"`
- Yearly on May 4th: `"FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=4"`
- With end date: `"FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T000000Z"`
- N occurrences: `"FREQ=WEEKLY;BYDAY=MO;COUNT=10"`

Add `recurrence:"FREQ=...;BYDAY=..."` to the properties dict in `make new event`. The `start date` becomes the first occurrence; subsequent ones are computed from the rule.

```applescript
set newEvent to make new event with properties {summary:"Weekly triage", start date:d, end date:d + 15 * minutes, recurrence:"FREQ=WEEKLY;BYDAY=MO"}
```

### Delete an event by UID

The UID is what the create script returns. Save it (in the daily note, or wherever the user expects) so future deletions are unambiguous.

```bash
osascript <<'EOF'
tell application "Calendar"
  tell calendar "Ostap's Tasks"
    delete (first event whose uid is "UID-FROM-CREATE")
    return "deleted"
  end tell
end tell
EOF
```

For recurring events, this deletes the whole series. AppleScript on Calendar.app does not expose per-occurrence deletion; if the user wants to skip a single occurrence, tell them to do it in Calendar.app directly.

### Verify a write landed

After creating an event, confirm via `icalBuddy` so the user sees it from a different vantage point (and to detect silent failures from Calendar.app):

```bash
icalBuddy -ic "Ostap's Tasks" eventsFrom:'2026-05-04' to:'2026-05-04 23:59'
```

## Output formatting flags (read)

- `-n` — separate events with a blank line (cleaner for multi-event days)
- `-b ""` — suppress bullet prefix
- `-nc` — no calendar names in output
- `-nrd` — no relative dates ("today at 14:00" → "2026-04-17 at 14:00")
- `-df "%Y-%m-%d"` `-tf "%H:%M"` — custom date/time formats
- `-iep "title,datetime,location,notes"` — only include these event properties (omit anything else)
- `-sed` — include end dates in output
- `-li N` — limit to N items

Example for programmatic parsing:

```bash
icalBuddy -nc -nrd -b "" -iep "title,datetime" -df "%Y-%m-%d" -tf "%H:%M" -ic "Work" eventsToday
```

## Tasks (Reminders)

Reminders lists are accessible via `icalBuddy` too — handy for a quick
date-context read without leaving a calendar query:

```bash
# Uncompleted tasks (from all Reminders lists)
icalBuddy uncompletedTasks

# Uncompleted tasks from specific lists
icalBuddy -ic "Tasks,Inbox" uncompletedTasks

# Tasks due today
icalBuddy tasksDueBefore:tomorrow
```

For anything beyond a glance — creating reminders, marking them complete, or a
guided reconcile/cleanup pass — use the **`/reminders` skill**, which owns
Reminders read+write end-to-end (and documents the AppleScript timeout and
partial-write gotchas this skill doesn't need to).

## Date/time range syntax (read)

`icalBuddy` accepts several forms for `eventsFrom:<start> to:<end>`:

- Keywords: `today`, `tomorrow`, `yesterday`, `now`
- Relative: `today+N`, `today-N`, `tomorrow+N` (N days)
- Absolute: `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS`
- Combined: `'today+7'`, `'tomorrow 09:00'`, `'2026-05-01 17:00'`

Always quote values with spaces.

## When to use this skill

Invoke when the user asks about:

- Today's / tomorrow's / this week's events
- Meetings, appointments, calls
- "What's on my calendar" / "am I free"
- "When is my next [X]"
- Upcoming deadlines or reminders tied to dates
- Schedule conflicts
- Adding a one-off or recurring event
- Removing a previously-added event (when the UID is known or findable)

## When NOT to use this skill

- For general task management without a date component → that's a to-do/GTD question, not a calendar one
- For historical scheduling ("what did I do last Tuesday") → prefer the daily note (`/daily-note` skill)
- For Obsidian-internal task tracking → use `obsidian-vault` skill
- For editing an existing event's time/title — AppleScript can do it, but the failure surface is high (especially for recurring events). Tell the user to edit in Calendar.app directly.

## Rules

- **Confirm before writing.** Show the resolved local date/time/calendar/recurrence and ask the user to confirm before creating or deleting. Calendar writes sync to all their devices and are visible to anyone they share calendars with.
- **Save the UID.** When creating, capture and report the returned UID. Without it, future deletion has to fall back to fuzzy `summary` matching, which is unsafe.
- **Default to filtered output (read).** Use the user's Core calendar grouping unless they ask for something specific. Raw `eventsToday` dumps 30+ items on a typical day with many subscribed calendars.
- **Name calendars verbatim.** Calendar names with spaces, apostrophes, or special chars must be quoted exactly as they appear in `icalBuddy calendars` (or in `osascript -e 'tell application "Calendar" to get name of every calendar'`).
- **Don't guess dates.** If the user says "next Thursday," convert to absolute YYYY-MM-DD first using the current date from context. For writes, prefer computing the date inside AppleScript over passing a `date "..."` literal — AppleScript date literals are locale-dependent and silently misparse.
- **Summarize, don't dump.** For multi-day views, group by day and highlight meetings over routine items. User cares about the exceptions.
- **Respect privacy.** Calendar events can include sensitive info (medical, financial). When summarizing, redact sensitive event details unless the user explicitly asks for the raw data.
- **Don't edit recurring events.** AppleScript can mutate properties, but Calendar.app handles edge cases (split a recurrence, modify single occurrence) badly. Direct the user to Calendar.app for edits.

## Allowlisting (for no-prompt access)

Add to `~/.claude/settings.json` or project-level `.claude/settings.local.json` under `permissions.allow`:

```json
"Bash(icalBuddy:*)",
"Bash(osascript:*)"
```

`icalBuddy` is read-only by design. `osascript` is broader (it can drive any macOS app), so the `:*` allowlist trades convenience for breadth — macOS still gates Calendar access via the per-app permission, so this skill is bounded by what Calendar.app itself allows.
