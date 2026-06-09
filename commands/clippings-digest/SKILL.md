---
name: clippings-digest
description: >
  Generate a digest of unreviewed Obsidian web clippings, append it to the daily
  note, and emit a self-contained HTML editorial page. Reads and summarizes via
  parallel Haiku subagents so large backlogs stay cheap.
  Triggers: "digest clippings", "review clippings", "what have I clipped",
  "clippings digest", "summarize clippings", "new clippings".
  Use when the user wants to catch up on saved articles they haven't reviewed yet.
---

# Clippings digest

Reads unreviewed web clippings from the Obsidian vault, summarizes them by topic
via parallel Haiku subagents, appends a Markdown digest to the daily note, and
renders a styled, self-contained HTML editorial page.

## How it works

1. Find clippings without the `reviewed: true` frontmatter property
2. Fan out to Haiku subagents (5 clippings each) that read + summarize + nominate a "star" — orchestrator never sees the raw bodies
3. Merge subagent JSON, pick the overall star
4. Format the Markdown digest grouped by category
5. Generate the HTML editorial page
6. Append the digest + an HTML link to today's daily note
7. Mark processed clippings as `reviewed: true` (this is the memory — runs are idempotent)

## Step 1: Find unreviewed clippings

The `reviewed: true` frontmatter property is the persistent memory of what's been processed. Filter the vault directly via the filesystem to avoid 200+ slow CLI calls:

```bash
VAULT_PATH=$(obsidian-cli vault info=path)
cd "$VAULT_PATH/Clippings"

# Files NOT yet marked reviewed: true
# Use -E with optional quotes — Obsidian sometimes writes `reviewed: "true"`
grep -EL '^reviewed: *"?true"?' *.md
```

If there are more than 20 unreviewed clippings, process only the **20 newest** (by `created` date in frontmatter — most recent first, since the typical flow is "I clipped some stuff, now process it"). Mention the remaining count in the digest.

```bash
# Sort unreviewed clippings by `created` descending, take top 20
for f in *.md; do
  if ! grep -Eq '^reviewed: *"?true"?' "$f"; then
    created=$(awk '/^created:/{print $2; exit}' "$f")
    echo "${created:-0000-00-00}|$f"
  fi
done | sort -r | head -20 | cut -d'|' -f2-
```

Files with no `created` field sort to the end (oldest), so newly-clipped items with proper frontmatter are processed first.

## Step 2: Read and summarize (fan-out)

The reads are independent and the summaries discard 95% of each clipping's content. Don't burn the orchestrator's context window doing this serially — fan out to Haiku subagents.

**Skip fan-out if total clippings ≤ 5** — read directly with the `Read` tool in the orchestrator. Spawning a subagent for 3 files is a net loss.

Otherwise:

1. Split the file list into batches of **5 clippings per batch**.
2. Cap concurrency at **6 subagents in flight at once**. With the default 20-clipping run that's 4 batches → all in parallel. With `all` mode (potentially 200+ clippings), process 6 batches at a time, wait for them, then dispatch the next 6.
3. Spawn one `Agent` tool call per batch, all in a single message:
   - `subagent_type: "general-purpose"`
   - `model: "haiku"` — extractive summarization is well within Haiku's competence and saves ~80% on the read-heavy phase
   - `description`: `"Summarize clippings batch N"`
   - `prompt`: see template below

### Subagent prompt template

```
You are summarizing a batch of {N} Obsidian web clippings for a daily-note digest. Read each file, extract metadata, and produce a structured JSON summary.

## Files to process (absolute paths)

- {abs_path_1}
- {abs_path_2}
- ... up to 5

## What to extract per file

- `title`: from frontmatter `title` field
- `source`: from frontmatter `source` field (URL)
- `tags`: from frontmatter `tags` field (array)
- `summary`: 1-2 sentence summary of the article's core value. Honest — if the clipping is too short or trivial to summarize, say so plainly.
- `category`: assign ONE primary category from this taxonomy:

| Tag prefix | Category |
|---|---|
| `ai*`, `llm`, `mcp`, `claude-code` | AI |
| `product-management`, `frameworks`, `strategy` | Product |
| `adtech`, `dsp`, `programmatic` | Ad tech |
| `software-engineering`, `web-dev`, `coding-tools`, `engineering`, `software` | Engineering |
| `design`, `typography` | Design |
| `music-synths`, `eurorack` | Music/synths |
| `philosophy`, `productivity`, `pkm`, `digital-garden`, `knowledge` | Thinking |
| `books` | Books |
| `hardware-diy`, `iot`, `homelab`, `networking` | Hardware |
| `cooking` | Cooking |
| Everything else | Other |

## Star nomination

Pick ONE clipping from your batch as the "star" — the standout most worth surfacing. One-line rationale on why.

## Output format — return EXACTLY this JSON in a single fenced code block, nothing else

```json
{
  "summaries": [
    {
      "path": "Clippings/<filename>.md",
      "title": "...",
      "source": "https://...",
      "tags": ["..."],
      "category": "AI",
      "summary": "1-2 sentences."
    }
  ],
  "star": {
    "path": "Clippings/<filename>.md",
    "rationale": "Why this stands out."
  }
}
```

Do not append a prose summary or commentary outside the JSON block. The orchestrator parses the block and discards everything else.
```

### Failure handling

If a subagent returns an error, malformed JSON, or no JSON block at all, capture the paths it was given. Those clippings go to the **Unsummarized** section in Step 4 and are NOT marked reviewed in Step 7 — the user can re-run to retry.

## Step 2.5: Merge

Collect JSON from all subagent results:

- Concatenate all `summaries` arrays.
- Collect all `star` nominees (≤ 6 of them, one per batch).
- Pick the **overall star** from the nominees by judging which rationale most aligns with novelty and load-bearing relevance to the user's projects (read the project CLAUDE.md if needed for context). The orchestrator does NOT re-read clipping bodies for this — pick from the rationales alone.

## Step 3: Group by topic

Group the merged summaries by `category` field (already assigned by subagents). The taxonomy used by subagents is in the prompt template above; see "Tag taxonomy reference" at the bottom of this file for the canonical source.

## Step 4: Format the Markdown digest

This is the audit-trail digest that goes into the daily note.

```markdown
## Clippings digest

*{count} new clippings — {remaining} more remain in the backlog. {duplicate notes if any}*

### {Category name} ({count})

- **{Title}** — {1-2 sentence summary} {#tag1 #tag2 …} [source]({url})
- ...

### Unsummarized ({count})

These clippings couldn't be auto-summarized — re-run the digest to retry, or open them manually:

- **{Title}** {#tag1 #tag2 …} [source]({url})
```

Mark the overall star (chosen in Step 2.5) with a `⭐` prefix and bold the entry. Include the **Unsummarized** section only if at least one batch failed.

**Tag rendering rules:**
- Render each tag as `#tagname` (with `#` prefix), space-separated. These become real Obsidian tags, navigable from the tag pane.
- Do NOT wrap the tag list in backticks — that produces an inert inline-code span, not a tag.
- If a clipping has no tags in frontmatter, render `_(no tags)_` (italics) rather than `#none` or backticks.
- Multi-word tags use hyphens: `#world-models`, not `#world models`.

## Step 5: Generate the HTML editorial page

Render the same content as a self-contained HTML page using the plugin's
template. **Skip this step entirely in `peek` mode.**

1. **Ensure the output directory exists:**

   ```bash
   mkdir -p ~/clipping-summaries
   ```

2. **Read the template:**
   `${CLAUDE_PLUGIN_ROOT}/commands/clippings-digest/templates/digest-page.html`

3. **Fill it in.** Replace every `{{TOKEN}}`, clone the topic-section block once
   per category, clone the `.dog` card once per clipping, clone the source `<li>`
   once per clipping. Delete all instructional HTML comments (including the header
   block) from the final file.

   - `{{TITLE}}` — an editorial headline for the batch, not "Clippings digest".
     Wrap one or two words in `<em>` for the accent colour.
   - `{{STANDFIRST}}` — one sentence framing what the batch is about.
   - `{{LEAD_PARAGRAPH}}` — a short intro; the CSS drop-caps the first letter.
   - `{{CATEGORY_KICKER}}` / `{{CATEGORY_HEADING}}` — the topic-section labels.
   - `.dog` card per clipping: `{{N}}` (running number across the whole page),
     `{{CLIPPING_TITLE}}`, `{{CLIPPING_SUMMARY}}`, `{{TAGS}}`, `{{SOURCE_URL}}`,
     `{{SOURCE_DOMAIN}}`.
   - `{{ENDNOTE}}` — note how many clippings, the date, and that it mirrors the
     daily-note digest.

4. **Default rendering uses only the template's built-in subset** — masthead,
   standfirst, topic sections, `.dog` cards, sources, endnote. Optionally elevate
   the single best clipping with one `<blockquote>` pull quote (the one bespoke
   component that always suits a digest).

5. **Bespoke components** (charts, `.players`, `.timeline`, `.callout`,
   `.bottomline`) are used **only when the batch genuinely supports them** — see
   `${CLAUDE_PLUGIN_ROOT}/commands/clippings-digest/references/component-kit.md`
   for each component and its when-to-use gate. Default = use none of them. Never
   fabricate data to fill a chart.

6. **Write the file** to `~/clipping-summaries/{ISO-date}-{slug}.html`:
   - `{ISO-date}` — today, e.g. `2026-05-22`.
   - `{slug}` — `clippings-digest` for a default run, `clippings-digest-{topic}`
     for a `topic <tag>` run.
   - If that filename already exists, append `-2`, `-3`, … Never overwrite.

## Step 6: Append to daily note

Two appends under the `# NOTES` section (skip both in `peek` mode):

1. The full Markdown digest from Step 4.
2. A short link entry pointing at the HTML file:

   ```markdown
   📄 [Clippings editorial — {date}](file:///Users/ostaps/clipping-summaries/{slug}.html) — {N} clippings across {M} topics
   ```

```bash
obsidian-cli append daily content="{line}"
```

`append daily` silently drops multi-line content — issue one `append daily` call
per line, and verify by reading the daily note afterward.

## Step 7: Mark as reviewed

After the digest is appended and the user has seen it, mark each successfully-summarized clipping so future runs skip it.

### Default path: use the Obsidian CLI (one call per file)

```bash
obsidian-cli property:set name="reviewed" value="true" type=checkbox path="Clippings/<filename>"
```

**This is the only way to write frontmatter that's safe by default.** The CLI parses YAML properly, so it handles every edge case the Obsidian Web Clipper produces (tags as inline arrays, missing trailing newlines, `---` without leading `\n`, mixed quoting, list values, comments).

For ~50 files this takes a couple of minutes wall time and is fine.

### Bulk path (50+ files): direct YAML rewrite

For a full backlog drain (200+ files), per-file CLI calls become slow. **Do NOT use string splicing on the `---` fences** — Web Clipper output varies in subtle ways that break naive `text.find("\n---\n")` parsers (real failure mode encountered: closing fence eaten, `reviewed: true` concatenated to previous line). Use a real YAML parser instead:

```python
import re
import yaml
from pathlib import Path

FM_RE = re.compile(r'^---\s*\n(.*?\n)---\s*\n', re.DOTALL)

def mark_reviewed(fpath: Path) -> str:
    """Returns 'marked' | 'already' | 'no-frontmatter' | 'parse-error'."""
    text = fpath.read_text()
    m = FM_RE.match(text)
    if not m:
        return "no-frontmatter"
    try:
        data = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return "parse-error"
    if data.get("reviewed") is True or str(data.get("reviewed", "")).lower() == "true":
        return "already"
    data["reviewed"] = True
    new_fm = yaml.safe_dump(data, sort_keys=False, allow_unicode=True, default_flow_style=False).rstrip()
    body = text[m.end():]
    fpath.write_text(f"---\n{new_fm}\n---\n{body}")
    return "marked"
```

Why this is safe:
- Anchors on `^---\s*\n` and `\n---\s*\n` (not `\n---\n`) — handles `\r\n` and trailing whitespace.
- Round-trips through PyYAML, so the output is always valid YAML regardless of input quirks.
- Preserves body content verbatim (no transformation of the rest of the file).
- Idempotent: re-running on already-marked files returns "already" without rewriting.

**After bulk rewrite, always validate:** if any files come back as `parse-error` or `no-frontmatter`, list them — those are real cases worth surfacing (genuinely empty clippings, manually-edited frontmatter, etc.) and should NOT be silently skipped.

### Verification (both paths)

After marking, run:

```bash
VAULT_PATH=$(obsidian-cli vault info=path)
cd "$VAULT_PATH/Clippings"

# Should equal previous_count + summaries-marked
grep -El '^reviewed: *"?true"?' *.md | wc -l

# Should be 0 — anything else means concatenation/corruption bugs
grep -lE '[^[:space:]]reviewed: true' *.md | wc -l
```

The second check catches the specific failure mode of "reviewed: true got appended mid-line." If non-zero, something in the rewrite went wrong — investigate before continuing.

### Rules

- Mark only clippings that appear in the merged `summaries` array. Skip anything in the **Unsummarized** section — those should remain unreviewed so the user can re-run on them.
- Always show the digest first, then ask the user explicitly: *"Mark these N clippings as reviewed?"* Do not infer confirmation from silence.
- Use `type=checkbox` (CLI path) or boolean `True` (Python path) so Obsidian renders the property as a boolean, not a string.

## Options

The user can customize the digest:

- `/clippings-digest` - default: process up to 20 newest unreviewed
- `/clippings-digest all` - process all unreviewed clippings
- `/clippings-digest oldest` - process 20 oldest unreviewed (use to drain the backlog)
- `/clippings-digest topic ai` - only digest clippings with AI-related tags
- `/clippings-digest peek` - show digest without marking as reviewed, appending
  to the daily note, or generating the HTML page

## Tag taxonomy reference

The taxonomy table in the Step 2 subagent prompt above is the canonical source —
keep the two in sync if you edit either. Users should adapt categories to match
their own tagging conventions; the full taxonomy is also documented at
`/Users/ostaps/code/cc-obsidian/analysis/tag-taxonomy.md`.

## Rules

- **Respect privacy.** Only access the `Clippings/` folder.
- **Don't auto-mark.** Always show the digest first, then mark as reviewed.
- **Keep summaries honest.** If a clipping is too short to summarize meaningfully,
  just show the title and tags. Never fabricate data for an HTML chart.
- **Subagents are read-only.** Pass file paths, get JSON back. Subagents must not
  write to the daily note or mark anything reviewed — only the orchestrator does
  writes, and only after user confirmation.
- **The HTML mirrors the digest.** The HTML page renders the same clippings and
  summaries as the Markdown digest — it is a restyling, never a different summary.
- **Never overwrite HTML files.** `~/clipping-summaries/` is created if missing;
  filename collisions get a `-2`/`-3` suffix so every run is a distinct artifact.
- **Cost guard for `all` mode.** With Haiku at 5-clippings-per-batch the read-heavy
  phase is cheap, but warn the user before processing 100+ clippings in a single
  run. Default `/clippings-digest` is capped at 20 newest.
- **Obsidian must be running** for CLI commands. If commands fail, tell the user
  to open Obsidian.
- **Be concise.** The Markdown digest should be scannable — one line per clipping,
  grouped by topic.
