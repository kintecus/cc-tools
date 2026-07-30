---
name: statusline
description: >
  Configure, preview, or troubleshoot the compact single-line Claude Code
  statusline bundled with this plugin. Triggers: "set up my statusline",
  "configure statusline", "statusline not showing", "statusline is blank",
  "change what the statusline shows", "preview my statusline", "enable the
  statusline". Use when the user wants to install the statusline into
  settings.json, see what it renders, or diagnose why it is missing or stale.
disable-model-invocation: true
---

# Statusline

A single-line statusline for Claude Code. Every value comes from the JSON
payload Claude Code pipes to the script on stdin, so it makes no network calls
and reads no credentials.

```
5h 92% 50m !!  7d 22% ~5d  $0.42  Opus 5  xhigh  30%  1M  owner/repo  main*  #42
```

| Segment | Source field | Notes |
|---|---|---|
| `5h` / `7d` | `rate_limits.five_hour` / `.seven_day` | Countdown to reset appears at >=60% |
| `$0.42` | `cost.total_cost_usd` | Session spend |
| `Opus 5` | `model.display_name` | Brightness = tier: Opus/Fable bright, Sonnet default, Haiku dim |
| `xhigh` | `effort.level` | Hidden when `medium` |
| `30%` | `context_window.used_percentage` | `!!` at >=80% |
| `1M` | `exceeds_200k_tokens` | Session passed 200k, so the 1M-context variant is live |
| `owner/repo` | `workspace.repo` | Falls back to the directory basename outside a git repo |
| `main*` | `git status -b` | `*` means dirty; not in the payload, so one git call is needed |
| `#42` | `pr` | Green approved, red changes requested, dim pending, faint draft |

Values dim at low usage and brighten as they climb: yellow above 90%, red at
100%. `!!` warns, `XX` means exhausted.

## Install it

The SessionStart hook keeps `~/.claude/statusline-tools.sh` in sync with the
plugin automatically. It does **not** edit settings, so the last step is manual
and deliberate.

1. Confirm the script is present. If it is missing, the hook has not run yet
   (restart Claude Code) or the plugin is not enabled:

   ```bash
   ls -l ~/.claude/statusline-tools.sh
   ```

2. Point `~/.claude/settings.json` at it:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline-tools.sh"
     }
   }
   ```

   Read the file, add or replace the `statusLine` key, and write it back. Never
   clobber unrelated keys.

3. Restart Claude Code.

**Before changing an existing `statusLine`,** show the user what it currently
points at and confirm the switch. Another plugin may own it.

## Preview without installing

Feed the script a sample payload. Strip the ANSI codes to read it as plain text:

```bash
echo '{
  "workspace": {"current_dir": "'"$PWD"'", "repo": {"owner": "owner", "name": "repo"}},
  "model": {"display_name": "Claude Opus 5"},
  "context_window": {"used_percentage": 52.3},
  "cost": {"total_cost_usd": 0.42},
  "effort": {"level": "high"},
  "rate_limits": {
    "five_hour": {"used_percentage": 12.4, "resets_at": 3000000000},
    "seven_day": {"used_percentage": 45.9, "resets_at": 3000200000}
  },
  "pr": {"number": 42, "review_state": "approved"}
}' | ~/.claude/statusline-tools.sh | sed 's/\x1b\[[0-9;]*m//g'
```

Vary the fields to check a specific segment. Omitting a key hides its segment,
which is the correct behaviour rather than a bug.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Nothing renders at all | `statusLine` not set, or points elsewhere | Check `jq '.statusLine' ~/.claude/settings.json` |
| Renders the old version | Another plugin owns `~/.claude/statusline.sh` and settings point there | Repoint settings at `statusline-tools.sh` |
| Script exists but output is empty | `jq` missing, or the payload failed to parse | `which jq`; then pipe a sample payload in by hand |
| No `5h` / `7d` segments | Expected on API-key, Bedrock, or Vertex sessions | `rate_limits` is only sent to Claude.ai subscribers |
| No `#42` segment | No open PR for the branch, or the version predates the field | Confirm with `gh pr list --head "$(git branch --show-current)"` |
| Segments missing on a wide terminal | Progressive hiding measured a narrow width | Drop order is repo, then cost, then effort |

## Changing what it shows

Segments are built in `scripts/statusline.sh` between the `BUILD SEGMENTS` and
`ASSEMBLE` banners. Each one sets a coloured string **and** a plain-text twin via
`set_seg`; the plain twin is what the width math reads, so a segment added
without one will break progressive hiding. Add the index to the `join_idx` calls
under `PROGRESSIVE HIDING` to place it and to choose when it gets dropped.

After editing, run `./scripts/sync-to-cache.sh` from the repo root so the next
session picks it up, and bump the plugin version.

Two constraints worth keeping:

- **bash 3.2.** That is what `/bin/bash` is on macOS. No `EPOCHSECONDS`, no
  `${x,,}`, no associative arrays.
- **Subprocess budget.** This runs on every render. One `jq` pass and one `git`
  call is the whole budget; a stray `sed` in a loop is what made the earlier
  version take 260 ms instead of 70 ms.
