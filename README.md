# tools@kintecus

> [!TIP]
> ✨ ***A personal productivity toolkit that lives inside Claude Code.***

Twenty-three slash commands, hooks, and a compact statusline that turn Claude Code into a daily driver: transform writing into your own voice, run an Obsidian daily-note and reflection loop, mine your sessions for weekly retros and billable hours, hold a build to a senior engineering-partner bar, and more. Built for a solo developer who works out of the terminal and an Obsidian vault, on macOS. If you live in Claude Code and want it wired into your notes, calendar, and writing, this is for you.

> [!NOTE]
> [📦 Installation](#installation) · [🔧 Setup](#setup) · [⚡ Commands](#commands) · [⚙️ Hooks](#hooks) · [📊 Statusline](#statusline) · [📋 References](#references)

## 🎬 Demo <a name="demo"></a>

<!-- PLACEHOLDER DEMO — replace with real terminal/agent output before relying on this section.
     Per the playbook, demo output must never be invented; this block is a marked stand-in. -->

> **⚠️ Placeholder — capture real output to replace this.** Run `/prose-deslop` (or any command below) in a live session and paste the actual exchange here. Do not invent the output.

## 📦 Installation <a name="installation"></a>

**Requirements:** Claude Code and `python3`. Optional, per-feature: `jq` (statusline), Obsidian v1.12+ (daily-note, reflect, obsidian-vault), a `storageDir` in `~/.claude/retroscope.json` (`/retro today|yesterday`, `/horizon`; see [/retro config](#retro-config)), network access to kroki.io or your own Kroki (Mermaid validation), `yt-dlp` (`/yt-transcript`), the `agy` Antigravity CLI and/or a `GEMINI_API_KEY` (`/ask-gemini`), `ical-buddy` plus Xcode Command Line Tools for the `swift` interpreter (`/calendar`). Each command degrades gracefully when its optional dependency is absent. macOS only for `/calendar` and `/reminders`.

On Claude Code 2.1.275 or later, install in one step:

```text
/plugin install tools --marketplace kintecus/cc-tools
```

On earlier versions, clone the marketplace:

```bash
git clone https://github.com/kintecus/cc-tools.git ~/.claude/plugins/marketplaces/kintecus
```

Then enable the plugin by adding it to `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "tools@kintecus": true
  }
}
```

Restart Claude Code to load the plugin.

## 🔧 Setup <a name="setup"></a>

Most commands work with zero configuration. One integration reads an API key from the environment:

```bash
# Add to ~/.zshenv — used by the /ask-gemini API fallback
export GEMINI_API_KEY="your-key-from-aistudio.google.com/apikey"
```

| Variable | Used by | Source |
|---|---|---|
| `GEMINI_API_KEY` | `/ask-gemini` (API fallback) | [Google AI Studio](https://aistudio.google.com/apikey) |

`/ask-gemini` prefers the `agy` Antigravity CLI (Google Search grounding) when present and only falls back to the API key, so the key is optional if you have `agy`.

## ⚡ Commands <a name="commands"></a>

- **`/prose-deslop`** - Transform AI-generated text into your natural writing voice, or polish drafts. Format-specific rules for Slack, email (personal/professional/BLUF), PRDs, and vision docs.
- **`/amazon-writing`** - Apply Amazon-style writing rigor: eliminate weasel words, replace adjectives with data, enforce narrative prose, ensure evidence-backed claims.
- **`/daily-note`** - Read and append to your Obsidian daily note. Timestamped, wikilinked activity entries across projects.
- **`/obsidian-vault`** - Read and navigate your Obsidian vault via the CLI: search, follow links, explore the knowledge graph. Read-only by default.
- **`/reflect`** - End-of-day review: compares daily-note plan vs actual git/session activity, tracks time per project with costs, appends a summary, updates auto-memory with durable insights.
- **`/pm-principles`** - Structured interview to articulate your PM operating system. Generates a living PRINCIPLES.md.
- **`/calendar`** - Read and write Apple Calendar (and synced Google/CalDAV). Reads via icalBuddy; creates/deletes one-off, recurring, and irregular multi-date events, and skips single occurrences of a recurring event, via a bundled EventKit script. Events get no alerts unless you ask for them. macOS only.
- **`/reminders`** - Read and write Apple Reminders (and synced iCloud/CalDAV). Reads via icalBuddy (fast, read-only); creates, completes, and runs a guided reconcile/cleanup pass via AppleScript. Read-safe default; writes confirmed, handling the AppleScript timeout and partial-write gotchas. macOS only.
- **`/research`** - Web research with quick-lookup and deep modes.
- **`/pr`** - Create a pull request from a structured template, with user-facing impact framing.
- **`/clippings-digest`** - Digest unreviewed Obsidian web clippings: summarize by topic, append a Markdown digest to the daily note, render a self-contained HTML editorial page into `~/clipping-summaries/`.
- **`/podcast-digest`** - Editorial digest of recent podcast/YouTube transcripts captured by `pidcast`: filter to genuine podcast/YT (skipping meeting recordings, tests, and prior digests), fan out to parallel Haiku subagents, synthesize a through-line, and write a self-contained HTML editorial page plus a Markdown archive note into your Obsidian vault. Windowed by recency (default last 30 days). Requires `pidcast`.
- **`/ask-gemini`** - Delegate a research question to Google Gemini and return the answer inline. Defaults to the `agy` Antigravity CLI (Google Search grounding); falls back to the AI Studio API. Bundled wrapper script.
- **`/yt-transcript`** - Search, quote, and summarize a YouTube video by its caption track. Pulls captions (not the video) via yt-dlp, cleans and dedupes, then greps the text - finding spoken content plain web search can't see. Prefers human captions, warns on auto-generated. Bundled script. Requires `yt-dlp`.
- **`/retro`** - Retrospective of Claude Code sessions. `/retro session` summarizes the current session (display only); `/retro today` and `/retro yesterday` aggregate the day's sessions into a report committed to your storage repo. Shorter-range sibling of `/horizon`; `/reflect` covers plan-vs-actual against the daily note. Uses the bundled `scripts/find-sessions.py`, which `/horizon` and `/reflect` also read.
- **`/mermaid-diagram-guide`** - Pick the right Mermaid diagram type (flowchart, sequence, state, class, ER, gantt) and apply the styling, title, and accessibility conventions. The SessionStart rules tell Claude to consult it before drawing a diagram.
- **`/mermaid-validate`** - Validate every Mermaid block in the project's markdown files against Kroki and report errors with file and line.
- **`/horizon`** - Long-horizon retrospective over Claude Code sessions. v1 = weekly: cheap Haiku per-day summaries fan out in parallel, then Sonnet (or Opus with `--deep`) synthesizes themes / shipped vs stalled / tangents / decisions / open loops. Includes a **Timesheet** of defensible per-project active time for hourly billing, computed deterministically by `horizon-timesheet.py` (`--no-timesheet` to skip; standalone with `--project` / `--format csv`). Explicit-only.
- **`/harvest-memory`** - Promote cross-project facts from per-project auto-memory stores into a curated global memory store (`~/.claude/global-memory/`) that loads into every session via `@import`. Discovers stores, finds facts touching 2+ projects, dedups, and proposes a diff - writes nothing without confirmation. Explicit-only.
- **`/commit`** - Git committer invoked proactively on commits. Produces conventional commits with user-facing impact framing.
- **`/statusline`** - Configure, preview, or troubleshoot the bundled single-line statusline: 5h/7d rate limits, session cost, model, effort level, context tokens with colour bands, 1M-context marker, repo, git branch, and open-PR badge. Everything comes from the payload Claude Code pipes in, so there are no network calls and no credential reads. Explicit-only.
- **`/build-partner`** - A senior engineering-partner persona for building: less-but-better, boring-tech-wins, YAGNI, vertical-slice-first. Owns architecture, the data model, code structure, and restraint; pushes back on speculative abstractions; defers the visual layer to the `frontend-design` skill when present. Explicit-only.
- **`/law-review`** - Review a diff, PR, or plan against named software laws (Gall's Law, YAGNI, second-system effect, least astonishment, Chesterton's Fence, Hyrum's Law, and more) for system-level design problems rather than style. Triages files by blast radius, asks for evidence of outcomes beyond passing tests, and ends with questions the human owner should be able to answer. Read-only, explicit-only.

## ⚙️ Hooks <a name="hooks"></a>

The plugin registers these hooks (`hooks/hooks.json`):

- **`SessionStart`** (`inject-rules.sh`) - injects static rules: an **effort-estimate rule** (every plan written in plan mode ends with a rough ~token-budget / ~cost / ~Claude-time / ~your-time block, scaled to the session model; best-effort, not gated), the Mermaid diagram conventions, and a one-line `/retro` reminder.
- **`SessionStart`** (`setup-statusline.sh`) - keeps the statusline script installed (see [Statusline](#statusline)).
- **`PostToolUse`** on `Write|Edit` (`validate-on-edit.sh`) - when the edited file is `.md`, validates each `mermaid` block. Parse errors go back to Claude as hook feedback (exit 2 with the errors on stderr) so it can fix them; the edit itself stands. Valid files, non-markdown files, and network failures produce no output.

> **Privacy note:** Mermaid validation POSTs the source of each `mermaid` block in the edited file to [kroki.io](https://kroki.io), a public service. Set `MERMAID_KROKI_URL` to a self-hosted Kroki (`docker run -d -p 8000:8000 yuzutech/kroki`, then `MERMAID_KROKI_URL=http://localhost:8000`) to keep diagrams local. No git hooks are installed and `core.hooksPath` is never touched.

> **Removed in 0.26.0:** the SessionStart injection of today's Obsidian daily note. It was non-deterministic (the note changes during the day, so it never hit the prompt prefix cache) and pulled personal context into every session whether or not the session had anything to do with it. Use `/daily-note` to read it on demand.

> **Removed in 0.25.0:** the plan-review enforcement system (`/review-plan`, the `ExitPlanMode` checkpoint hook, and the `PreToolUse` marker gate). It depended on spawning a fresh-context reviewer subagent, which stopped returning findings after an upstream change to how subagents run and report. See the [0.25.0 removal commit](https://github.com/kintecus/cc-tools/commits/main) for the full implementation if you want to revive it.

## 📊 Statusline <a name="statusline"></a>

A single-line statusline ships with the plugin:

```
5h 92% 50m !!  7d 22% ~5d  $0.42  Opus 5  xhigh  104k (10%)  1M  owner/repo  main*  #42
```

Claude Code does not let a plugin set the main statusline, so setup is one manual
step. The `SessionStart` hook keeps `~/.claude/statusline-tools.sh` up to date, and
you point `~/.claude/settings.json` at it once, either by running `/statusline` or
by hand:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-tools.sh"
  }
}
```

It needs `jq`. Every value except the git branch arrives in the JSON Claude Code
pipes to the script on stdin, so it makes no network calls and reads no credentials.
On narrow terminals segments drop in order: repo, session cost, effort.

Context is coloured by absolute tokens, because on a 1M window a percentage stays
low long after quality starts to slip:

| Tokens | Look | Meaning |
|---|---|---|
| under 70k | dim | Cold start and early work |
| 70-100k | default | Watch |
| 100-200k | bold yellow | Finish this task, then `/clear` |
| 200-300k | bold orange | `/compact` or hand off at the next safe point |
| 300k+ | bold red `!!` | Expect degradation |

Any window at 80% or more also goes red. The sources behind each band are in
[`commands/statusline/SKILL.md`](commands/statusline/SKILL.md#context-bands). They
are heuristics, not measured limits.

The installed script is overwritten on update, so make changes in
`scripts/statusline.sh`. The deliberately non-standard filename leaves
`~/.claude/statusline.sh` free, so other statusline plugins can stay installed
without two `SessionStart` hooks racing to overwrite one path.

## 🗂️ /retro config <a name="retro-config"></a>

`/retro`, `/horizon`, and `/harvest-memory` read the same config, first match wins: `.claude-plugin/retroscope.json` in the project, then `.claude/retroscope.json` in the project, then `~/.claude/retroscope.json`. There is no setup wizard; create the file by hand:

```json
{
  "storageDir": "~/code/retros",
  "timezone": "Europe/Warsaw",
  "model": "haiku",
  "scope": "all"
}
```

| Field | Default | Description |
|---|---|---|
| `storageDir` | none | Git repo where reports are saved. Required for `/retro today\|yesterday` and `/horizon` |
| `language` | `"en"` | Report language |
| `timezone` | system | IANA timezone name |
| `model` | `"haiku"` | Report model: `haiku`, `sonnet`, or `inherit` |
| `extractMode` | `true` | Pre-filter sessions to text-only (cuts tokens 80-90%) |
| `sessionSource` | `"logs"` | `/retro session` source: `logs` (full JSONL, survives `/compact`) or `context` (faster, may miss earlier turns) |
| `scope` | `"project"` | `project` (current project only) or `all` (cross-project reports) |
| `autoPush` | `false` | `git push` after each report commit |
| `horizon.*` | | `/horizon` settings; see [`commands/horizon/references/config-schema.md`](commands/horizon/references/config-schema.md) |

## 📋 References <a name="references"></a>

- [`CLAUDE.md`](CLAUDE.md) - agent-facing instructions: plugin structure, conventions, and how to add a skill.
- [`LICENSE`](LICENSE) - MIT.

## 🙏 Credits <a name="credits"></a>

Derived from plugins in [Tribe Coding claude-plugins](https://github.com/artem-from-ua/claude-plugins/tree/bcc769c14690b8d9da0230f8b3b34d551bb016e9) (snapshot `bcc769c`),
MIT License, Copyright (c) 2025 Tribe Coding:

- `scripts/statusline.sh` is derived from the [`statusline-compact`](https://github.com/artem-from-ua/claude-plugins/tree/bcc769c14690b8d9da0230f8b3b34d551bb016e9/plugins/statusline-compact) plugin.
- `scripts/find-sessions.py` and `commands/retro/` are derived from the [`retroscope`](https://github.com/artem-from-ua/claude-plugins/tree/bcc769c14690b8d9da0230f8b3b34d551bb016e9/plugins/retroscope) plugin (0.3.1), with local changes: `--projects-dir` and skipping sessions where Claude never replied.

The Mermaid commands, rules, and validator were written by the cc-tools author and originally published in the same repository.
