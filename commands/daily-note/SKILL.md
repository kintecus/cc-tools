---
name: daily-note
description: >
  Read and append to Ostap's Obsidian daily note. Use when the user asks to
  log activity, update the daily note, check today's tasks, or note something down.
  Keywords: daily note, log, obsidian, today, tasks, note that down, wrap up.
---

# Obsidian daily note

The daily note is the single source of truth for the day's activities across all projects and contexts.

## CLI reference

All commands use the Obsidian CLI. Always filter stderr noise:

```bash
OBSIDIAN="/Applications/Obsidian.app/Contents/MacOS/obsidian"
```

### Read today's note

```bash
$OBSIDIAN daily:read 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

### Append to today's note

```bash
$OBSIDIAN daily:append content="- **HH:MM** [[Project]] - description" 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

### List open tasks from today's note

```bash
$OBSIDIAN tasks daily todo 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

### Complete a task

```bash
$OBSIDIAN task daily line=N done 2>&1 | grep -v "Loading updated\|out of date\|better CLI"
```

## Activity log format

```
- **HH:MM** [[Project]] - what happened
```

Examples:
```
- **14:32** [[Satori Ads]] - implemented barcode validation endpoint
- **16:10** [[Xenoss]] - closed out Ogury project documentation on Confluence
- **09:45** [[job-hunt-2026]] - tailored CV for Datadog role, submitted application
```

Use 24h time. Use wikilinks for projects and people. Keep entries terse - one line per activity.

## Project wikilink mapping

Infer the project from the current working directory:

| cwd pattern | Wikilink |
|---|---|
| `*/satori*` | `[[Satori Ads]]` |
| `*/xenoss*` | `[[Xenoss]]` |
| `*/job-hunt*` | `[[job-hunt-2026]]` |
| `*/homelab*` | `[[Homelabbing on MBP]]` |
| other | Use the folder/repo name |

## Rules

- **Only append when asked.** Log activity when the user says "log this", "update daily note", "note that down", "wrap up", or similar. Never auto-append.
- **Read for context.** The daily note is injected at session start. Re-read mid-session with `daily:read` if needed.
- **TODOs are read-only** unless the user explicitly asks to check off or add a task.
- **Privacy.** Only interact with today's daily note via `daily:*` commands. Do not browse the broader vault through this skill.
- **Obsidian must be running** for CLI commands to work. If a command fails, tell the user to open Obsidian.
