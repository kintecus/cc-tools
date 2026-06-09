#!/usr/bin/env python3
"""
horizon-extract.py — strict clean-prose extractor for Claude Code session JSONL.

Used by /horizon to produce ultra-clean text for the Haiku per-day bulk
summarization stage. Stricter than retroscope's --extract mode: drops tool
calls, hook output, system reminders, memory injections, and compresses
long assistant turns.

See: commands/horizon/references/extract-spec.md for the algorithm.
See: commands/horizon/references/cli-contracts.md for the CLI contract.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from datetime import date, datetime
from pathlib import Path
from typing import Iterable
from zoneinfo import ZoneInfo


# --- Drop patterns -----------------------------------------------------------

# Match against the START of a text block. Case sensitive.
USER_TEXT_DROP_PREFIXES = (
    "# claudeMd",
    "# currentDate",
    "# userEmail",
    "# MEMORY",
    "<system-reminder>",
    "<command-name>",
    "<command-message>",
    "<command-args>",
    "<local-command-stdout>",
    "<local-command-stderr>",
    "SessionStart:",
    "Contents of /",  # auto-injected CLAUDE.md blocks
    # Skill-doc bodies leak as user-role text blocks when the model invokes
    # a skill. Drop them — they're plugin documentation, not user prose.
    "Base directory for this skill:",
    "# Mermaid Diagram",
    "# PlantUML Diagram",
    "# Branch Naming",
    "# Technology Explainer",
    "# Plan Review Protocol",
    "# Retroscope",
    "# Daily Note",
    "# Obsidian vault reader",
)

# Whole-block "frame" patterns: if the entire text block is this, drop it.
USER_TEXT_DROP_WHOLE_BLOCK = (
    re.compile(r"^\s*<system-reminder>.*?</system-reminder>\s*$", re.DOTALL),
    re.compile(r"^\s*<command-name>.*?</command-name>\s*$", re.DOTALL),
)

# Hook banner headings that arrive as their own text blocks. Drop if the
# block STARTS with one of these markdown headings (everything after is
# also hook output until the next user-real prompt, but each banner is its
# own block so prefix match is enough).
HOOK_BANNER_PREFIXES = (
    "## Plan Review",
    "## Semantic Versioning",
    "## Mermaid Diagrams",
    "## PlantUML Diagrams",
    "## Retroscope",
    "## Git Branch Naming",
    "## Technology Explainer",
    "## Today is ",  # daily-note injection banner
)

CORRECTION_RE = re.compile(
    r"^(y|n|yes|no|ok|okay|continue|go|do it|lgtm|sure|yep|nope|stop|done|cool|next|now|\.|\?)\s*$",
    re.IGNORECASE,
)
CORRECTION_MAX_LEN = 16
CORRECTION_MIN_RUN = 4  # > 3 consecutive => collapse

CODE_FENCE_RE = re.compile(r"```")


# --- Filtering primitives ----------------------------------------------------


def is_droppable_user_text(text: str) -> bool:
    """Return True if a user-role text block should be dropped entirely."""
    if not text:
        return True
    stripped = text.lstrip()
    if any(stripped.startswith(p) for p in USER_TEXT_DROP_PREFIXES):
        return True
    if any(stripped.startswith(p) for p in HOOK_BANNER_PREFIXES):
        return True
    if any(pat.match(text) for pat in USER_TEXT_DROP_WHOLE_BLOCK):
        return True
    return False


def is_short_correction(text: str) -> bool:
    if len(text) > CORRECTION_MAX_LEN:
        return False
    return bool(CORRECTION_RE.match(text.strip()))


def compress_assistant_text(text: str, max_chars: int) -> str:
    """Compress long assistant text per extract-spec.md."""
    if len(text) <= max_chars:
        return text

    if "```" in text:
        # Replace each fenced code block with its first non-empty line + marker.
        out: list[str] = []
        in_code = False
        block_first_line: str | None = None
        for line in text.splitlines(keepends=True):
            if CODE_FENCE_RE.match(line.strip()):
                if not in_code:
                    in_code = True
                    block_first_line = None
                    out.append(line)
                else:
                    out.append("… [code trimmed]\n")
                    out.append(line)
                    in_code = False
                continue
            if in_code:
                if block_first_line is None and line.strip():
                    block_first_line = line
                    out.append(line)
                # skip rest of block body
                continue
            out.append(line)
        compressed = "".join(out)
        if len(compressed) <= max_chars:
            return compressed
        text = compressed  # fall through to head/tail

    # Head/tail fallback.
    head = text[:1200]
    tail = text[-600:]
    return f"{head} […trimmed…] {tail}"


# --- Message walking ---------------------------------------------------------


def parse_timestamp(s: str | None, tz: ZoneInfo) -> datetime | None:
    if not s:
        return None
    try:
        # Claude Code JSONL uses ISO-8601 with 'Z' or +00:00.
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.fromisoformat(s)
        return dt.astimezone(tz)
    except (ValueError, TypeError):
        return None


def extract_message_text(message: dict, role: str, max_asst_chars: int,
                          drop_counter: Counter) -> str:
    """Walk message.content blocks, return joined plaintext or ''."""
    content = message.get("content")
    if content is None:
        return ""
    if isinstance(content, str):
        # Top-level string content (older format).
        if role == "user" and is_droppable_user_text(content):
            drop_counter["user_text_drop"] += len(content)
            return ""
        if role == "assistant":
            return compress_assistant_text(content, max_asst_chars)
        return content

    if not isinstance(content, list):
        return ""

    parts: list[str] = []
    for block in content:
        if not isinstance(block, dict):
            continue
        btype = block.get("type")
        if btype == "tool_use":
            drop_counter["tool_use"] += len(json.dumps(block, ensure_ascii=False))
            continue
        if btype == "tool_result":
            drop_counter["tool_result"] += len(json.dumps(block, ensure_ascii=False))
            continue
        if btype == "text":
            text = block.get("text", "")
            if not isinstance(text, str):
                continue
            if role == "user" and is_droppable_user_text(text):
                drop_counter["user_text_drop"] += len(text)
                continue
            if role == "assistant":
                text = compress_assistant_text(text, max_asst_chars)
            parts.append(text)
        else:
            drop_counter[f"other:{btype}"] += len(json.dumps(block, ensure_ascii=False))

    return "\n".join(p for p in parts if p.strip())


def iter_session(path: Path, target_date: date, tz: ZoneInfo,
                  max_asst_chars: int, drop_counter: Counter
                  ) -> Iterable[tuple[datetime, str, str]]:
    """Yield (timestamp_local, role, text) tuples for messages matching target_date."""
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                drop_counter["json_parse_error"] += len(line)
                continue
            t = obj.get("type")
            if t not in ("user", "assistant"):
                drop_counter[f"type:{t}"] += len(line)
                continue
            ts = parse_timestamp(obj.get("timestamp"), tz)
            if ts is None or ts.date() != target_date:
                continue
            message = obj.get("message") or {}
            text = extract_message_text(message, t, max_asst_chars, drop_counter)
            if not text.strip():
                continue
            yield ts, t, text


def collapse_corrections(stream: Iterable[tuple[datetime, str, str]]
                          ) -> Iterable[tuple[datetime, str, str]]:
    """Collapse runs of >3 consecutive single-token user corrections."""
    run: list[tuple[datetime, str, str]] = []
    for ts, role, text in stream:
        if role == "user" and is_short_correction(text):
            run.append((ts, role, text))
            continue
        if run:
            if len(run) >= CORRECTION_MIN_RUN:
                yield run[0][0], "user", f"[user nudged ×{len(run)}]"
            else:
                yield from run
            run = []
        yield ts, role, text
    if run:
        if len(run) >= CORRECTION_MIN_RUN:
            yield run[0][0], "user", f"[user nudged ×{len(run)}]"
        else:
            yield from run


# --- Main --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Clean-prose extractor for Claude Code sessions.")
    p.add_argument("--session", action="append", required=True,
                   help="Session JSONL file (repeatable)")
    p.add_argument("--date", required=True, help="YYYY-MM-DD local-date filter")
    p.add_argument("--tz", required=True, help="IANA timezone, e.g. Europe/Warsaw")
    p.add_argument("--stats-out", default=None, help="Optional path for stats sidecar JSON")
    p.add_argument("--max-asst-chars", type=int, default=3000)
    p.add_argument("--debug", action="store_true")
    args = p.parse_args(argv)

    try:
        target_date = datetime.strptime(args.date, "%Y-%m-%d").date()
    except ValueError:
        print(f"horizon-extract: bad --date '{args.date}'", file=sys.stderr)
        return 2

    try:
        tz = ZoneInfo(args.tz)
    except Exception as e:
        print(f"horizon-extract: bad --tz '{args.tz}': {e}", file=sys.stderr)
        return 2

    drop_counter: Counter = Counter()
    raw_total = 0
    out_total = 0
    sessions: list[Path] = []
    for s in args.session:
        path = Path(s)
        if not path.is_file():
            print(f"horizon-extract: unreadable session {path}", file=sys.stderr)
            return 2
        sessions.append(path)
        try:
            raw_total += path.stat().st_size
        except OSError:
            pass

    # Stream all sessions, collapse corrections across the whole stream.
    def all_messages():
        for path in sessions:
            yield from iter_session(path, target_date, tz, args.max_asst_chars, drop_counter)

    emitted_any = False
    for ts, role, text in collapse_corrections(all_messages()):
        header = f"[{ts.isoformat()} | {role}]\n"
        body = text.rstrip() + "\n\n"
        sys.stdout.write(header)
        sys.stdout.write(body)
        out_total += len(header) + len(body)
        emitted_any = True

    if args.debug:
        ratio = (1 - out_total / raw_total) if raw_total else 0
        print(f"horizon-extract: raw={raw_total} extracted={out_total} reduction={ratio:.2%}",
              file=sys.stderr)
        top5 = drop_counter.most_common(5)
        print(f"horizon-extract: top-5 dropped: {top5}", file=sys.stderr)

    if not emitted_any:
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
