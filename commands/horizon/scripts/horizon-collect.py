#!/usr/bin/env python3
"""
horizon-collect.py — hybrid collector for /horizon week.

For each of the 7 days in the window:
  - If a /retro daily summary exists and is newer than every session that day,
    reuse it (no re-extraction).
  - Else, locate sessions via retroscope's find-sessions.py, run
    horizon-extract.py for clean prose, aggregate stats via find-sessions.py --stats.
  - Else, emit an empty record.

See: commands/horizon/references/cli-contracts.md for the CLI contract.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import Counter
from datetime import date, datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

EXIT_OK = 0
EXIT_NO_RETROSCOPE = 2
EXIT_BAD_WEEK = 3
EXIT_NO_STORAGE = 4
EXIT_BAD_SESSION = 5

WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


# --- Week math ---------------------------------------------------------------


def week_from_arg(week_arg: str | None, from_arg: str | None, to_arg: str | None,
                  tz: ZoneInfo) -> tuple[date, date, str]:
    """Return (start_date, end_date, week_label). Raises ValueError on bad input."""
    if from_arg and to_arg:
        start = datetime.strptime(from_arg, "%Y-%m-%d").date()
        end = datetime.strptime(to_arg, "%Y-%m-%d").date()
        if end < start:
            raise ValueError("--to is before --from")
        iso = start.isocalendar()
        return start, end, f"{iso.year}-W{iso.week:02d}"

    if week_arg:
        # Parse YYYY-Www.
        try:
            year_str, week_str = week_arg.split("-W")
            year = int(year_str)
            week = int(week_str)
        except (ValueError, IndexError):
            raise ValueError(f"bad --week '{week_arg}', expected YYYY-Www")
        try:
            start = date.fromisocalendar(year, week, 1)  # Monday
        except ValueError as e:
            raise ValueError(f"bad ISO week {week_arg}: {e}")
        end = start + timedelta(days=6)
        return start, end, f"{year}-W{week:02d}"

    # Default: current ISO week in tz.
    now_local = datetime.now(tz).date()
    iso = now_local.isocalendar()
    start = date.fromisocalendar(iso.year, iso.week, 1)
    end = start + timedelta(days=6)
    return start, end, f"{iso.year}-W{iso.week:02d}"


def reject_future_week(start: date, tz: ZoneInfo) -> None:
    today_local = datetime.now(tz).date()
    if start > today_local:
        raise ValueError(f"future week ({start} is after today {today_local} in {tz})")


# --- Retroscope script resolution -------------------------------------------


RETROSCOPE_CANDIDATES = [
    Path.home() / ".claude/plugins/marketplaces/tribe-coding/plugins/retroscope/scripts/find-sessions.py",
    Path.home() / "code/tribe-coding/claude-plugins/plugins/retroscope/scripts/find-sessions.py",
]


def resolve_retroscope(explicit: str | None) -> Path | None:
    if explicit:
        p = Path(explicit).expanduser()
        return p if p.is_file() and os.access(p, os.X_OK) else None
    env = os.environ.get("RETROSCOPE_SCRIPT")
    if env:
        p = Path(env).expanduser()
        if p.is_file() and os.access(p, os.X_OK):
            return p
    for cand in RETROSCOPE_CANDIDATES:
        if cand.is_file() and os.access(cand, os.X_OK):
            return cand
    return None


# --- Session listing ---------------------------------------------------------


def list_sessions_for_date(retroscope: Path, day: date, scope: str, tz: str,
                            project_dir: str | None) -> list[tuple[str, Path]]:
    """Return list of (project_label, jsonl_path) for the given day."""
    date_str = day.isoformat()
    cmd = ["python3", str(retroscope), date_str, "--tz", tz]
    if scope == "all":
        cmd.append("--all-projects")
    elif project_dir:
        cmd.extend(["--project-dir", project_dir])
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return []
    if result.returncode != 0:
        return []
    out: list[tuple[str, Path]] = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if "\t" in line:
            project, path_str = line.split("\t", 1)
        else:
            project, path_str = "default", line
        out.append((project, Path(path_str)))
    return out


def get_session_stats(retroscope: Path, session_path: Path) -> dict:
    cmd = ["python3", str(retroscope), "--stats", str(session_path)]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return {}
    if result.returncode != 0 or not result.stdout.strip():
        return {}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {}


# --- Stats aggregation -------------------------------------------------------


def zero_stats() -> dict:
    return {
        "session_count": 0,
        "cwd_list": [],
        "branches": [],
        "models": [],
        "time_range": {"duration_minutes": 0},
        "token_usage": {
            "input_tokens": 0, "output_tokens": 0,
            "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0,
        },
        "tool_counts": {},
        "estimated_cost_usd": 0.0,
        "naive_cost_usd": 0.0,
    }


def aggregate_stats(stats_blocks: list[dict]) -> dict:
    """Aggregate either per-session or per-day stats blocks.

    Per-session blocks have `cwd` (string) and no `session_count`. Per-day
    blocks have `cwd_list` (array) and `session_count`. Handle both so the
    same function works for day → week roll-up.
    """
    out = zero_stats()
    cwds: set[str] = set()
    branches: set[str] = set()
    models: set[str] = set()
    duration = 0.0
    tu = Counter()
    tc = Counter()
    cost_actual = 0.0
    cost_naive = 0.0
    count = 0
    for s in stats_blocks:
        if not s:
            continue
        # Per-session blocks lack session_count; per-day blocks already have it.
        if "session_count" in s:
            count += int(s.get("session_count") or 0)
        else:
            count += 1
        if s.get("cwd"):
            cwds.add(s["cwd"])
        for c in s.get("cwd_list", []) or []:
            cwds.add(c)
        for b in s.get("branches", []) or []:
            branches.add(b)
        for m in s.get("models", []) or []:
            models.add(m)
        dur = ((s.get("time_range") or {}).get("duration_minutes")) or 0
        try:
            duration += float(dur)
        except (TypeError, ValueError):
            pass
        for k, v in (s.get("token_usage") or {}).items():
            try:
                tu[k] += int(v or 0)
            except (TypeError, ValueError):
                pass
        for k, v in (s.get("tool_counts") or {}).items():
            try:
                tc[k] += int(v or 0)
            except (TypeError, ValueError):
                pass
        try:
            cost_actual += float(s.get("estimated_cost_usd") or 0)
        except (TypeError, ValueError):
            pass
        try:
            cost_naive += float(s.get("naive_cost_usd") or 0)
        except (TypeError, ValueError):
            pass
    out["session_count"] = count
    out["cwd_list"] = sorted(cwds)
    out["branches"] = sorted(branches)
    out["models"] = sorted(models)
    out["time_range"]["duration_minutes"] = round(duration, 1)
    out["token_usage"] = dict(tu)
    out["tool_counts"] = dict(tc)
    out["estimated_cost_usd"] = round(cost_actual, 4)
    out["naive_cost_usd"] = round(cost_naive, 4)
    return out


def merge_week_stats(per_day: list[dict]) -> dict:
    return aggregate_stats(per_day)


# --- Daily summary lookup ----------------------------------------------------


def daily_summary_path(storage_dir: Path, scope: str, project: str, day: date) -> Path:
    bucket = "_cross-project" if scope == "all" else project
    return storage_dir / "reports" / bucket / "daily" / f"{day.year:04d}" / f"{day.month:02d}" / f"{day.day:02d}" / "summary.md"


def cached_daily_is_fresh(summary: Path, sessions: list[Path]) -> bool:
    if not summary.is_file():
        return False
    try:
        summary_mtime = summary.stat().st_mtime
    except OSError:
        return False
    if not sessions:
        return True
    try:
        newest_session = max(s.stat().st_mtime for s in sessions if s.is_file())
    except (OSError, ValueError):
        return False
    return summary_mtime > newest_session


# --- Per-day chunking --------------------------------------------------------


# Split a day's prose at turn boundaries when it exceeds max_bytes. Turn
# boundaries are blank lines between two `[YYYY-...T... | role]` headers,
# matching horizon-extract.py's output format. Splitting at headers ensures
# the bulk LLM never sees a half-truncated message.

_TURN_HEADER_RE = re.compile(r"^\[\d{4}-\d{2}-\d{2}T", re.MULTILINE)


def write_day_with_parts(prose_path: Path, prose: str, max_bytes: int,
                          debug: bool = False) -> list[str]:
    """Write a day's prose to prose_path; also write part files if oversized.

    Returns a list of basenames (relative to prose_path's parent) that the
    orchestrator should fan out over. For under-threshold days that's just
    [prose_path.name]; for oversized days it includes the part files but NOT
    the master (the master stays for debug/idempotency only).
    """
    prose_path.write_text(prose, encoding="utf-8")
    parent = prose_path.parent
    stem = prose_path.stem  # e.g. "day-3"

    parts = split_prose_at_turns(prose, max_bytes)
    if len(parts) <= 1:
        return [prose_path.name]

    part_names: list[str] = []
    for idx, body in enumerate(parts):
        part_path = parent / f"{stem}-part-{idx}.txt"
        part_path.write_text(body, encoding="utf-8")
        part_names.append(part_path.name)
    if debug:
        sizes = [len(p.encode("utf-8")) for p in parts]
        print(f"horizon-collect: split {prose_path.name} into {len(parts)} parts ({sizes} bytes)",
              file=sys.stderr)
    return part_names


def split_prose_at_turns(prose: str, max_bytes: int) -> list[str]:
    """Split prose into parts of ≤max_bytes (UTF-8), respecting turn boundaries.

    Returns a single-element list when prose is already within budget. Each
    part starts at a `[timestamp | role]` header so the bulk LLM never sees a
    mid-message cut.
    """
    if len(prose.encode("utf-8")) <= max_bytes:
        return [prose]

    starts = [m.start() for m in _TURN_HEADER_RE.finditer(prose)]
    if not starts:
        return [prose[i:i + max_bytes] for i in range(0, len(prose), max_bytes)]

    # Treat the prose as a sequence of turn-chunks: [start_i, start_{i+1}).
    boundaries = starts + [len(prose)]
    turns: list[tuple[int, int]] = list(zip(boundaries[:-1], boundaries[1:]))

    parts: list[str] = []
    part_start = boundaries[0]
    part_bytes = 0
    for start, end in turns:
        turn_bytes = len(prose[start:end].encode("utf-8"))
        # If adding this turn would exceed budget AND the current part has
        # content, close the current part and start a new one at this turn.
        if part_bytes > 0 and (part_bytes + turn_bytes) > max_bytes:
            parts.append(prose[part_start:start])
            part_start = start
            part_bytes = 0
        part_bytes += turn_bytes

    # Flush the tail.
    if part_start < len(prose):
        parts.append(prose[part_start:])
    return parts


# --- Project label derivation ------------------------------------------------


def project_label_from_cwd(cwd: str) -> str:
    """Derive a short project label from a cwd path. Mirrors the table in output-template.md."""
    if not cwd:
        return "unknown"
    cwd = cwd.rstrip("/")
    for marker, label in [
        ("/satori/", "satori"),
        ("/client-project/", "client"),
        ("/cc-tools", "cc-tools"),
        ("/puch", "puch"),
        ("/homelab", "homelab"),
        ("/finances", "finances"),
        ("/meds", "meds"),
        ("/music-agent", "music-agent"),
        ("/tribe-coding", "tribe-coding"),
        ("/dotfiles", "dotfiles"),
    ]:
        if marker in cwd:
            return label
    base = os.path.basename(cwd)
    if base in ("code", "Code"):
        return "global"
    return base or "unknown"


# --- Main --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Hybrid collector for /horizon week.")
    p.add_argument("--week", default=None)
    p.add_argument("--from", dest="from_date", default=None)
    p.add_argument("--to", dest="to_date", default=None)
    p.add_argument("--scope", default="project", choices=["project", "all"])
    p.add_argument("--project-dir", default=None)
    p.add_argument("--tz", required=True)
    p.add_argument("--storage-dir", required=True)
    p.add_argument("--retroscope-script", default=None)
    p.add_argument("--out-dir", default=None)
    p.add_argument("--max-day-bytes", type=int, default=200_000,
                   help="Split per-day prose into parts when it exceeds this many UTF-8 bytes (default: 200000 ≈ 50K tokens)")
    p.add_argument("--debug", action="store_true")
    args = p.parse_args(argv)

    try:
        tz = ZoneInfo(args.tz)
    except Exception as e:
        print(f"horizon-collect: bad --tz '{args.tz}': {e}", file=sys.stderr)
        return EXIT_BAD_WEEK

    try:
        start, end, week_label = week_from_arg(args.week, args.from_date, args.to_date, tz)
        reject_future_week(start, tz)
    except ValueError as e:
        print(f"horizon-collect: {e}", file=sys.stderr)
        return EXIT_BAD_WEEK

    storage_dir = Path(args.storage_dir).expanduser()
    if not storage_dir.is_dir():
        print(f"horizon-collect: storageDir not a directory: {storage_dir}", file=sys.stderr)
        return EXIT_NO_STORAGE

    retroscope = resolve_retroscope(args.retroscope_script)
    if retroscope is None:
        print("horizon-collect: find-sessions.py not found (install retroscope)", file=sys.stderr)
        return EXIT_NO_RETROSCOPE
    if args.debug:
        print(f"horizon-collect: retroscope={retroscope}", file=sys.stderr)
        print(f"horizon-collect: week={week_label} {start}..{end} scope={args.scope} tz={args.tz}",
              file=sys.stderr)

    out_dir = Path(args.out_dir) if args.out_dir else Path(tempfile.mkdtemp(prefix=f"horizon-{week_label}-"))
    out_dir.mkdir(parents=True, exist_ok=True)

    extractor = Path(__file__).resolve().parent / "horizon-extract.py"
    if not extractor.is_file():
        print(f"horizon-collect: extractor missing at {extractor}", file=sys.stderr)
        return EXIT_NO_RETROSCOPE  # treat as install error

    manifest_days = []
    week_stats_blocks: list[dict] = []
    bad_session_seen = False

    for offset in range(7):
        day = start + timedelta(days=offset)
        if day > end:
            break
        weekday = WEEKDAYS[day.weekday()]
        prose_path = out_dir / f"day-{offset}.txt"
        stats_path = out_dir / f"day-{offset}.stats.json"

        sessions = list_sessions_for_date(retroscope, day, args.scope, args.tz, args.project_dir)
        session_paths = [path for _, path in sessions]

        # Determine the "project" label for daily-summary lookup (used in scope=project).
        # When scope=all, daily summaries live under _cross-project regardless.
        project_label = (
            project_label_from_cwd(args.project_dir or os.getcwd())
            if args.scope == "project" else "_cross-project"
        )
        cached_summary = daily_summary_path(storage_dir, args.scope, project_label, day)

        if cached_daily_is_fresh(cached_summary, session_paths):
            # Reuse cached daily summary.
            try:
                summary_text = cached_summary.read_text(encoding="utf-8")
            except OSError as e:
                print(f"horizon-collect: read daily summary failed for {day}: {e}", file=sys.stderr)
                bad_session_seen = True
                continue
            parts = write_day_with_parts(prose_path, summary_text, args.max_day_bytes, args.debug)
            # Reaggregate stats from the underlying sessions (cheap; gives consistent numbers).
            stats_blocks = [get_session_stats(retroscope, p) for p in session_paths]
            day_stats = aggregate_stats(stats_blocks)
            stats_path.write_text(json.dumps(day_stats, indent=2), encoding="utf-8")
            week_stats_blocks.append(day_stats)
            manifest_days.append({
                "date": day.isoformat(), "weekday": weekday,
                "source": "daily", "summary_path": str(cached_summary),
                "session_count": len(session_paths),
                "parts": parts,
            })
            continue

        if not session_paths:
            prose_path.write_text("", encoding="utf-8")
            stats_path.write_text(json.dumps(zero_stats(), indent=2), encoding="utf-8")
            week_stats_blocks.append(zero_stats())
            manifest_days.append({
                "date": day.isoformat(), "weekday": weekday,
                "source": "empty", "session_files": [],
                "parts": [],
            })
            continue

        # Build prose by running the extractor; one extractor call per project group
        # so we can insert project-marker headers between groups.
        by_project: dict[str, list[Path]] = {}
        for project, path in sessions:
            by_project.setdefault(project or "default", []).append(path)

        prose_chunks: list[str] = []
        stats_blocks: list[dict] = []
        for project, paths in by_project.items():
            short = ",".join(p.stem[:8] for p in paths)
            prose_chunks.append(f"\n\n### {project} — sessions {short}\n\n")
            cmd = [
                "python3", str(extractor),
                "--date", day.isoformat(),
                "--tz", args.tz,
                "--max-asst-chars", "3000",
            ]
            for path in paths:
                cmd.extend(["--session", str(path)])
            if args.debug:
                cmd.append("--debug")
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            except FileNotFoundError:
                print(f"horizon-collect: extractor not invokable: {extractor}", file=sys.stderr)
                return EXIT_NO_RETROSCOPE
            if result.returncode not in (0, 3):
                print(f"horizon-collect: extractor failed for {day} ({project}): rc={result.returncode}",
                      file=sys.stderr)
                if result.stderr:
                    print(result.stderr, file=sys.stderr)
                bad_session_seen = True
            else:
                prose_chunks.append(result.stdout)
                if args.debug and result.stderr:
                    sys.stderr.write(result.stderr)
            # Stats from upstream per-session.
            for path in paths:
                stats_blocks.append(get_session_stats(retroscope, path))

        parts = write_day_with_parts(prose_path, "".join(prose_chunks),
                                       args.max_day_bytes, args.debug)
        day_stats = aggregate_stats(stats_blocks)
        stats_path.write_text(json.dumps(day_stats, indent=2), encoding="utf-8")
        week_stats_blocks.append(day_stats)
        manifest_days.append({
            "date": day.isoformat(), "weekday": weekday,
            "source": "raw", "session_files": [str(p) for p in session_paths],
            "parts": parts,
        })

    # Week-level aggregation.
    week_stats = merge_week_stats(week_stats_blocks)
    (out_dir / "week-stats.json").write_text(json.dumps(week_stats, indent=2), encoding="utf-8")
    (out_dir / "manifest.json").write_text(json.dumps({
        "week": week_label,
        "from": start.isoformat(),
        "to": end.isoformat(),
        "scope": args.scope,
        "tz": args.tz,
        "storage_dir": str(storage_dir),
        "days": manifest_days,
    }, indent=2), encoding="utf-8")

    print(str(out_dir))
    return EXIT_BAD_SESSION if bad_session_seen else EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
