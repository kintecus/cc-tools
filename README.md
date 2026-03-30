# tools@kintecus

Personal productivity plugin for Claude Code. Writing voice, daily notes, PM principles.

## Commands

- **`/prose-deslop`** - Transform AI-generated text into your natural writing voice, or polish drafts. Supports format-specific rules for Slack, email (personal/professional/BLUF), PRDs, and vision docs.
- **`/amazon-writing`** - Apply Amazon-style writing rigor: eliminate weasel words, replace adjectives with data, enforce narrative prose, ensure evidence-backed claims.
- **`/daily-note`** - Read and append to your Obsidian daily note. Tracks activities across projects with timestamped, wikilinked entries.
- **`/reflect`** - End-of-day review: compares daily note plan vs actual git/session activity, tracks time per project with costs, appends summary to daily note, updates auto-memory with durable insights.
- **`/pm-principles`** - Structured interview to articulate your PM operating system. Generates a living PRINCIPLES.md document.

## SessionStart hook

Injects today's Obsidian daily note into every session for situational awareness. Requires Obsidian desktop app (v1.12+) running with CLI enabled.

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
- retroscope plugin (for /reflect time tracking, optional - works without it)

## License

MIT
