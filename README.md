# tools@kintecus

> [!TIP]
> ✨ ***A personal productivity toolkit that lives inside Claude Code.***

Eighteen slash commands, hooks, and an image MCP server that turn Claude Code into a daily driver: transform writing into your own voice, run an Obsidian daily-note and reflection loop, enforce fresh-context plan review, mine your sessions for weekly retros and billable hours, hold a build to a senior engineering-partner bar, and more. Built for a solo developer who works out of the terminal and an Obsidian vault, on macOS. If you live in Claude Code and want it wired into your notes, calendar, and writing, this is for you.

> [!NOTE]
> [📦 Installation](#installation) · [🔧 Setup](#setup) · [⚡ Commands](#commands) · [🖼️ Image MCP](#image-mcp) · [⚙️ Plan-review hooks](#hooks) · [📋 References](#references)

## 🎬 Demo <a name="demo"></a>

<!-- PLACEHOLDER DEMO — replace with real terminal/agent output before relying on this section.
     Per the playbook, demo output must never be invented; this block is a marked stand-in. -->

> **⚠️ Placeholder — capture real output to replace this.** Run `/review-plan` (or `/prose-deslop`) in a live session and paste the actual exchange here.

```text
> /review-plan

Reading the plan… spawning a fresh-context reviewer (it sees only the plan text).

  CRITICAL  Branch deletion targets the wrong branch — the named branch is the
            cleanup, not the leak.   → delete the other branch instead.
  HIGH      Verification grep uses `rg -nE`; ripgrep has no -E flag, so the
            check silently passes.   → use `-e` per pattern.

Verdict: REVISE (major) — applying CRITICAL + HIGH, then re-presenting the plan.
```

## 📦 Installation <a name="installation"></a>

**Requirements:** Claude Code. Optional, per-feature: Obsidian v1.12+ (daily-note, reflect, obsidian-vault), the [retroscope](https://github.com/kintecus/retroscope) plugin (required for `/horizon`, optional for `/reflect`), `uv` (image MCP), `yt-dlp` (`/yt-transcript`), the `agy` Antigravity CLI and/or a `GEMINI_API_KEY` (`/ask-gemini`, image MCP). Each command degrades gracefully when its optional dependency is absent. macOS only for `/calendar` and `/reminders`.

```bash
# Clone the marketplace
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

Most commands work with zero configuration. Two integrations read an API key from the environment:

```bash
# Add to ~/.zshenv — used by the image MCP server and the /ask-gemini API fallback
export GEMINI_API_KEY="your-key-from-aistudio.google.com/apikey"
```

| Variable | Used by | Source |
|---|---|---|
| `GEMINI_API_KEY` | `gemini-image` MCP server; `/ask-gemini` (API fallback) | [Google AI Studio](https://aistudio.google.com/apikey) |

`/ask-gemini` prefers the `agy` Antigravity CLI (Google Search grounding) when present and only falls back to the API key, so the key is optional if you have `agy`.

## ⚡ Commands <a name="commands"></a>

- **`/prose-deslop`** - Transform AI-generated text into your natural writing voice, or polish drafts. Format-specific rules for Slack, email (personal/professional/BLUF), PRDs, and vision docs.
- **`/amazon-writing`** - Apply Amazon-style writing rigor: eliminate weasel words, replace adjectives with data, enforce narrative prose, ensure evidence-backed claims.
- **`/daily-note`** - Read and append to your Obsidian daily note. Timestamped, wikilinked activity entries across projects.
- **`/obsidian-vault`** - Read and navigate your Obsidian vault via the CLI: search, follow links, explore the knowledge graph. Read-only by default.
- **`/reflect`** - End-of-day review: compares daily-note plan vs actual git/session activity, tracks time per project with costs, appends a summary, updates auto-memory with durable insights.
- **`/pm-principles`** - Structured interview to articulate your PM operating system. Generates a living PRINCIPLES.md.
- **`/calendar`** - Read and write Apple Calendar (and synced Google/CalDAV). Reads via icalBuddy; creates/deletes one-off and recurring events via AppleScript. macOS only.
- **`/reminders`** - Read and write Apple Reminders (and synced iCloud/CalDAV). Reads via icalBuddy (fast, read-only); creates, completes, and runs a guided reconcile/cleanup pass via AppleScript. Read-safe default; writes confirmed, handling the AppleScript timeout and partial-write gotchas. macOS only.
- **`/research`** - Web research with quick-lookup and deep modes.
- **`/pr`** - Create a pull request from a structured template, with user-facing impact framing.
- **`/review-plan`** - Spawn a fresh-context subagent to critique an implementation plan for gaps, blind spots, and ordering issues before any code. Also runs proactively after plan mode (see [hooks](#hooks)).
- **`/clippings-digest`** - Digest unreviewed Obsidian web clippings: summarize by topic, append a Markdown digest to the daily note, render a self-contained HTML editorial page into `~/clipping-summaries/`.
- **`/ask-gemini`** - Delegate a research question to Google Gemini and return the answer inline. Defaults to the `agy` Antigravity CLI (Google Search grounding); falls back to the AI Studio API. Bundled wrapper script.
- **`/yt-transcript`** - Search, quote, and summarize a YouTube video by its caption track. Pulls captions (not the video) via yt-dlp, cleans and dedupes, then greps the text - finding spoken content plain web search can't see. Prefers human captions, warns on auto-generated. Bundled script. Requires `yt-dlp`.
- **`/horizon`** - Long-horizon retrospective over Claude Code sessions. v1 = weekly: cheap Haiku per-day summaries fan out in parallel, then Sonnet (or Opus with `--deep`) synthesizes themes / shipped vs stalled / tangents / decisions / open loops. Includes a **Timesheet** of defensible per-project active time for hourly billing, computed deterministically by `horizon-timesheet.py` (`--no-timesheet` to skip; standalone with `--project` / `--format csv`). Explicit-only.
- **`/harvest-memory`** - Promote cross-project facts from per-project auto-memory stores into a curated global memory store (`~/.claude/global-memory/`) that loads into every session via `@import`. Discovers stores, finds facts touching 2+ projects, dedups, and proposes a diff - writes nothing without confirmation. Explicit-only.
- **`/commit`** - Git committer invoked proactively on commits. Produces conventional commits with user-facing impact framing.
- **`/build-partner`** - A senior engineering-partner persona for building: less-but-better, boring-tech-wins, YAGNI, vertical-slice-first. Owns architecture, the data model, code structure, and restraint; pushes back on speculative abstractions; defers the visual layer to the `frontend-design` skill when present. Explicit-only.

## 🖼️ Image MCP <a name="image-mcp"></a>

`gemini-image` generates and edits images using Google's Gemini API (nanobanana). Requires `GEMINI_API_KEY` (see [Setup](#setup)) and `uv`.

- **`generate_image`** - text-to-image. Params: `prompt`, optional `output_path`, optional `aspect_ratio`.
- **`edit_image`** - modify an existing image with a text prompt. Params: `prompt`, `source_image_path`, optional `output_path`.

Images save to `~/Downloads/gemini_{timestamp}.png` by default.

## ⚙️ Plan-review hooks <a name="hooks"></a>

The plugin registers a layered plan-review enforcement system plus daily-note injection (`hooks/hooks.json`). The goal: make the fresh-context plan-review offer survive context loss and auto-accept-edits modes, deterministically rather than relying on the model to remember.

- **`SessionStart`** - injects a **plan-review rule** (Claude proactively offers a fresh-context review after plan mode) and **today's Obsidian daily note** for situational awareness. The daily-note part needs the Obsidian desktop app (v1.12+) running with CLI enabled; the rule is always injected.
- **`PostToolUse` / `ExitPlanMode`** - on **every** acceptance mode (including "auto-accept edits"), injects a fresh **plan-review checkpoint** reminder and **sets a session-keyed pending-review marker** that arms the gate below. The reminder decouples the edit-approval mode from the review decision, so "auto-accept edits" is no longer misread as declining the review.
- **`PreToolUse` / `Edit|Write|MultiEdit|NotebookEdit`** (the **deterministic gate**) - while the marker exists, the first code edit is **hard-blocked via exit code 2**. Exit 2 blocks *before* permission rules are evaluated, so it overrides `permissions.allow` rules and every non-prompting mode - the one mechanism that reliably stops the edit. (An earlier `permissionDecision: "ask"` was overridden by allow-rules and unreliably honored on Claude Code 2.1.x - see issues #52822/#13339/#39344.) Fails open: any error or missing marker exits 0 and never blocks.
- **`PostToolUse` / `Edit|Write|MultiEdit|NotebookEdit`** - clears the marker after a successful edit (backstop for the decline-path retry). Also cleared by `/review-plan` (Step 0) and re-armed when a new plan is accepted. Markers are session-keyed under `$TMPDIR`, so concurrent sessions never cross-block and staleness clears on reboot.

**Resolving the block:** because exit 2 blocks the edit, the marker can't auto-clear, so the gate's stderr tells Claude to clear it explicitly - `/review-plan` on the review path, or `rm` the marker and retry on the decline path. This keeps the offer deterministic without an infinite block loop.

## 📋 References <a name="references"></a>

- [`CLAUDE.md`](CLAUDE.md) - agent-facing instructions: plugin structure, conventions, and how to add a skill.
- [`LICENSE`](LICENSE) - MIT.
