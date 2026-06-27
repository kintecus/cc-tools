# Spec 1: `/memory-janitor` ("Toby") - a context-maintenance agent

## Origin
Ali K. Miller's sharpest point (TITV 2026-06-26): everyone builds *doer* agents; nobody builds the boring janitor that keeps context from drifting across the agent org. Her `Toby` "manages memory... looking across as a project manager to make it more efficient."

## The real problem it solves (for you, specifically)
You have memory in **three tiers** and they drift:
1. **Global memory store** - `~/.claude/global-memory/` (git-managed, curated, loads every session via `@import`). HARD <200-line budget on `MEMORY.md`.
2. **Per-project auto-memory** - `~/.claude/projects/<hash>/memory/MEMORY.md` + topic files, keyed by git root (capital-`C` for satori).
3. **Repo `CLAUDE.md` files** - `~/code/CLAUDE.md` and per-project ones.

Known live drift you've already flagged in your own memories:
- `~/code/CLAUDE.md` still lists **xenoss as active** (it wrapped end of March 2026).
- Repo-count claim ("78 nested repos") goes stale as repos come/go.
- Time-sensitive state ("X is active/launched/wrapped", deadlines, pilot outcomes) rots silently.

`/harvest-memory` *promotes* facts upward but does **not** audit existing facts for staleness, contradiction, or dead references. That's the gap `/memory-janitor` fills. It is the **read-and-flag** counterpart to harvest's **promote**.

## Scope (what it does)
A propose-then-confirm audit pass. **Writes nothing without approval** - same contract as `/harvest-memory`.

Checks, in order:
1. **Dead file references** - any memory whose body names a file/dir/function/flag that no longer exists (`projects/movie-grants/...`, a renamed path like `personal/open-call` -> `client/open-call`, a deleted command). Grep-verify each path-shaped token.
2. **Stale state claims** - any memory asserting active/wrapped/launched/deadline/count. Cross-check against `~/code/CLAUDE.md`, the project's own `STATUS.md` (pm-workspace), and git reality. Flag conflicts; never silently rewrite.
3. **Contradictions** - two memories (across tiers) that assert opposing facts. Surface the pair.
4. **Duplicates / near-duplicates** - same fact in global + per-project, or two per-project memories that should be merged.
5. **Budget pressure** - global `MEMORY.md` approaching the 200-line / 25 KB hard cap; propose prunes (flag, don't truncate - matches the harvester's rule).
6. **Orphaned `[[links]]`** - `[[name]]` pointers that resolve to no memory file (these are *allowed* as forward-markers per your memory rules, so report as INFO, not error).

## Out of scope
- Promotion (that's `/harvest-memory`).
- Rewriting facts unattended.
- Touching the Obsidian vault (different system).

## Flow
`discover -> read indexes -> run checks -> classify findings (ERROR / STALE / DUPE / INFO) -> show diff/report -> confirm -> apply approved edits -> sync (git commit global store with gmc)`

Reuses harvest-memory's Step 1 discovery verbatim (the capital-`C` satori gotcha, the `-maxdepth 3` rule, the "abort if empty / warn if no satori" asserts).

## Output shape
A grouped report:
```
STALE (3)
  global/... : claims xenoss active; ~/code/CLAUDE.md and project_xenoss_wrapped.md both say wrapped Mar 2026
  ...
DEAD REF (2)
  satori/... : references frontend/src/components/ColorPicker.tsx (deleted in r5 cleanup)
  ...
DUPE (1) ...
BUDGET: global MEMORY.md at 187/200 lines - 2 prune candidates below
INFO: 4 forward-[[links]] with no target yet (expected)
```
Then: "Apply these N edits? (per-finding y/n)".

## How to run it
Two delivery options (decide at build time):
- **(A) Slash command** in `~/code/cc-tools/commands/memory-janitor/SKILL.md`, `disable-model-invocation: true`, invoked manually like `/harvest-memory`. Lowest risk, on-demand.
- **(B) Weekly cron** (`CronCreate`) that runs the audit read-only and drops the *report* into the daily note or a scratch file - you then run `/memory-janitor` interactively to apply. This is the truer "Toby" (proactive watchdog) without giving it write power. **Recommended: build A first, add B once A is trusted** - mirrors Miller's own "progressive trust, no outbound power until earned."

## Why this one ranks first
The pain is real and recurring in *your* setup (you've written multiple memories about drift), it reuses existing infrastructure (`/harvest-memory` discovery + global-store rules) rather than inventing a paradigm, and it stays inside your confirm-before-write stance. It does not add agents to a scatter problem - it *reduces* entropy.

## Build estimate (rough)
Single command file modeled on harvest-memory's SKILL.md. ~S effort. The discovery + global-store rules are already documented and battle-tested; the new work is the 6 checks and the report format.
