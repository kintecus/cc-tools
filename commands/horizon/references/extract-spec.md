# Extract spec

The block-by-block algorithm `horizon-extract.py` uses to turn raw session
JSONL into ultra-clean prose for the Haiku per-day summarization stage.

This is **stricter than retroscope's extract mode**. Tool data is preserved
separately as stats and never reaches the bulk LLM.

## Per-line loop

For each line in the session JSONL:

1. Parse as JSON. On parse error → skip (log to stderr in `--debug`).
2. If `obj.type not in ("user", "assistant")` → skip.
3. Parse `obj.timestamp` to a `datetime`. Convert to `--tz`. If date != `--date`
   → skip.
4. Walk `obj.message.content` blocks:
   - Apply block-level filters (below).
5. If the resulting text is non-empty, emit:

```
[{ISO timestamp, local tz} | {role}]
{joined block texts}

```

## Block-level filters

| Block type | Action |
| --- | --- |
| `text` (user) | Apply user-text drop patterns + correction-collapse + emit if non-empty |
| `text` (assistant) | Apply length compression + emit |
| `tool_use` | Drop entirely (no name, no input) |
| `tool_result` | Drop entirely |
| anything else | Drop entirely |

## User-text drop patterns

If a `text` block's content matches any of these at start-of-string (case
sensitive unless noted), drop the whole block:

```
^# claudeMd\b
^# currentDate\b
^# userEmail\b
^# MEMORY\b
^<system-reminder>
^<command-name>
^<command-message>
^<command-args>
^<local-command-stdout>
^<local-command-stderr>
^SessionStart:
^Base directory for this skill:
^# Mermaid Diagram
^# PlantUML Diagram
^# Branch Naming
^# Technology Explainer
^# Plan Review Protocol
^# Retroscope
^# Daily Note
^# Obsidian vault reader
```

The last 9 patterns catch skill-doc bodies that leak as user-role text
blocks when the model invokes a Skill — those documents are plugin
guidance, not user prose, and they dilute the bulk summarization signal.

Also drop blocks that consist *entirely* of:

- A `<system-reminder>…</system-reminder>` wrapper
- A `<command-name>…</command-name>` wrapper
- Hook output framed as `## Plan Review …`, `## Semantic Versioning …`,
  `## Mermaid Diagrams …`, `## PlantUML Diagrams …` (all SessionStart hook
  banners from the user's setup)
- The MEMORY.md index header + bullet list
- `Contents of /Users/.+/CLAUDE.md` block (auto-injected per-project rules)

If a user message has **multiple text blocks** and only some match drop
patterns, drop the matching blocks and keep the rest. Only omit the whole
turn when every block is dropped.

## Single-token correction collapse (user only)

Match (case-insensitive, full block content, ≤16 chars):

```
^(y|n|yes|no|ok|okay|continue|go|do it|lgtm|sure|yep|nope|stop|done|cool|next|now|.|\?)\s*$
```

When **>3 consecutive user turns** match this pattern, collapse them into a
single synthetic turn:

```
[{first-timestamp} | user]
[user nudged ×N]

```

A turn breaks the streak the moment its content fails the regex.

## Assistant compression

If `len(text) > --max-asst-chars` (default 3000):

- **If text contains fenced code blocks** (lines starting with ` ``` `):
  - Walk the text; replace each code block with its first non-empty line
    followed by ` … [code trimmed] `.
  - Keep all prose outside code blocks verbatim.
  - If the result is still longer than the threshold, fall back to the
    head/tail strategy below.
- **Else (no code blocks)**:
  - Emit `text[:1200] + " […trimmed…] " + text[-600:]`.

This preserves file paths, decisions, and structural intent that the bulk
summarizer needs without dragging full long answers through tokens.

## Empty-turn elision

If after filtering a turn has no remaining text content, do **not** emit a
header. The output is gap-free; reading it should feel like a chat transcript
with all the JSON garbage and tool noise removed.

## Reduction calibration

Target: ≥90% byte reduction vs raw JSONL.

Calibration test (run once, record the number in this file):

```bash
RAW=$(ls -S ~/.claude/projects/-Users-ostaps-code/*.jsonl | head -1)
RAW_BYTES=$(wc -c < "$RAW")
EXTRACTED_BYTES=$(python3 horizon-extract.py \
  --session "$RAW" \
  --date $(date +%Y-%m-%d) \
  --tz Europe/Warsaw | wc -c)
echo "raw=$RAW_BYTES extracted=$EXTRACTED_BYTES ratio=$(bc -l <<<"1 - $EXTRACTED_BYTES/$RAW_BYTES")"
```

Record:

- Date measured: _to be filled during validation_
- Raw bytes: _TBD_
- Extracted bytes: _TBD_
- Reduction ratio: _TBD_
- Top 5 dropped block types by byte volume: _TBD_

If ratio < 90%, tighten the drop patterns above before merging the PR.
