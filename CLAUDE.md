# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Claude Code plugin (`tools@kintecus`) packaging personal productivity skills: writing voice transformation, Amazon-style document rigor, Obsidian daily note integration, and PM principles generation.

## Plugin structure

Follows the [tribe-coding plugin conventions](https://github.com/tribe-coding/claude-plugins):

```
.claude-plugin/
  plugin.json           # manifest (name, version, commands, skills)
  marketplace.json      # marketplace registration
hooks/
  hooks.json            # SessionStart hook definition
scripts/
  inject-rules.sh       # reads today's Obsidian daily note into session context
mcp/
  gemini_image.py       # Gemini image generation MCP server
.mcp.json               # MCP server registration
commands/
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
```

## Key conventions

- **SKILL.md frontmatter**: every skill needs `name` and `description` in YAML frontmatter per [agentskills.io spec](https://agentskills.io/specification)
- **Path references**: use `${CLAUDE_PLUGIN_ROOT}` for cross-skill references, never hardcoded paths
- **Hook scripts**: use `${CLAUDE_PLUGIN_ROOT}` in hooks.json, with `PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"` fallback in scripts
- **SessionStart output**: keep under 300 tokens. The daily note injection is non-deterministic (content changes during day) so it won't benefit from API prefix caching
- **No `skills/` directory**: all skills are user-invoked commands, so `plugin.json` points both `commands` and `skills` at `./commands/`

## MCP server: gemini-image

The plugin includes an MCP server for Gemini (nanobanana) image generation. Registered via `.mcp.json`, started automatically when the plugin is enabled.

- **Tools**: `generate_image` (text-to-image), `edit_image` (image+text-to-image)
- **Env var**: `GEMINI_API_KEY` (from Google AI Studio)
- **Output**: saves PNG to `~/Downloads/gemini_{timestamp}.png` by default
- **Runtime**: `uv run` with inline PEP 723 deps (mcp, httpx) - no install step

## Obsidian CLI dependency

The daily-note skill and SessionStart hook require the Obsidian CLI (`/Applications/Obsidian.app/Contents/MacOS/obsidian`, v1.12+). Obsidian must be running. The hook fails silently if Obsidian is closed.

## Commands

| Command | Trigger | Description |
|---------|---------|-------------|
| `/prose-deslop` | "de-slop", "humanize", "make it sound like me" | Voice transformation with format-specific rules |
| `/amazon-writing` | "finalize", "make it crisp", "no fluff" | Data-driven writing rigor |
| `/daily-note` | "log this", "update daily note", "note that down" | Obsidian daily note read/append |
| `/reflect` | "end of day", "wrap up day", "what did I do today" | Plan vs actual review, time tracking, memory updates |
| `/pm-principles` | explicit invocation only | PM principles interview generator |

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
5. Add a symlink from `~/.claude/skills/<skill-name>` to `commands/<skill-name>/` so it works before marketplace install
6. Add the command to the Commands table in this file and in README.md
7. Bump MINOR version in `.claude-plugin/plugin.json`
8. Commit and push

## Version bumps

Bump version in `.claude-plugin/plugin.json` when making changes:
- PATCH: bug fixes, doc updates, format file tweaks
- MINOR: new command, new format file, new hook
- MAJOR: breaking changes to skill interfaces

## Testing locally

```bash
# Copy to marketplace cache
cp -r . ~/.claude/plugins/marketplaces/kintecus/

# Enable in settings.json
# "tools@kintecus": true

# Restart Claude Code
```
