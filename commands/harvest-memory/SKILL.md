---
name: harvest-memory
description: >
  Promote cross-project facts from per-project auto-memory stores into the
  global memory index (~/.claude/global-memory/). Shows a diff; writes nothing
  without confirmation. Invoke explicitly with /harvest-memory.
disable-model-invocation: true
---

# Harvest cross-project memory

Promote facts that hold across the whole `~/code` workspace from the per-project
auto-memory stores into the **global memory store** (`~/.claude/global-memory/`),
which loads into every session via an `@import` in `~/.claude/CLAUDE.md`.

This is **propose-then-confirm**: gather candidates, show a diff, write nothing until
the user approves. It mutates a curated, version-controlled store — never write silently.

The flow is: **discover → read → identify → corroborate → dedup → propose → confirm → write → sync.**

**See also:** `/horizon` (weekly retro) is the upstream signal source — its weekly summaries
corroborate which facts are durable enough to promote (Step 3b), and it nudges toward
`/harvest-memory` when a retro surfaces cross-project signals. Run `/horizon` first for the
richest candidates.

## Step 1: Discover the per-project stores (case-insensitively, fail loudly)

Auto-memory is keyed by git root, so each project has its own store at
`~/.claude/projects/<hash>/memory/MEMORY.md`. List them and keep the `~/code` workspace
stores. The hash uses the project path with separators replaced by `-`, and **the path
casing is preserved** — satori's repos live at `~/code/satori/...` but their store hashes
are `-Users-ostaps-Code-satori-walletsvc` and `-Users-ostaps-Code-satori-walletsvc-frontend`
(capital `C`). A lowercase-only match silently drops the highest-stakes project.

```bash
# Match BOTH cases of "code"; derive the active set from what actually exists on disk.
# NOTE: the stores sit at projects/<hash>/memory/MEMORY.md — that is depth 3 under
# `projects`, so -maxdepth must be >= 3 (a tighter cap silently finds nothing).
find ~/.claude/projects -maxdepth 3 -name MEMORY.md -path '*-Users-ostaps-[Cc]ode*/memory/MEMORY.md' 2>/dev/null | sort
```

Rules for this step:

- **Derive the active set dynamically** from the files that exist. Do NOT hardcode a
  project-name list — some named projects (e.g. family-os, music-agent) have no store on
  disk, and a hardcoded list would iterate dead paths.
- **The root workspace store** (`-Users-ostaps-code/memory/MEMORY.md`, lowercase `code`) is
  itself one of the sources — it already holds many cross-project facts curated by hand.
- **Assert satori is present.** If the discovered set contains no satori store, surface a
  warning (satori is the highest-stakes project and its capital-`C` path is the exact thing
  a casing bug drops). If the discovered set is **empty**, abort with an error — do not
  silently proceed as if there were nothing to harvest.
- Accept an optional argument to scope to specific projects (match against the discovered
  paths) or `all` (default).

## Step 2: Read the indexes and the existing global state (cold-start safe)

- Read each discovered project `MEMORY.md` — the **index only** (cheap). The index lines
  are enough to spot candidates; only read a topic file when Step 3 requires it.
- Read `~/.claude/global-memory/MEMORY.md` to know what is already promoted.
  **If it does not exist (first run), treat the promoted set as empty.** Do NOT error on a
  missing global index — it gets created during the first write in Step 7.

## Step 3: Identify cross-project candidates

A fact qualifies for promotion ONLY if:

- (a) it **references or affects 2+ projects**, OR
- (b) it is a **workspace-level** decision, preference, or reference useful everywhere
  (e.g. a git-workflow split, a tool preference, an environment quirk).

**EXCLUDE** single-project-internal facts: build commands, project-local gotchas, per-repo
state, anything that only makes sense inside one project. Those stay in their own store.

**For any candidate that asserts cross-project STATE** — deadlines, counts, "X is
active/wrapped/launched", anything time-sensitive — **read the full topic file** (not just
the index hook) before promoting, and **cross-check `~/code/CLAUDE.md` for staleness**. The
root store itself flags drift (e.g. a client project listed as active when it wrapped; the repo-count
number). Do not promote a stale claim; flag the conflict in Step 5 instead.

## Step 3b: Corroborate candidates against weekly retros (`/horizon` evidence)

The weekly retros that `/horizon` writes are a strong, time-stamped corroboration source:
a decision or pattern that recurs **across multiple weeks** is durable by definition — exactly
what belongs in the global store. Use them to *raise confidence* and *catch staleness*, never
as the sole basis for a promotion (the per-project stores remain the source of truth).

Resolve the retro directory from the retroscope config cascade (same order retroscope and
horizon use — first match wins per key): `$CLAUDE_PROJECT_DIR/.claude-plugin/retroscope.json`,
`$CLAUDE_PROJECT_DIR/.claude/retroscope.json`, `~/.claude/retroscope.json`. Read `storageDir`
and `scope`. Retros live at:

```bash
# scope=all (cross-project): reports/_cross-project/weekly/<YYYY-Www>/summary.md
# scope=project:             reports/<project>/weekly/<YYYY-Www>/summary.md
RETRO_GLOB="$STORAGE_DIR/reports/_cross-project/weekly/*/summary.md"   # adjust for scope
ls -1 $RETRO_GLOB 2>/dev/null | sort | tail -6   # the most recent ~6 weeks is plenty
```

Read the **most recent ~4-6 weekly summaries** (cheap — they are short). For each candidate
from Step 3, check the retros' `## Decisions`, `## Themes`, and `## Open loops` sections:

- **Recurs across 2+ weeks** → strong promote signal. Note it in the Step 5 proposal
  ("seen in W21, W22, W23") so the user sees *why* it's durable.
- **Appears once, recently** → neutral. Keep relying on the per-project store's own signal.
- **A retro contradicts the candidate** (e.g. retro says a project wrapped, candidate calls
  it active) → treat as a staleness flag, same as the `~/code/CLAUDE.md` cross-check above:
  do not promote; FLAG it in Step 5.

If **no recent retros exist on disk** (the directory is empty or the last summary is several
weeks old), surface a one-line nudge before proposing:

> No recent weekly retros found. Running `/horizon` first would surface richer, time-stamped
> candidates (recurring decisions, patterns) — want to do that before harvesting?

This is a suggestion, not a gate — proceed with the per-project stores if the user declines.
Retros are corroboration, not a prerequisite.

## Step 4: Dedup against the global store

Compare each candidate against the global index from Step 2. Classify:

- **NEW** — not in the global store. Propose as an ADD.
- **UPDATE** — a global entry exists, but a source store has newer or conflicting detail.
- **STALE** — a global entry whose underlying source facts no longer exist or have changed.

Skip facts already promoted with no change.

## Step 5: Propose as a diff (write nothing yet)

Present a table the user can scan:

| Action | Title | Sources | Summary |
|--------|-------|---------|---------|
| ADD    | ...   | satori, puch | new topic file + index line |
| UPDATE | ...   | homelab | global file change |
| FLAG   | ...   | —       | conflict / stale — needs a human call |

For each ADD/UPDATE, show the **proposed frontmatter + body + index line** so the user sees
exactly what would be written. For each FLAG, state the conflict and the options. **Write
nothing in this step.**

## Step 6: Confirm

Use `AskUserQuestion` to confirm the ADD/UPDATE set, and ask per-item for any FLAGGED
conflict (which version wins, or skip). **Honor partial approval** — write only what was
approved.

## Step 7: Write the approved changes

- Create or update each approved topic file at `~/.claude/global-memory/<slug>.md` using the
  format in the Rules section below.
- Create or update `~/.claude/global-memory/MEMORY.md` — on a cold start, create it here with
  the header (see the existing committed `MEMORY.md` for the template) plus the new index
  lines.
- **Enforce the <200-line budget by flag-don't-truncate.** If adding the approved entries
  would push `MEMORY.md` past 200 lines, STOP and ask the user to prune or split first.
  Never silently drop entries — `@import`ed files are loaded in full with **no
  auto-truncation safety net**, so an over-budget index inflates every session's context.

## Step 8: Sync

- Show `git -C ~/.claude/global-memory status --short`.
- Offer to commit (`gmc` alias, or `git -C ~/.claude/global-memory add -A && commit`).
- The store is **local git only** (no remote yet) — do NOT push. If a remote is later added,
  still never push without explicit confirmation.
- Report what was written: counts of ADD/UPDATE/FLAG and the final index line count.

## Rules

- **Never write without confirmation.** Steps 1–5 are read-only + propose; writing happens
  only after Step 6 approval.
- **Cross-project only.** Promote a fact only if it touches 2+ projects or is workspace-level.
  Exclude build commands, project-local gotchas, and per-repo state.
- **File format** — one fact per file, frontmatter is a deliberate superset of the
  per-project (puch-style) nested `metadata:` convention:

  ```markdown
  ---
  name: <kebab-slug>
  description: <one-line summary — used for recall relevance>
  metadata:
    type: user | feedback | project | reference
    sources: [satori, puch]        # which project store(s) this was promoted from
    promoted: 2026-06-04           # ISO date — stamp from the session date in context
  ---

  <the fact; link related facts with [[other-name]]>
  ```

- **Index style** — `- [Title](file.md) - one-line hook`: **regular dash separator**,
  sentence-case title. Per Ostap's CLAUDE.md, regular dashes (-), never emdashes (—).
  **Normalize emdash separators to regular dashes** when promoting from stores that use them
  (notably puch's index lines use `—`).
- **Hard <200-line budget** on `MEMORY.md` — flag, don't truncate.
- **Stamp `promoted:`** with the session date from context (there are no helper scripts, so
  read the date from the session, not a shell call).
- **Never bulk-copy a whole store.** Promote individual qualifying facts, not everything.
- **Back-reference sources** in `metadata.sources` so provenance is auditable.
- This skill is a single self-contained `SKILL.md` — no helper scripts (mirrors `reflect`'s
  inline Read/Write/Edit/Glob pattern).
