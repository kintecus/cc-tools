---
name: daily-note
description: >
  Read and append to Ostap's Obsidian daily note. Triggers: "daily note",
  "log this", "note that down", "what's on today", "today's tasks",
  "wrap up", "end of day", "check daily", "open tasks", "update daily",
  "obsidian daily", "what did I do today".
  Always use this skill for any daily note interaction.
---

# Obsidian daily note

The daily note is the single source of truth for the day's activities across all projects and contexts.

## CLI reference

All commands use the `obsidian-cli` wrapper, which auto-pins to "Obsidian Vault" and filters stderr noise.

If the CLI returns empty or fails (Obsidian not running), fall back to reading the file directly:

```bash
DAILY_FILE="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian Vault/Journal/Daily/$(date +%Y-%m-%d).md"
```

> **Grammar note:** `daily` is a bare modifier, not a `daily:` namespace.
> `daily:read` / `daily:append` return "Command not found". The wrapper pins
> the vault for you (and `vault=` must precede the subcommand, which it handles).

### Read today's note

```bash
obsidian-cli read daily
```

### Append to today's note

```bash
obsidian-cli append daily content="- **HH:MM** [[Project]] - description"
```

### List open tasks from today's note

```bash
obsidian-cli tasks daily todo
```

### Complete a task

```bash
obsidian-cli task daily line=N done
```

## Activity log format

```
- **HH:MM** [[Project]] - what happened
```

Examples:
```
- **14:32** [[Satori Ads]] - implemented barcode validation endpoint
- **16:10** [[Client]] - closed out client project documentation on Confluence
- **09:45** [[job-hunt-2026]] - tailored CV for a role, submitted application
```

Use 24h time. Use wikilinks for projects and people. Keep entries terse - one line per activity.

## Project wikilink mapping

Infer the project from the current working directory:

| cwd pattern | Wikilink |
|---|---|
| `*/satori*` | `[[Satori Ads]]` |
| `*/client-project*` | `[[Client]]` |
| `*/job-hunt*` | `[[job-hunt-2026]]` |
| `*/homelab*` | `[[Homelabbing on MBP]]` |
| other | Use the folder/repo name |

## Rules

- **Only append when asked.** Log activity when the user says "log this", "update daily note", "note that down", "wrap up", or similar. Never auto-append.
- **Read for context.** The daily note is injected at session start. Re-read mid-session with `obsidian-cli read daily` if needed.
- **TODOs are read-only** unless the user explicitly asks to check off or add a task.
- **Privacy.** Only interact with today's daily note via the `daily` modifier (`read daily`, `append daily`, `tasks daily`, `task daily`). Do not browse the broader vault through this skill.
- **Obsidian must be running** for CLI commands to work. If a command fails, tell the user to open Obsidian.
