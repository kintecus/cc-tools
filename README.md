# tools@kintecus

Personal productivity plugin for Claude Code. Writing voice, daily notes, PM principles.

## Commands

- **`/prose-deslop`** - Transform AI-generated text into your natural writing voice, or polish drafts. Supports format-specific rules for Slack, email (personal/professional/BLUF), PRDs, and vision docs.
- **`/amazon-writing`** - Apply Amazon-style writing rigor: eliminate weasel words, replace adjectives with data, enforce narrative prose, ensure evidence-backed claims.
- **`/daily-note`** - Read and append to your Obsidian daily note. Tracks activities across projects with timestamped, wikilinked entries.
- **`/reflect`** - End-of-day review: compares daily note plan vs actual git/session activity, tracks time per project with costs, appends summary to daily note, updates auto-memory with durable insights.
- **`/pm-principles`** - Structured interview to articulate your PM operating system. Generates a living PRINCIPLES.md document.
- **`/calendar`** - Read and write Apple Calendar (and synced Google/CalDAV calendars). Reads via icalBuddy; creates/deletes events (one-off and recurring) via AppleScript. macOS only.
- **`/reminders`** - Read and write Apple Reminders (and synced iCloud/CalDAV lists). Reads via icalBuddy (fast, read-only); creates reminders, marks them complete, and runs a guided reconcile/cleanup pass via AppleScript. Read is the confirmed-safe default; writes are confirmed and handle the Reminders AppleScript timeout and partial-write gotchas. macOS only.
- **`/research`** - Web research with quick lookup and deep modes.
- **`/pr`** - Create a pull request from a structured template, with user-facing impact framing.
- **`/review-plan`** - Spawn a fresh-context subagent to critique an implementation plan for gaps, blind spots, and ordering issues before any code is written. Also runs proactively after plan mode (see Hooks below).
- **`/clippings-digest`** - Digest unreviewed Obsidian web clippings: summarize by topic, append a Markdown digest to the daily note, and render a self-contained HTML editorial page into `~/clipping-summaries/`.
- **`/ask-gemini`** - Delegate a research question to Google Gemini and return the answer inline. Defaults to the Antigravity CLI (`agy`) backend with Google Search grounding; falls back to the AI Studio API. Bundled wrapper script.
- **`/yt-transcript`** - Search, quote, and summarize a YouTube video by its caption track. Pulls captions (not the video) via yt-dlp, cleans and dedupes them, then greps the text - finding spoken content that plain web search can't see. Prefers human captions, falls back to auto-generated with a quote-accuracy warning. Bundled script. Requires `yt-dlp`.
- **`/horizon`** - Long-horizon retrospective over Claude Code sessions. v1 = weekly: cheap Haiku per-day summaries fan out in parallel, then Sonnet (or Opus with `--deep`) synthesizes themes / shipped vs stalled / tangents / decisions / open loops. Includes a **Timesheet** section: defensible per-project active engaged time (inter-message gaps with idle capped) for hourly billing, computed deterministically by `horizon-timesheet.py` (skip with `--no-timesheet`; also invocable standalone with `--project` / `--format csv`). Writes to the retroscope storage repo and mirrors a proxy note into the Obsidian vault for clickable wikilinks. Explicit-only.
- **`/harvest-memory`** - Promote cross-project facts from the per-project auto-memory stores into a curated global memory store (`~/.claude/global-memory/`) that loads into every session via an `@import`. Discovers stores, identifies facts touching 2+ projects, dedups against what's already promoted, and proposes a diff - writes nothing without confirmation. Local git only. Explicit-only.

## Agents

- **`commit`** - Git committer invoked proactively on commits. Produces conventional commits with user-facing impact framing.

## MCP server: gemini-image

Generate and edit images using Google's Gemini API (nanobanana). Provides two tools:

- **`generate_image`** - text-to-image generation. Params: `prompt`, optional `output_path`, optional `aspect_ratio`.
- **`edit_image`** - modify an existing image with a text prompt. Params: `prompt`, `source_image_path`, optional `output_path`.

Images are saved to `~/Downloads/gemini_{timestamp}.png` by default.

**Setup**: export your Google AI Studio API key:

```bash
# Add to ~/.zshenv
export GEMINI_API_KEY="your-key-from-aistudio.google.com/apikey"
```

## Hooks

The plugin registers a layered plan-review enforcement system plus daily-note injection (`hooks/hooks.json`):

- **`SessionStart`** - injects two things into every session: a **plan review rule** (makes Claude proactively offer a fresh-context plan review after plan mode) and **today's Obsidian daily note** for situational awareness. The daily note part requires the Obsidian desktop app (v1.12+) running with CLI enabled; the plan review rule is always injected.
- **`PostToolUse` / `ExitPlanMode`** - fires the moment a plan is accepted - on **every** acceptance mode, including "auto-accept edits" - and does two things: injects a fresh **plan-review checkpoint** reminder (so the `/review-plan` offer is reliable even when the SessionStart rule has scrolled out of context), and **sets a session-keyed pending-review marker** that arms the gate below. The reminder explicitly decouples the edit-approval mode from the review decision, so picking "auto-accept edits" no longer gets misread as declining the review.
- **`PreToolUse` / `Edit|Write|MultiEdit|NotebookEdit`** (the **deterministic gate**) - while the pending-review marker exists, the first code edit is **hard-blocked via exit code 2**. Exit 2 blocks the tool *before* permission rules are evaluated, so it **overrides `permissions.allow` rules** (every plan edits allow-listed paths) and every non-prompting mode - the one mechanism that reliably stops the edit. The block's stderr instructs Claude to offer the review, then clear the gate. (An earlier version returned `permissionDecision: "ask"`; on Claude Code 2.1.x that is overridden by allow-rules and unreliably honored, so it does not work - see issues #52822/#13339/#39344.) Fails open: any error or missing marker exits 0 and never blocks an edit.
- **`PostToolUse` / `Edit|Write|MultiEdit|NotebookEdit`** - clears the marker after an edit succeeds (a backstop for the decline path's retry). The marker is also cleared by `/review-plan` (Step 0) and re-armed when a new plan is accepted. Markers are session-keyed under `$TMPDIR`, so concurrent sessions never cross-block and staleness clears on reboot.

**Resolving the block:** because exit 2 blocks the edit, the marker cannot auto-clear, so the stderr tells Claude to clear it explicitly - `/review-plan` clears it on the review path, or Claude `rm`s the marker and retries on the decline path. This avoids an infinite block loop while keeping the offer deterministic rather than dependent on Claude's judgment. See `/review-plan` for the manual entry point.

## Install

```bash
# Clone
git clone https://github.com/kintecus/cc-tools.git ~/.claude/plugins/marketplaces/kintecus

# Enable
# Add "tools@kintecus": true to ~/.claude/settings.json under enabledPlugins
```

## Requirements

- Claude Code
- Obsidian v1.12+ (for daily-note and reflect features, optional for other commands)
- retroscope plugin (for /reflect time tracking, optional - works without it; **required for /horizon**)
- `GEMINI_API_KEY` env var (for image generation; also the `/ask-gemini` API fallback — optional for other commands)
- `agy` Antigravity CLI (for `/ask-gemini`'s default backend — optional; the skill falls back to the API if absent)
- `yt-dlp` (for `/yt-transcript` — `brew install yt-dlp`; optional for other commands)
- `uv` (for running the MCP server)

## License

MIT
