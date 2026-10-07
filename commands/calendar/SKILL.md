---
name: calendar
description: >
  Read and write Apple Calendar (and synced Google/CalDAV calendars).
  Reads via icalBuddy. Writes (create/delete events, including recurring,
  irregular multi-date sets, and alert-free events) via a bundled EventKit
  script. Triggers: "calendar", "schedule", "what's on today",
  "my events", "next meeting", "free this week", "agenda", "what do I have",
  "busy tomorrow", "add to calendar", "create event", "schedule recurring",
  "remove from calendar", "delete event". Apple Calendar is the primary
  source; Google Calendars are pulled in via macOS sync.
---

# Calendar

Reads events from Apple Calendar (and Google/CalDAV calendars synced into it) using `icalBuddy`. Writes events (one-off, recurring, and irregular multi-date sets) via the bundled `calendar-ek` EventKit script.

**Read with `icalBuddy`, write with `calendar-ek`. Do not write with AppleScript** — see [Why writes don't use AppleScript](#why-writes-dont-use-applescript).

## Requirements

- macOS with `icalBuddy` installed: `brew install ical-buddy`
- Xcode Command Line Tools, for the `swift` interpreter the write script runs under: `xcode-select --install`
- Calendar permission granted to the terminal running Claude Code (System Settings → Privacy & Security → Calendars → enable your terminal app). The same permission covers the EventKit script.
- Apple Calendar app open at least once, so calendars are synced locally
- Allowlist `Bash(icalBuddy:*)` in `~/.claude/settings.json` to skip per-command prompts

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

All writes go through the bundled EventKit script:

```bash
CAL_EK="${CLAUDE_PLUGIN_ROOT}/commands/calendar/calendar-ek.swift"
```

Invoke it as `swift "$CAL_EK" <subcommand> [flags]` (or directly, it is executable). First run in a session takes a second or two while Swift compiles it; there is no build artifact to manage.

**Events are created with no alerts unless you pass `--alarm-minutes`.** That is the opposite of Calendar.app's behaviour, and it is deliberate — see [Why writes don't use AppleScript](#why-writes-dont-use-applescript).

**Always confirm with the user before writing.** Show the resolved dates, times, calendar, and recurrence, and ask for confirmation. Calendar writes sync to all their devices and are not local-only.

### Resolve the calendar name first

Titles must match exactly, and they are not unique — subscribed holiday calendars typically arrive once per account.

```bash
swift "$CAL_EK" calendars
# Family	[rw]	Google
# Holidays in Poland	[ro]	Google
# Holidays in Poland	[ro]	you@work.com
```

Ambiguous titles fail loudly; disambiguate with `--source "Google"`. Read-only (`[ro]`) calendars reject writes.

### Create a one-off event

```bash
swift "$CAL_EK" create --calendar "Family" --title "Dentist" \
  --start "2026-05-04 09:00" --duration 30 --notes "Optional notes"
```

Use `--end "YYYY-MM-DD HH:MM"` instead of `--duration` when the end time is what you know. `--all-day` for all-day events. Times are local; there is no locale-dependent parsing to get wrong.

### Create an irregular multi-date set ("loosely recurring")

When the user gives an explicit list of dates that no RRULE describes cleanly — a term timetable, a class that meets six times a year — create independent one-off events rather than forcing a rule:

```bash
swift "$CAL_EK" create --calendar "Family" --title "Class" \
  --dates 2026-10-28,2026-12-16,2027-03-03,2027-04-14 \
  --time 08:00 --duration 45
```

This is usually what "loosely recurring" means. **Do not approximate an irregular list with an RRULE** — a biweekly rule that happens to hit four of six requested dates also silently creates dozens of dates the user never asked for, with no end. Prefer N standalone events; they are trivially deletable one at a time.

### Create a recurring event

Pass an RFC 5545 RRULE (with or without the `RRULE:` prefix) alongside a single `--start`:

```bash
swift "$CAL_EK" create --calendar "Family" --title "Weekly triage" \
  --start "2026-05-04 09:00" --duration 15 --rrule "FREQ=WEEKLY;BYDAY=MO"
```

Common patterns:

- Weekly on Monday: `FREQ=WEEKLY;BYDAY=MO`
- Weekdays only: `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR`
- Every other Friday: `FREQ=WEEKLY;INTERVAL=2;BYDAY=FR`
- Monthly on the 15th: `FREQ=MONTHLY;BYMONTHDAY=15`
- First Monday of each month: `FREQ=MONTHLY;BYDAY=1MO`
- Yearly on May 4th: `FREQ=YEARLY;BYMONTH=5;BYMONTHDAY=4`
- With end date: `FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231T000000Z`
- N occurrences: `FREQ=WEEKLY;BYDAY=MO;COUNT=10`

Supported keys: `FREQ`, `INTERVAL`, `BYDAY` (with ordinals), `BYMONTHDAY`, `BYMONTH`, `BYSETPOS`, `COUNT`, `UNTIL`. Anything else is ignored; an unsupported `FREQ` is a hard error.

An open-ended rule runs forever. Default to `COUNT` or `UNTIL` unless the user genuinely wants that, and say which you used.

### Add alerts (opt-in)

```bash
swift "$CAL_EK" create ... --alarm-minutes 15 --alarm-minutes 60
```

Repeat the flag for multiple alerts. Omit it for none.

To clear alerts from events that already exist (e.g. created in Calendar.app, which applies the account default):

```bash
swift "$CAL_EK" strip-alarms --calendar "Family" \
  --from 2026-05-01 --to 2026-06-01 --title "Class"
```

### Find events and their ids

`list` prints the event identifier, which is the handle for deletion. Reads here are for write bookkeeping; for anything user-facing, `icalBuddy` output is nicer.

```bash
swift "$CAL_EK" list --calendar "Family" --from 2026-05-01 --to 2026-06-01 --title "Class"
# 2026-05-04 (Mon) 09:00-09:30 | Class | alarms=0 | rrule=none | id=<ACCOUNT>:<EVENT>
```

Occurrences of a series share one id, so a series prints once.

### Delete events

By id, which is unambiguous and the preferred form:

```bash
swift "$CAL_EK" delete --calendar "Family" --id "<ACCOUNT>:<EVENT>"
```

Repeat `--id` for several. By exact title within a date window when the id is unknown:

```bash
swift "$CAL_EK" delete --calendar "Family" --title "Class" --from 2026-05-01 --to 2026-06-01
```

Deleting a recurring event removes the whole series (`--span futureEvents`); a one-off removes just itself. Pass `--span` explicitly to override for an id-targeted delete. Title-matched deletes always remove a matched series wholesale — a `thisEvent` delete on one occurrence leaves the rest behind and reads as a failed delete.

**Run `list` first and show the user what matched** before a title-matched delete. It matches every event with that exact title in the window.

### Verify a write landed

Confirm through `icalBuddy` rather than the write tool, so the check comes from a different code path:

```bash
icalBuddy -nc -nrd -b "" -iep "title,datetime" -sed \
  -ic "Family" eventsFrom:'2026-05-04' to:'2026-05-04 23:59'
```

Re-run `list` too if alert state matters — `icalBuddy` does not show alarm counts.

### Why writes don't use AppleScript

This skill used to create events with `osascript` → `make new event`. Two defects make that path unusable for anything alert-sensitive:

1. **Alarms cannot be removed.** `delete every display alarm of <event>` fails with `Calendar got an error: AppleEvent handler failed. (-10000)`, in every syntactic form (`delete every display alarm`, a `repeat` over `display alarms`, inside or outside a `tell ev` block). The error aborts the enclosing script, so a loop creating N events stops after the first.
2. **New events silently inherit the account's default alert.** An event created with only `summary`/`start date`/`end date` comes back with a 15-minute display alarm attached. Combined with (1), "no alerts" is unreachable over AppleScript.

EventKit sets `alarms = nil` on save and it sticks. The script also gets real `EKSpan` control over recurring deletes, which Calendar.app's AppleScript interface does not expose at all.

AppleScript remains fine for reads and for driving Calendar.app's UI; just don't create or modify events with it.

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
- Removing a previously-added event (by id, or by exact title within a date range)
- Clearing alerts off events that already have them

## When NOT to use this skill

- For general task management without a date component → that's a to-do/GTD question, not a calendar one
- For historical scheduling ("what did I do last Tuesday") → prefer the daily note (`/daily-note` skill)
- For Obsidian-internal task tracking → use `obsidian-vault` skill
- For editing an existing event's time or title — there is no `update` subcommand by design. Delete and recreate a one-off, or tell the user to edit in Calendar.app.

## Rules

- **Confirm before writing.** Show the resolved local dates/times/calendar/recurrence and ask the user to confirm before creating or deleting. Calendar writes sync to all their devices and are visible to anyone they share calendars with.
- **Never write with AppleScript.** Use `calendar-ek`. The AppleScript path attaches alerts you cannot remove; see [Why writes don't use AppleScript](#why-writes-dont-use-applescript).
- **List the target range before creating.** Run `list` over the dates you are about to write and show anything already there. Creating blind produces duplicates, and a pre-existing series can quietly already cover the dates the user is asking for. Never delete a pre-existing event to make room without asking, even when it looks like a near-duplicate of the request.
- **Prefer N one-off events over an approximate rule.** If the requested dates don't fit an RRULE exactly, use `--dates`. An RRULE that fits *most* of them adds occurrences the user never asked for.
- **Bound every recurrence.** Use `COUNT` or `UNTIL` unless the user asks for an open-ended series, and state which you applied.
- **Save the event id.** Capture and report the id from `create`. Without it, deletion falls back to title matching, which can catch unrelated events.
- **Default to filtered output (read).** Use the user's Core calendar grouping unless they ask for something specific. Raw `eventsToday` dumps 30+ items on a typical day with many subscribed calendars.
- **Name calendars verbatim.** Titles with spaces, apostrophes, or trailing whitespace must match exactly as `swift "$CAL_EK" calendars` prints them. Duplicate titles need `--source`.
- **Don't guess dates.** If the user says "next Thursday," convert to an absolute `YYYY-MM-DD` using the current date from context, and state the weekday back to them so an off-by-one is visible.
- **Summarize, don't dump.** For multi-day views, group by day and highlight meetings over routine items. User cares about the exceptions.
- **Respect privacy.** Calendar events can include sensitive info (medical, financial). When summarizing, redact sensitive event details unless the user explicitly asks for the raw data.
- **Don't edit existing events.** `calendar-ek` deliberately has no `update`. Calendar.app handles recurrence edge cases (splitting a series, changing one occurrence) badly, and so would a script. Delete-and-recreate a one-off, or send the user to Calendar.app.

## Allowlisting (for no-prompt access)

Add to `~/.claude/settings.json` or project-level `.claude/settings.local.json` under `permissions.allow`:

```json
"Bash(icalBuddy:*)"
```

`icalBuddy` is read-only by design, so allowlisting it is safe.

Deliberately **not** allowlisted: the write script. `Bash(swift:*)` would allow running arbitrary Swift, and `calendar-ek` itself creates and deletes events that sync to every device. Leaving writes to a per-call prompt is the point — it is the last checkpoint before a destructive `delete` reaches iCloud. Confirm with the user in conversation too; the permission prompt shows a command line, not what it will match.
