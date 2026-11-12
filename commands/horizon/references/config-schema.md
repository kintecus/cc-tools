# Config schema

`/horizon` reuses retroscope's config cascade. No standalone `horizon.json`.

## Cascade (first match per key wins)

1. `$CLAUDE_PROJECT_DIR/.claude-plugin/retroscope.json` (project, checked in)
2. `$CLAUDE_PROJECT_DIR/.claude/retroscope.json` (project, gitignored)
3. `~/.claude/retroscope.json` (user global)

`$CLAUDE_PROJECT_DIR` falls back to `cwd` if unset.

## Required keys

| Key | Source | Notes |
| --- | --- | --- |
| `storageDir` | retroscope | Absolute path; must be a git repo. Hard error if missing. |
| `timezone` | retroscope | IANA tz, e.g. `Europe/Warsaw`. |

## Optional keys

| Key | Default | Notes |
| --- | --- | --- |
| `scope` | `project` | `project` writes to `reports/{project}/weekly/...`; `all` writes to `reports/_cross-project/weekly/...` and walks all session projects. |
| `autoPush` | `false` | Push to remote after commit. |
| `horizon.weekly.model` | `sonnet` | Synthesis model alias. |
| `horizon.weekly.deepModel` | `opus` | Synthesis model when `--deep`. |
| `horizon.bulkModel` | `haiku` | Per-day summarization model. |

## CLI flags (override config)

| Flag | Effect |
| --- | --- |
| `--week YYYY-Www` | Pick a specific ISO week (default: current in `--tz`). |
| `--from / --to` | Alternative date window (inclusive). |
| `--deep` | Swap synthesis to `horizon.weekly.deepModel`. |
| `--force` | Skip cache check. |
| `--dry-run` | Compute + print, no commit, no vault write. |
| `--debug` | Log resolved paths, byte ratios, dropped block-type counts. |

## Private project labels (timesheet)

`horizon-timesheet.py` ships only generic project labels. Client and side-project
names belong in your private config, never in this repo, which is public. Add them
under `horizon.projectLabels` in `~/.claude/retroscope.json`:

```json
{ "horizon": { "projectLabels": {
    "pmWorkspaceFold": { "client-x-strategy": "client-x" },
    "markers": [ ["/client/client-x", "client-x"] ]
} } }
```

- `pmWorkspaceFold` maps a `pm-workspace/projects/<name>` sub-project to the
  bucket of its build repo. Unmapped sub-projects become `pm/<name>`.
- `markers` are `[cwd-substring, label]` pairs checked before the built-in
  markers, so a more specific private marker wins.
- Override the file with `--labels-config PATH`. A missing file means no
  overrides.

## ISO week semantics

- Week format: `YYYY-Www` (zero-padded, e.g. `2026-W21`).
- Week boundaries: Monday 00:00 → Sunday 23:59:59 in `--tz`.
- Sunday is the canonical anchor for daily-note linkage.
- W01 lookback for "prior week": W52 or W53 of previous year via
  `datetime.date.isocalendar()` — the standard library handles the edge.
- Future weeks are rejected (exit 3). "Future" = the Monday of the week is
  strictly after today in `--tz`.
- Empty weeks (no sessions in any project for the whole window) are allowed;
  produce a minimal "no activity" report.

## Worked example

User has `~/.claude/retroscope.json`:

```json
{
  "storageDir": "~/code/retroscope",
  "timezone": "Europe/Warsaw",
  "scope": "all",
  "autoPush": false
}
```

Running `/horizon week` on Monday 2026-05-25 with no flags:

- Resolves week = `2026-W21` (Mon 2026-05-18 – Sun 2026-05-24).
- Scope = `all` → output at
  `~/code/retroscope/reports/_cross-project/weekly/2026-W21/summary.md`.
- Sunday anchor = `2026-05-24`; daily-note path =
  `…/Vault/Journal/Daily/2026-05-24.md`.
- Vault proxy =
  `…/Vault/02 - AREAS/Retros/weekly/2026-W21.md`.
- Models: bulk = `haiku`, synthesis = `sonnet` (no `--deep`).
