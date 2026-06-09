---
name: obsidian-vault
description: >
  Read and navigate Ostap's Obsidian vault via the CLI. Triggers: "obsidian",
  "vault", "search vault", "find in obsidian", "read note", "obsidian note",
  "check my notes", "look up in vault", "search my notes", "vault search".
  Use for pulling context from vault notes, searching, following links,
  and exploring the knowledge graph. Read-only by default.
---

# Obsidian vault reader

Read and navigate notes in Ostap's Obsidian vault using the `obsidian-cli` wrapper.

## Scope restrictions

**IMPORTANT: Privacy boundary.** This is Ostap's main personal vault. Do not browse freely.

- When no path is specified, ask which folder to scope to
- Follow links across folders only when explicitly referenced
- Default to read-only - no writes unless explicitly requested (iCloud sync risk)

If a project-level CLAUDE.md or skill specifies a default folder (e.g., job hunt), scope to that folder.

## CLI conventions

All commands use `obsidian-cli`, which auto-pins to "Obsidian Vault" and filters stderr noise.

- `file=` resolves by name (like wikilinks); `path=` is exact (folder/note.md)
- Most commands default to the active file when file/path is omitted
- Quote values with spaces: `name="My Note"`
- Use `\n` for newline, `\t` for tab in content values

## Read commands

```bash
# Read a note by exact path
obsidian-cli read path="01 - PROJECTS/some-note.md"

# Read a note by name (wikilink resolution)
obsidian-cli read file="Some Note Name"

# Read a random note (optionally scoped to folder)
obsidian-cli random:read folder="01 - PROJECTS"

# Show file info (size, dates, etc.)
obsidian-cli file path="some-note.md"

# Word count
obsidian-cli wordcount path="some-note.md"
```

## List and browse commands

```bash
# List files (optionally filter by folder and extension)
obsidian-cli files folder="01 - PROJECTS" ext=md
obsidian-cli files total                        # just the count

# List folders
obsidian-cli folders folder="01 - PROJECTS"

# Folder info
obsidian-cli folder path="01 - PROJECTS" info=files

# Recently opened files
obsidian-cli recents

# Bookmarks
obsidian-cli bookmarks format=json
```

## Search commands

```bash
# Full-text search (scoped to folder)
obsidian-cli search query="interview" path="01 - PROJECTS" format=json

# Search with matching line context
obsidian-cli search:context query="keepit" path="01 - PROJECTS"

# Vault-wide search (only when explicitly asked)
obsidian-cli search query="term" format=json

# Options: limit=<n>, case (case-sensitive), total (count only)
```

## Link and graph commands

```bash
# Outgoing links from a note
obsidian-cli links path="some-note.md"

# Backlinks (what links here)
obsidian-cli backlinks path="some-note.md" format=json

# Orphan notes (no incoming links)
obsidian-cli orphans

# Dead-end notes (no outgoing links)
obsidian-cli deadends

# Unresolved wikilinks
obsidian-cli unresolved format=json
```

## Properties and metadata

```bash
# All properties for a note (frontmatter)
obsidian-cli properties path="some-note.md" format=yaml

# Read a specific property value
obsidian-cli property:read name="status" path="some-note.md"

# Tags (for a note or vault-wide with counts)
obsidian-cli tags path="some-note.md"
obsidian-cli tags counts sort=count

# Tasks (filter by status)
obsidian-cli tasks path="some-note.md" todo
obsidian-cli tasks path="some-note.md" done

# Heading outline
obsidian-cli outline path="some-note.md" format=tree

# Aliases
obsidian-cli aliases path="some-note.md"
```

## Write commands (use only when explicitly asked)

```bash
# Create a new note
obsidian-cli create name="New Note" path="01 - PROJECTS/New Note.md" content="# Title"

# Append/prepend content to a note
obsidian-cli append path="some-note.md" content="New content here"
obsidian-cli prepend path="some-note.md" content="Top content"

# Set a frontmatter property
obsidian-cli property:set name="status" value="active" path="some-note.md"

# Remove a property
obsidian-cli property:remove name="old-prop" path="some-note.md"

# Move/rename a file
obsidian-cli move path="old/path.md" to="new/path.md"
obsidian-cli rename path="note.md" name="New Name"

# Delete (moves to trash by default)
obsidian-cli delete path="some-note.md"
```

## Template commands

```bash
# List available templates
obsidian-cli templates

# Read a template (optionally resolve variables)
obsidian-cli template:read name="Daily Note" resolve title="2026-04-01"
```

## History and versioning

```bash
# List files with history
obsidian-cli history:list

# List versions for a file
obsidian-cli history path="some-note.md"

# Read a specific version
obsidian-cli history:read path="some-note.md" version=2

# Diff between versions
obsidian-cli diff path="some-note.md" from=1 to=2
```

## Bases (`.base` files)

Obsidian Bases are YAML-defined views over vault metadata — tables, cards, lists driven by file and frontmatter properties. Schema evolves between Obsidian releases.

**Before editing any `.base` file:**

1. Check the installed Obsidian version:
   ```bash
   /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" /Applications/Obsidian.app/Contents/Info.plist
   ```
2. Pull the current schema from the official `obsidianmd/obsidian-help` repo (the rendered help site is a JS SPA and does not return content via WebFetch — go to the source):
   ```bash
   gh api "repos/obsidianmd/obsidian-help/contents/en/Bases" --jq '.[].name'
   gh api "repos/obsidianmd/obsidian-help/contents/en/Bases/Bases syntax.md" --jq '.content' | base64 -d
   gh api "repos/obsidianmd/obsidian-help/contents/en/Bases/Views.md" --jq '.content' | base64 -d
   gh api "repos/obsidianmd/obsidian-help/contents/en/Bases/Functions.md" --jq '.content' | base64 -d
   ```

**Gotchas confirmed by source docs (as of Obsidian 1.12):**

- `file.name` **includes** the extension (e.g. `"STATUS.md"`). Use `file.basename` for extensionless comparisons.
- Relative dates use function form: `file.mtime > now() - "14d"`. String literals like `"now-14d"` are not parsed.
- Valid duration units: `y`, `M`, `d`, `w`, `h`, `m`, `s` — or full words (`"1 week"`, `"2 hours"`).
- Folder matching: `file.inFolder("foo")` (first-class, recurses into subfolders) or `file.folder.startsWith("foo/")` / `file.folder.contains("bar")` (string ops on the `string`-typed `file.folder`).
- Top-level keys: `filters`, `formulas`, `properties`, `summaries`, `views`.
- View keys: `type` (table | cards | list | map), `name`, `limit: N`, `filters`, `order`, `sort`, `groupBy`, `summaries`. `columnSize` is UI-written and undocumented — safe but not canonical.
- Filter groups: `and:`, `or:`, `not:` — each a list of filter statements or nested groups.
- Boolean operators inside filter strings: `!`, `&&`, `||`. Comparison: `==`, `!=`, `>`, `<`, `>=`, `<=`.

**Latest docs source of truth:** `github.com/obsidianmd/obsidian-help/tree/main/en/Bases` — always prefer this over guessing or training-data recall. Syntax changes between minor Obsidian versions.

## Vault structure (top-level folders)

| Folder | Contents |
|--------|----------|
| `00 - INBOX` | Unsorted captures |
| `01 - PROJECTS` | Active projects (PARA method) |
| `02 - AREAS` | Ongoing areas of responsibility |
| `03 - RESOURCES` | Reference material, people, topics |
| `Journal/Daily` | Daily notes (YYYY-MM-DD.md) |
| `Clippings` | Web clippings |
| `Retroscope` | CC session retrospectives |

## Rules

- **Read-only by default.** Do not create, edit, append, or delete notes unless explicitly asked.
- **Ask before browsing.** If the user says "search my vault" without a folder, ask which area to scope to - or search vault-wide if they confirm.
- **Follow links when referenced.** If a note links to `[[Some Person]]` in `03 - RESOURCES/People/`, you may follow and read that specific note.
- **Obsidian must be running** for CLI commands to work. If a command returns empty, suggest the user open Obsidian.
- **For daily note operations**, use the `/daily-note` skill instead - it has specialized commands for read/append/tasks.
- **iCloud sync risk.** Write operations can cause sync conflicts. Prefer small, targeted writes over bulk operations.
