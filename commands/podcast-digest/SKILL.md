---
name: podcast-digest
description: >
  Generate an editorial digest of recent podcast and YouTube transcripts captured
  by pidcast, and emit a self-contained HTML editorial page plus a Markdown archive
  note in your Obsidian vault. Reads and summarizes via parallel Haiku subagents so
  large batches stay cheap.
  Triggers: "podcast digest", "digest my podcasts", "summarize recent podcasts",
  "what have I listened to", "digest transcripts", "podcast roundup".
  Use when the user wants an editorial catch-up on transcripts they've captured.
---

# Podcast digest

Reads recent podcast/YouTube transcripts from the pidcast data dir, summarizes them
by topic via parallel Haiku subagents, synthesizes an editorial angle, and writes
two artifacts: a styled self-contained HTML editorial page and a Markdown archive
note. Both land in the user's Obsidian vault.

## How it works

1. Resolve the transcripts dir from `pidcast info` and select a recency window
2. **Filter to genuine podcast/YouTube transcripts** by front-matter `url` (this is load-bearing — the `tags` field is unreliable)
3. Fan out to Haiku subagents (~5 transcripts each) that read + summarize + nominate a "star" — the orchestrator never sees the raw transcript bodies
4. Merge subagent JSON, pick the overall star, group by category
5. Synthesize an editorial angle across the batch (the through-line)
6. Render the HTML editorial page and the Markdown archive note into the vault
7. Optionally append a pointer to the daily note

Digests are **windowed by recency**, not marked — there is no per-file "processed"
memory. Re-running the same window regenerates (never overwrites — see Step 6).

## Prerequisites

- `pidcast` installed and on `PATH` (`pidcast info` must resolve). If it isn't, tell
  the user and stop — this skill has no other transcript source.
- Obsidian desktop app running with the CLI enabled, for vault-path resolution and
  the optional daily-note append. If the CLI is unavailable, fall back to writing
  into `~/podcast-summaries/` and tell the user.

## Step 1: Resolve source and select the window

```bash
# The canonical transcripts store (XDG data dir by default; never assume a path)
TRANSCRIPTS=$(pidcast info | awk -F'transcripts:[[:space:]]*' '/transcripts:/{print $2; exit}')
```

Default window is **last 30 days**. Parse the user's argument (see Options) into a
cutoff date `YYYY-MM-DD` or an explicit "last N" count. pidcast filenames are
`YYYY-MM-DD_Title.md`, so the date prefix is the primary sort/filter key; fall back
to the front-matter `date` field for legacy undated filenames.

## Step 2: Filter to genuine podcast/YouTube transcripts (load-bearing)

The transcripts dir mixes real podcast/YT transcripts with things that must be
**skipped**: local meeting recordings, smoke tests, prior digests, and analysis
side-files. **Do not filter on the `tags` field** — pidcast writes
`['podcast','youtube','transcription']` onto meeting recordings too. Filter on the
front-matter `url` instead:

| Front-matter signal | Classification | Action |
|---|---|---|
| `url:` contains `youtube.com`, `youtu.be`, or `podcasts.apple.com` | Podcast / YouTube | **KEEP** |
| `url:` is `file://…` (local audio, e.g. a meeting `.m4a`/`.mp3`) | Local recording / meeting | skip |
| filename ends `_analysis_summary.md` / `_analysis_key_points.md`, or front matter has `analysis_type:` | Analysis side-file | skip |
| front matter `type: podcast-digest`, or filename contains `podcast-digest` | A prior digest | skip |
| filename contains `pidsmoke`, `test_`, `Test_`, or `url:` under `/tmp/` | Test / smoke fixture | skip |

```bash
cd "$TRANSCRIPTS"
is_podcast() { # $1 = .md filename; returns 0 to KEEP
  local f="$1" url
  case "$f" in *_analysis_summary.md|*_analysis_key_points*.md|*podcast-digest*|*pidsmoke*|*test_*|*Test_*) return 1 ;; esac
  url=$(awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} /^url:/{print; exit}' "$f")
  case "$url" in
    *youtube.com*|*youtu.be*|*podcasts.apple.com*) return 0 ;;
    *) return 1 ;;
  esac
}
```

Build the KEEP list for the window. If a file has no `url:` at all (legacy
pre-migration format), classify it UNKNOWN and **list those for the user rather than
silently including or dropping them** — they are usually genuine but old.

**Report the survey before summarizing:** e.g. "42 transcripts in window; 26 genuine
podcast/YT, 12 meetings/tests skipped, 4 legacy-format unknown — proceed with 26?"
If anything is ambiguous, ask before spending tokens.

## Step 3: Read and summarize (fan-out)

The reads are independent and the summaries discard ~95% of each transcript. Don't
burn the orchestrator's context reading these serially — and **never read raw
transcripts into the orchestrator** (they run to hundreds of KB each).

**Skip fan-out if the KEEP list is ≤ 3** — read directly in the orchestrator.

Otherwise:

1. **Balance batches by word count, not naive count.** Transcripts range from ~1k to
   ~25k words; a naive 5-per-batch can hand one Haiku agent five 20k-word files.
   Sort by size and snake-draft into batches of ~5 so each batch is ~25-40k words.
2. Cap concurrency at **6 subagents in flight**. Dispatch all batches in one message
   when there are ≤ 6; otherwise process 6 at a time.
3. Spawn one `Agent` tool call per batch:
   - `subagent_type: "general-purpose"`, `model: "haiku"`
   - `description`: `"Summarize transcript batch N"`
   - `prompt`: the template below

### Subagent prompt template

```
You are summarizing a batch of {N} podcast/YouTube transcripts for an editorial
digest. Each file is a pidcast Markdown transcript: YAML front matter (title, url,
duration, channel) followed by the raw transcript body. Read each file fully, then
produce a structured JSON summary. Extractive only — do not invent facts.

## Files to process (absolute paths)
- {abs_path_1}
- ... up to ~5

## What to extract per file
- `title`, `url`: from front matter
- `channel`: front-matter `channel` if present, else infer the show name, else null
- `duration`: front-matter `duration` if present, else null
- `category`: assign ONE from this taxonomy (adapt to the actual batch):
  | Category | Fits when the episode is mainly about… |
  |---|---|
  | AI models & releases | model launches, benchmarks, capabilities, model-vs-model |
  | AI industry & economics | AI business, funding, costs/pricing, labs' strategy, jobs, compute |
  | Engineering & dev practice | software craft, dev tools, coding agents, context engineering |
  | Product & PM | product management, product strategy, how companies build |
  | Tech culture & media | tech news roundups, platforms, surveillance, internet culture |
  | Politics & economy | macroeconomics, geopolitics, policy, elections |
  | Music & culture | music/album reviews, art, creativity, consumerism |
  | Other | anything that fits none of the above |
- `summary`: 2-3 sentence honest summary of the core argument. If thin/promotional, say so.
- `key_takeaways`: 2-4 short strings — concrete claims, numbers, names worth remembering.
- `notable_quote`: ONE short verbatim quote (< 30 words), or null.

## Star nomination
Pick ONE episode from your batch as the standout most worth surfacing (novelty,
insight density, relevance). One-line rationale.

## Output format — return EXACTLY this JSON in a single fenced ```json block, nothing else
{
  "summaries": [
    { "path":"...", "title":"...", "url":"...", "channel":"...", "duration":"...",
      "category":"...", "summary":"...", "key_takeaways":["..."], "notable_quote":"..." }
  ],
  "star": { "path":"...", "rationale":"..." }
}
Return only the JSON block. No prose before or after it.
```

### Failure handling

If a subagent returns malformed JSON or no block, capture the paths it was given and
list them in an **Unsummarized** section of the note. Never fabricate summaries.

## Step 4: Merge and pick the star

Concatenate the `summaries` arrays, collect the per-batch `star` nominees, and pick
the **overall star** by judging which rationale best combines novelty with relevance
to the user's work (read project CLAUDE.md if needed). Pick from rationales alone —
do not re-read transcript bodies.

## Step 5: Synthesize the editorial angle

Unlike a clippings survey, a month of one person's podcast listening usually has a
**through-line** — a recurring theme, a running argument, an arc of events. Find it
and make it the spine: the `{{TITLE}}`, `{{STANDFIRST}}`, `{{LEAD_PARAGRAPH}}`, and
(if the batch supports it) a `bottomline`. This is the editorial value-add over a
flat list. Keep it honest — if the batch is genuinely miscellaneous, say so and lean
on the per-category grouping instead.

## Step 6: Render the artifacts

Resolve the vault path and target folder:

```bash
VAULT=$(obsidian-cli vault info=path 2>/dev/null)     # requires Obsidian running
OUT_DIR="$VAULT/03 - RESOURCES/Podcasts"              # DEFAULT — adapt to the user's vault
mkdir -p "$OUT_DIR"                                   # fall back to ~/podcast-summaries if no vault
```

> The `03 - RESOURCES/Podcasts` default follows the PARA convention; if the user's
> vault differs, ask once or honor a `--out <folder>` argument. Never hardcode an
> absolute vault path — always resolve it via `obsidian-cli`.

**HTML page** — read `${CLAUDE_PLUGIN_ROOT}/commands/podcast-digest/templates/digest-page.html`
and fill it in:

- Clone the `<!-- BEGIN SECTION -->…<!-- END SECTION -->` block once per category
  (order categories by relevance/size, with the strongest first).
- Clone the `.dog` card once per episode; number `{{N}}` runs 1..count across the
  whole page. Clone the `<li>` in `<ul class="tk">` once per takeaway; delete the
  `<ul>` if an episode has none.
- Put the `.starbadge` span and `class="star"` on the overall star card **only**;
  remove the badge from every other card.
- Add bespoke components **when the batch genuinely supports them** (see
  `references/component-kit.md`): a `players` grid for 2-4 comparable subjects, a
  `timeline` for a real chronology, a `figure`+SVG chart for real numbers, a
  `callout`, a `blockquote` pull quote, a `bottomline` for a genuine single
  takeaway. Never fabricate data to fill one.
- Fill `{{ENDNOTE}}` with the method: N transcripts, the window, filtered to
  podcast/YT only, summarized by M parallel Haiku subagents, preview-model numbers
  flagged provisional.
- Delete every instructional HTML comment (including the header block).
- Write to `$OUT_DIR/{ISO-date}-podcast-digest-{slug}.html` where `{slug}` encodes
  the window (e.g. `30d`, `14d`, `since-2026-06-01`). **If the file exists, append
  `-2`/`-3`. Never overwrite** — each run is a distinct artifact.

**Markdown archive note** — write a scannable note to
`$OUT_DIR/{ISO-date} Podcast digest — {window}.md` with:

- Front matter: `title`, `created`, `type: podcast-digest`, `window`, `episodes`,
  `source: pidcast`, `tags: [podcast, digest, …]`.
- A one-line link to the HTML page.
- An abstract callout with the through-line, and the ⭐ star.
- One `### {Category}` section per group; per episode a bold title, 1-line summary,
  its 2-4 takeaways as sub-bullets, and a `` `Show · Duration` `` + `[source](url)`
  line. Mark the star with ⭐.
- An **Unsummarized** section only if a batch failed.

The HTML and the note render the **same** episodes and summaries — the HTML is a
restyling, never a different summary.

## Step 7: Optional daily-note pointer

Unless `--no-daily`, append one line to the daily note pointing at the artifacts
(use the daily-note skill / `obsidian-cli append daily`; one call per line — it drops
multi-line content):

```
🎙️ [Podcast digest — {date}]({html-file-uri}) — {N} episodes across {M} topics, {window}
```

## Options

- `/podcast-digest` — default: last 30 days
- `/podcast-digest 7d` | `14d` | `30d` — recency window
- `/podcast-digest since 2026-06-01` — explicit cutoff
- `/podcast-digest last 15` — the 15 most recent, regardless of date
- `/podcast-digest topic ai` — only categories matching a topic keyword
- `/podcast-digest --out "<vault folder>"` — override the output folder
- `/podcast-digest --no-daily` — skip the daily-note pointer
- `/podcast-digest peek` — show the survey and proposed batch plan without spending
  tokens on summaries or writing anything

## Rules

- **Respect the skip filter.** Only summarize KEEP-classified podcast/YT transcripts.
  Meeting recordings and other local audio are private and out of scope — never read
  or summarize them.
- **Never read raw transcripts into the orchestrator.** Pass paths to Haiku
  subagents; the orchestrator works from returned JSON only. Subagents are read-only.
- **Windowed, not marked.** Selection is by recency window; there is no per-file
  processed flag. Never overwrite an existing artifact — suffix `-2`/`-3`.
- **Keep it honest.** Extractive summaries; flag preview-model benchmark numbers as
  provisional; never fabricate data for a chart or comparison row. If the batch has
  no real through-line, don't invent one.
- **Resolve paths dynamically.** `pidcast info` for transcripts, `obsidian-cli` for
  the vault. Never hardcode an absolute path.
- **Cost guard.** Fan-out over Haiku keeps big windows cheap, but warn before
  processing 60+ transcripts in one run.
