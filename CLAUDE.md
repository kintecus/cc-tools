# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. For the user-facing project overview, commands, and installation, see [`README.md`](README.md).

## What this is

A Claude Code plugin (`tools@kintecus`) packaging personal productivity skills: writing voice transformation, Amazon-style document rigor, Obsidian daily note integration, and PM principles generation.

## This is a PUBLIC repo — leak hygiene is paramount

`kintecus/cc-tools` is **public**. Anything committed here is world-readable and, because git history is permanent, effectively un-deletable without a history rewrite or repo recreation (the latter is what it took to clean this repo once already). The danger is specific: these skills are useful *because* they encode real personal context (real repo paths, project names, project states, colleagues, clients), and that same context must NOT land in committed examples.

**Standing rule — flag before building.** When the user proposes a new skill/agent, or an edit to an existing one, and the natural implementation would bake in personal or otherwise non-public information, **flag it to the user before writing it** and propose a placeholder-based alternative. Do not silently commit real values and assume they can be scrubbed later. Things that must stay generic in committed content:

- **Real names** — colleagues, clients, family. Use placeholders (the established convention: `Alex`, `Jordan`, `Sam` for people; `[[Client]]` / `client-project` for third-party clients).
- **Client / employer-confidential references** — third-party client names, internal environment names, real business metrics. (The user's own company `Satori Ads` and own projects `puch`/`homelab`/`job-hunt-2026` are intentionally kept — those are public-facing under his own name.)
- **Personal absolute paths** — anything under the user's home or external volumes that exposes the OS username or machine layout. Prefer `~/...` or generic example paths in docs/examples.
- **Financial / personal-life specifics** — tax filings, banks, school/class logistics, health. These belong in the user's private Obsidian vault and auto-memory, never in a committed example.
- **Secrets** — env-var references only (`${GEMINI_API_KEY}`), never literal keys. (None exist today; keep it that way.)

**When in doubt, ask.** A one-line "this example would expose X — want a generic placeholder instead?" is always cheaper than a history rewrite. The decision was explicitly to rely on this authoring-time discipline rather than an automated pre-commit gate, so the discipline is load-bearing.

## Plugin structure

Follows the [tribe-coding plugin conventions](https://github.com/tribe-coding/claude-plugins):

```
.claude-plugin/
  plugin.json           # manifest (name, version, commands; skills is empty [])
  marketplace.json      # marketplace registration
hooks/
  hooks.json            # SessionStart + plan-review gate hook definitions
scripts/
  inject-rules.sh       # SessionStart: plan-review rule + effort-estimate rule + today's Obsidian daily note
  plan-review-checkpoint.sh  # PostToolUse(ExitPlanMode): checkpoint reminder + sets pending-review marker
  plan-review-gate.sh   # PreToolUse(edit tools): "ask" prompt before first edit while marker exists
  plan-review-clear.sh  # PostToolUse(edit tools): clears marker after an edit
  plan-review-marker.sh # shared helper: marker path + session_id parse (sourced by the three above)
commands/
  commit/               # git committer (conventional commits + impact framing)
    SKILL.md
  build-partner/        # senior engineering-partner persona (Rams/Fadell/Shape Up/YAGNI)
    SKILL.md
  pr/                   # PR creation with structured template
  research/             # web research (quick lookup + deep)
  prose-deslop/         # writing voice transformation
    SKILL.md
    formats/            # email.md, slack.md, prd.md, vision-doc.md
  amazon-writing/       # Amazon-style writing rigor
    SKILL.md
    references/         # source-prompt.md
  daily-note/           # Obsidian daily note read/append
    SKILL.md
  reflect/              # End-of-day review and memory update
    SKILL.md
  pm-principles/        # PM principles interview + generation
    SKILL.md
  review-plan/          # fresh-context plan review
    SKILL.md
    references/         # protocol.md
  clippings-digest/     # Obsidian clippings digest + HTML editorial page
    SKILL.md
    templates/          # digest-page.html (frozen design system)
    references/         # component-kit.md (bespoke component vocabulary)
  podcast-digest/       # pidcast transcript digest + HTML editorial page
    SKILL.md
    templates/          # digest-page.html (frozen design system, podcast variant)
    references/         # component-kit.md (bespoke component vocabulary)
  ask-gemini/           # delegate a question to Google Gemini
    SKILL.md
    ask-gemini          # the wrapper script (executable; bundled with the skill)
  yt-transcript/        # search/quote/summarize a YouTube video by its captions
    SKILL.md
    yt-transcript       # the caption-fetch+clean script (executable; bundled)
```

Note: `commands/ask-gemini/` is the first skill that ships its own executable
inside the command dir. The skill invokes it via
`${CLAUDE_PLUGIN_ROOT}/commands/ask-gemini/ask-gemini`; it is also exposed on
`PATH` as bare `ask-gemini` via a symlink in `~/.claude/bin/` (same pattern as
`scripts/obsidian-cli`).

## Key conventions

- **SKILL.md frontmatter**: every skill needs `name` and `description` in YAML frontmatter per [agentskills.io spec](https://agentskills.io/specification)
- **Path references**: use `${CLAUDE_PLUGIN_ROOT}` for cross-skill references, never hardcoded paths
- **Hook scripts**: use `${CLAUDE_PLUGIN_ROOT}` in hooks.json, with `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"` fallback in scripts
- **SessionStart output**: the two static rule blocks (plan-review, effort-estimate) are deterministic and benefit from API prefix caching, so keep each terse but they are not the token-budget constraint. The 300-token target is about the non-deterministic **daily-note** injection (content changes during the day, so it won't cache) — that is the part to keep lean
- **No `skills/` directory**: all skills are user-invoked commands under `commands/`, so `plugin.json` points `commands` at `./commands/` and leaves `skills` empty (`[]`)

## Plan-review gate (deterministic enforcement)

The plan-review offer is enforced by a **session-keyed marker**, not just injected text — text reminders alone get rationalized past (notably: "auto-accept edits" misread as a review decline).

- **Marker**: `${TMPDIR:-/tmp}/cc-plan-review-pending-<session_id>`. Path + `session_id` parsing live in `scripts/plan-review-marker.sh`, sourced by all three hook scripts so the convention has a single source of truth.
- **Lifecycle**: `plan-review-checkpoint.sh` (PostToolUse/ExitPlanMode) **sets** it → `plan-review-gate.sh` (PreToolUse/edit-tools) **hard-blocks the edit with `exit 2`** while it exists → the block is resolved by clearing the marker (`/review-plan` Step 0, or Claude `rm`s it on the decline path), re-armed by a new plan. `plan-review-clear.sh` (PostToolUse/edit-tools) also clears it after a successful edit, as a backstop.
- **Why `exit 2`, not `permissionDecision: "ask"`**: on Claude Code 2.1.x an `ask` from a plugin hook is overridden by `permissions.allow` rules (the user allow-lists `Write/Edit(~/code/**)`, which every plan touches) and is unreliably honored anyway (issues #52822/#13339/#39344). **`exit 2` blocks before permission rules are evaluated**, so it overrides allow-rules — the only mechanism that reliably stops the edit. Verified empirically: the `ask` gate produced no prompt on 2.1.168; exit 2 is the replacement.
- **Loop avoidance**: a blocked edit never reaches `plan-review-clear.sh`, so the marker can't auto-clear — it would block forever. The gate's **stderr instructs Claude to clear the marker explicitly** when the user resolves the block (run `/review-plan`, or `rm -f` the marker then retry). This is load-bearing: do not remove the clear instructions from the stderr.
- **Session id**: the hook stdin `session_id` equals the `CLAUDE_CODE_SESSION_ID` env var available in Bash/skill context (verified — same value names the transcript jsonl). That equality is what lets the skill's clear match the gate's marker.
- **Fail-open invariant**: only the marker-present branch exits non-zero. Gate and clear use `set -uo pipefail` (no `-e`) and swallow every error → a broken hook or missing marker exits 0 and never blocks a legitimate edit. The checkpoint likewise never lets the marker step abort its context emission. Preserve this when editing these scripts.

## Obsidian CLI dependency

The daily-note skill and SessionStart hook require the Obsidian CLI (`/Applications/Obsidian.app/Contents/MacOS/obsidian`, v1.12+). Obsidian must be running. The hook fails silently if Obsidian is closed.

## Commands

| Command | Trigger | Description |
|---------|---------|-------------|
| `/prose-deslop` | "de-slop", "humanize", "make it sound like me" | Voice transformation with format-specific rules |
| `/amazon-writing` | "finalize", "make it crisp", "no fluff" | Data-driven writing rigor |
| `/daily-note` | "log this", "update daily note", "note that down" | Obsidian daily note read/append |
| `/obsidian-vault` | "obsidian", "vault", "search vault", "read note", "look up in vault" | Read and navigate the Obsidian vault via the CLI: search, follow links, explore the knowledge graph. Read-only by default |
| `/reflect` | "end of day", "wrap up day", "what did I do today" | Plan vs actual review, time tracking, memory updates |
| `/pm-principles` | explicit invocation only | PM principles interview generator |
| `/research` | "research X", "look up X", "find docs for", "compare X vs Y" | Web research with quick/deep modes |
| `/pr` | "create PR", "open PR", "push and create PR" | Structured PR with user-facing impact |
| `/calendar` | "calendar", "schedule", "what's on today", "add to calendar", "create event", "schedule recurring" | Read Apple Calendar via icalBuddy; create/delete events (one-off + recurring) via AppleScript |
| `/reminders` | "reminders", "what's due", "overdue", "remind me to", "add a reminder", "mark X done", "clean up reminders", "reconcile reminders" | Read Apple Reminders via icalBuddy (fast, read-only); create reminders, mark complete, and run a guided reconcile/cleanup pass via AppleScript. Read-safe default; writes confirmed. Documents the Reminders AppleScript `with timeout` requirement and the timed-out-write-may-have-succeeded gotcha |
| `/review-plan` | "review plan", "critique plan", after plan mode | Fresh-context subagent critiques an implementation plan before any code; re-estimates the effort block on the revised plan |
| `/clippings-digest` | "digest clippings", "review clippings", "what have I clipped" | Digest unreviewed Obsidian clippings to the daily note + a self-contained HTML editorial page in `~/clipping-summaries/` |
| `/podcast-digest` | "podcast digest", "digest my podcasts", "summarize recent podcasts", "what have I listened to" | Editorial digest of recent `pidcast` podcast/YouTube transcripts. Resolves the transcripts dir via `pidcast info`, filters to genuine podcast/YT by front-matter `url` (skips meeting recordings, tests, prior digests, analysis side-files), fans out to parallel Haiku subagents, synthesizes a through-line, and writes an HTML editorial page + Markdown archive note into the Obsidian vault (`03 - RESOURCES/Podcasts` default, resolved via `obsidian-cli`). Windowed by recency (default 30d); never overwrites |
| `/ask-gemini` | "ask gemini", "what does gemini think", research needing current data | Delegate a question to Google Gemini (Antigravity CLI default, AI Studio API fallback) and return the answer inline |
| `/yt-transcript` | "what did X say in this video", "find the quote in this talk", "search/summarize this YouTube video" | Fetch a YouTube caption track via yt-dlp, clean/dedupe it, and search/quote/summarize spoken content that web search can't see. Bundled script |
| `/horizon` | "weekly retro", "horizon week", "how was my week" (explicit-only) | Long-horizon retrospective. v1 = weekly: Haiku per-day summaries + Sonnet synthesis (Opus with `--deep`). Includes a deterministic Timesheet section (`horizon-timesheet.py`, Step 5c) for defensible per-project billable hours; `--no-timesheet` to skip. Writes to retroscope storage repo + mirrors to vault. |
| `/harvest-memory` | explicit invocation only | Promote cross-project facts from per-project auto-memory stores into the global memory store (`~/.claude/global-memory/`, loaded everywhere via `@import`). Propose-then-confirm; writes nothing without approval. |
| `/commit` | PROACTIVE on git commits | Conventional commits with user-facing impact framing |
| `/build-partner` | explicit invocation only | Senior engineering-partner persona for building: less-but-better, boring-tech-wins, YAGNI, vertical-slice-first. Owns architecture/data-model/restraint; defers the visual layer to `frontend-design`. |

## Adding a new skill

1. Create `commands/<skill-name>/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: <skill-name>
   description: >
     When to invoke this skill. Include trigger phrases and keywords.
   ---
   ```
2. If the skill has supporting files (formats, references, templates), put them in subdirectories alongside SKILL.md
3. Use `${CLAUDE_PLUGIN_ROOT}` for any cross-references to other plugin files - never hardcoded paths
4. Add `disable-model-invocation: true` to frontmatter if the skill should only be invoked explicitly (not auto-matched)
5. Add the command to the Commands table in this file and in README.md
6. Bump MINOR version in `.claude-plugin/plugin.json`
7. Run `./scripts/sync-to-cache.sh` to update the plugin cache
8. Commit and push
9. Restart Claude Code to load the new skill

## Adding a horizon variant (month/quarter)

`/horizon` is structured for incremental horizon expansion. To add a month or
quarter mode in a future MINOR bump:

1. Add a new sub-mode to `commands/horizon/SKILL.md` (e.g. `/horizon month`).
2. Extend `horizon-collect.py`'s window logic — the per-day pipeline is reusable;
   month = 28-31 days, quarter = 12-13 weeks.
3. For monthly, recursion-of-summarization is cheaper than re-running per-day
   Haiku: aggregate the 4-5 weekly retros (already cached in storage repo) and
   pass them to synthesis. Quarter does the same with monthly summaries.
4. Update `references/output-template.md` with a month/quarter variant.
5. Use `horizon.monthly.model` / `horizon.quarterly.model` config keys.
6. Default `horizon.quarterly.model` to `opus` — pattern recognition across
   3 months earns Opus's 5× cost premium.

## Version bumps

Bump version in `.claude-plugin/plugin.json` when making changes:
- PATCH: bug fixes, doc updates, format file tweaks
- MINOR: new command, new format file, new hook
- MAJOR: breaking changes to skill interfaces

## Syncing to Claude Code

This plugin is registered as a private marketplace at `kintecus/cc-tools`. After making changes:

```bash
# Sync local changes to plugin cache (updates marketplace clone + cache + install record)
./scripts/sync-to-cache.sh

# Restart Claude Code to load the updated version
```

The plugin is enabled globally via `"tools@kintecus": true` in `~/.claude/settings.json`. No symlinks needed - the plugin system loads skills from the cache at `~/.claude/plugins/cache/kintecus/tools/<version>/`.
