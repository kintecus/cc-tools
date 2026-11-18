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

This skill owns the *workflow* (what to log, format, rules). For general Obsidian CLI syntax and behavior, see the `obsidian:obsidian-cli` skill from the official `obsidian@obsidian-skills` plugin; for Markdown syntax (wikilinks, callouts, properties), see `obsidian:obsidian-markdown`.

## Target vault

The daily note lives in one specific vault, so always target it explicitly - never rely on cwd or "last focused vault" resolution (the user may have several vaults, and a session's cwd may itself be a vault).

1. Read `vault.name` from `~/.config/cc-tools/config.yaml`.
2. If the file or key is missing, run `obsidian vaults` and ask the user which vault holds their daily notes.

`vault=` must be the **first** parameter, before the subcommand. Below, `$VAULT` stands for that name.

## CLI reference

```bash
obsidian vault="$VAULT" daily:read                                   # read today's note
obsidian vault="$VAULT" daily:append content="- **HH:MM** [[Project]] - description"
obsidian vault="$VAULT" daily:append heading="TODOs" content="- [ ] task"   # insert at end of a section
obsidian vault="$VAULT" tasks daily todo                             # open tasks in today's note
obsidian vault="$VAULT" task daily line=N done                       # complete a task
obsidian vault="$VAULT" daily:path                                   # vault-relative path of today's note
```

- **Exit code is always 0**, even on failure. Read stdout: success prints `Appended to: ...`; failure prints `Error: ...`.
- Multi-line `content=` works (real newlines or `\n`). `\n` and `\t` escapes are always converted, so write content containing backslashes directly to the file instead.
- If Obsidian isn't running, the first CLI call launches it. If the CLI is unavailable, fall back to the file: `"$(obsidian vault="$VAULT" vault info=path)/$(obsidian vault="$VAULT" daily:path)"`, or ask the user for the vault path.

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

Infer the project from the current working directory. If `~/.config/cc-tools/config.yaml` has a `projects:` list (`pattern` → `wikilink`), use it; otherwise:

| cwd pattern | Wikilink |
|---|---|
| `*/satori*` | `[[Satori Ads]]` |
| `*/client-project*` | `[[Client]]` |
| `*/job-hunt*` | `[[job-hunt-2026]]` |
| `*/homelab*` | `[[Homelabbing on MBP]]` |
| other | Use the folder/repo name |

## Rules

- **Only append when asked.** Log activity when the user says "log this", "update daily note", "note that down", "wrap up", or similar. Never auto-append.
- **Read for context.** Re-read with `daily:read` mid-session if needed; it is not injected at session start.
- **TODOs are read-only** unless the user explicitly asks to check off or add a task. New tasks go under the TODOs heading via `heading=`, not at end of file.
- **Privacy.** Only touch today's daily note through this skill (`daily:*`, `tasks daily`, `task daily`). Do not browse the broader vault from here.
- **Verify writes.** After an append, check stdout for `Appended to:`; for anything structured, `daily:read` it back.
