#!/usr/bin/env python3
"""horizon-timesheet — defensible per-project active-time tracking from CC session logs.

Computes "active engaged time" per project over a date window by reading message
timestamps from Claude Code session JSONL files and summing the gaps between
consecutive messages, capping any idle gap above a threshold (default 5 min) so
that walking-away time and long agent runs don't inflate the bill.

This is a CONSERVATIVE floor on hands-on-CC time, suitable as the audit trail
behind an hourly invoice. It does NOT count off-CC work (calls, phone review,
thinking away from the keyboard).

Two numbers are reported per project:
  - active_h : sum of inter-message gaps, each capped at --cap minutes. The
               billable number. "Time at the keyboard, idle stretches removed."
  - union_h  : deduped wall-clock the project's sessions actually occupied
               (overlapping concurrent sessions counted once). Always <= the
               naive span-sum; equals active_h when the project's own sessions
               never overlapped each other. Use it to sanity-check that you are
               not double-counting one minute across two sessions of the SAME
               project.

Cross-project concurrency (billing two different clients for the same minute)
is NOT auto-resolved — that's a human judgment call. Use --project to isolate a
single client, and be honest that context-switching happened.

Usage:
  horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw [--project satori]
  horizon-timesheet.py --from 2026-06-01 --to 2026-06-07 --tz Europe/Warsaw
  horizon-timesheet.py --week 2026-W23 --tz Europe/Warsaw --format csv

Output formats: table (default, human), csv (machine/invoice), json.
Exit codes: 0 ok, 2 bad args, 3 future/empty window.
"""
from __future__ import annotations

import argparse
import csv
import glob
import io
import json
import os
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - py<3.9
    print("horizon-timesheet: requires Python 3.9+ (zoneinfo)", file=sys.stderr)
    sys.exit(2)

EXIT_OK = 0
EXIT_BAD_ARGS = 2
EXIT_EMPTY = 3

DEFAULT_PROJECTS_DIR = os.path.expanduser("~/.claude/projects")


# --- Window resolution -------------------------------------------------------


def week_window(week_label: str, tz: ZoneInfo) -> tuple[datetime, datetime, str]:
    """ISO week 'YYYY-Www' -> (start_utc, end_utc, label). Local Mon 00:00 .. next Mon 00:00."""
    try:
        y_str, w_str = week_label.upper().split("-W")
        year, week = int(y_str), int(w_str)
    except ValueError:
        raise ValueError(f"bad --week '{week_label}', expected YYYY-Www")
    monday = date.fromisocalendar(year, week, 1)
    return _local_span(monday, monday + timedelta(days=7), tz, week_label)


def from_to_window(from_str: str, to_str: str, tz: ZoneInfo) -> tuple[datetime, datetime, str]:
    """Inclusive --from / --to dates -> half-open [start, end+1day) in UTC."""
    try:
        start = date.fromisoformat(from_str)
        end = date.fromisoformat(to_str)
    except ValueError as e:
        raise ValueError(f"bad --from/--to: {e}")
    if end < start:
        raise ValueError("--to is before --from")
    label = f"{from_str}..{to_str}"
    return _local_span(start, end + timedelta(days=1), tz, label)


def _local_span(start_d: date, end_d: date, tz: ZoneInfo, label: str):
    start = datetime(start_d.year, start_d.month, start_d.day, tzinfo=tz).astimezone(timezone.utc)
    end = datetime(end_d.year, end_d.month, end_d.day, tzinfo=tz).astimezone(timezone.utc)
    return start, end, label


# --- Project labeling (mirrors horizon-collect.project_label_from_cwd) --------


def project_label_from_cwd(cwd: str) -> str:
    """Derive a short project label from a cwd path. Kept in sync with horizon-collect.py.

    Extended with the personal/ sub-project markers that horizon's coarser
    table folds into bare basenames, because billing wants them distinct.
    """
    if not cwd:
        return "unknown"
    cwd = cwd.rstrip("/")
    for marker, label in [
        ("/satori/", "satori"),
        ("/client-project/", "client"),
        ("/personal/earshot", "earshot"),
        ("/personal/pidcast", "pidcast"),
        ("/personal/open-call", "open-call"),
        ("/personal/movie-grants", "movie-grants"),
        ("/cc-tools", "cc-tools"),
        ("/puch", "puch"),
        ("/homelab", "homelab"),
        ("/finances", "finances"),
        ("/meds", "meds"),
        ("/music-agent", "music-agent"),
        ("/tribe-coding", "tribe-coding"),
        ("/job-hunt", "job-hunt"),
        ("/pm-workspace", "pm-workspace"),
        ("/dotfiles", "dotfiles"),
    ]:
        if marker in cwd:
            return label
    base = os.path.basename(cwd)
    if base in ("code", "Code"):
        return "global"
    return base or "unknown"


# --- Core computation --------------------------------------------------------


def session_cwd_and_timestamps(
    jsonl_path: str, start_utc: datetime, end_utc: datetime
) -> tuple[str | None, list[datetime]]:
    """Read a session file once: return its real cwd (from the first line that
    carries one) and the in-window message timestamps.

    The project DIR name (-Users-ostaps-code-foo-bar) is a lossy dash-encoding
    that cannot be reliably inverted — a literal hyphen in a path segment
    (open-call, movie-grants) is indistinguishable from a path separator. Each
    session line carries the verbatim ``cwd`` field, so we read that instead.
    """
    cwd: str | None = None
    out: list[datetime] = []
    try:
        with open(jsonl_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if cwd is None and obj.get("cwd"):
                    cwd = obj["cwd"]
                ts = obj.get("timestamp")
                if not ts:
                    continue
                try:
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                except ValueError:
                    continue
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
                if start_utc <= dt < end_utc:
                    out.append(dt)
    except OSError:
        return cwd, []
    out.sort()
    return cwd, out


def merged_union_seconds(intervals: list[tuple[float, float]]) -> float:
    """Total length of the union of [start,end) intervals (epoch seconds)."""
    if not intervals:
        return 0.0
    iv = sorted(intervals)
    total = 0.0
    cur_s, cur_e = iv[0]
    for s, e in iv[1:]:
        if s <= cur_e:
            cur_e = max(cur_e, e)
        else:
            total += cur_e - cur_s
            cur_s, cur_e = s, e
    total += cur_e - cur_s
    return total


def compute(start_utc: datetime, end_utc: datetime, cap_seconds: int,
            projects_dir: str, only_project: str | None) -> dict:
    active = defaultdict(float)
    sessions = defaultdict(set)
    msgs = defaultdict(int)
    intervals = defaultdict(list)  # project -> [(epoch_start, epoch_end)] capped sub-intervals

    for jf in glob.glob(os.path.join(projects_dir, "*", "*.jsonl")):
        cwd, ts = session_cwd_and_timestamps(jf, start_utc, end_utc)
        if not ts:
            continue
        label = project_label_from_cwd(cwd or "")
        if only_project and label != only_project:
            continue
        sessions[label].add(jf)
        msgs[label] += len(ts)
        for a, b in zip(ts, ts[1:]):
            gap = (b - a).total_seconds()
            capped = min(gap, cap_seconds)
            active[label] += capped
            intervals[label].append((a.timestamp(), a.timestamp() + capped))

    rows = []
    for label in active:
        rows.append({
            "project": label,
            "active_h": round(active[label] / 3600, 2),
            "union_h": round(merged_union_seconds(intervals[label]) / 3600, 2),
            "sessions": len(sessions[label]),
            "messages": msgs[label],
        })
    rows.sort(key=lambda r: -r["active_h"])
    return {"rows": rows, "cap_minutes": cap_seconds // 60}


# --- Rendering ---------------------------------------------------------------


def render_table(result: dict, label: str) -> str:
    rows = result["rows"]
    cap = result["cap_minutes"]
    lines = [f"Timesheet — {label}  (active = inter-msg gaps capped at {cap} min)", ""]
    lines.append(f"{'project':18} {'active_h':>9} {'union_h':>8} {'sess':>5} {'msgs':>6}")
    lines.append("-" * 50)
    tot_a = tot_u = 0.0
    for r in rows:
        tot_a += r["active_h"]
        tot_u += r["union_h"]
        lines.append(f"{r['project']:18} {r['active_h']:9.1f} {r['union_h']:8.1f} "
                     f"{r['sessions']:5} {r['messages']:6}")
    lines.append("-" * 50)
    lines.append(f"{'TOTAL':18} {tot_a:9.1f} {tot_u:8.1f}")
    lines.append("")
    lines.append("active_h = billable floor (hands-on-CC, idle removed).")
    lines.append("union_h  = deduped wall-clock; if it lags active_h the project's own")
    lines.append("           sessions overlapped — bill the smaller. Cross-project")
    lines.append("           concurrency is your call, not the script's.")
    return "\n".join(lines)


def render_csv(result: dict, label: str) -> str:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["window", "project", "active_hours", "union_hours",
                "sessions", "messages", "cap_minutes"])
    for r in result["rows"]:
        w.writerow([label, r["project"], r["active_h"], r["union_h"],
                    r["sessions"], r["messages"], result["cap_minutes"]])
    return buf.getvalue().rstrip("\n")


def render_json(result: dict, label: str) -> str:
    return json.dumps({"window": label, **result}, indent=2)


# --- Main --------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Per-project active-time timesheet from CC session logs.")
    p.add_argument("--week", default=None, help="ISO week YYYY-Www")
    p.add_argument("--from", dest="from_date", default=None, help="start date YYYY-MM-DD (with --to)")
    p.add_argument("--to", dest="to_date", default=None, help="end date YYYY-MM-DD inclusive")
    p.add_argument("--tz", required=True, help="IANA timezone, e.g. Europe/Warsaw")
    p.add_argument("--project", default=None, help="restrict to one project label (e.g. satori)")
    p.add_argument("--cap", type=int, default=5, help="idle-gap cap in minutes (default 5)")
    p.add_argument("--projects-dir", default=DEFAULT_PROJECTS_DIR)
    p.add_argument("--format", choices=["table", "csv", "json"], default="table")
    args = p.parse_args(argv)

    try:
        tz = ZoneInfo(args.tz)
    except Exception as e:
        print(f"horizon-timesheet: bad --tz '{args.tz}': {e}", file=sys.stderr)
        return EXIT_BAD_ARGS

    try:
        if args.week:
            start, end, label = week_window(args.week, tz)
        elif args.from_date and args.to_date:
            start, end, label = from_to_window(args.from_date, args.to_date, tz)
        else:
            print("horizon-timesheet: provide --week OR (--from and --to)", file=sys.stderr)
            return EXIT_BAD_ARGS
    except ValueError as e:
        print(f"horizon-timesheet: {e}", file=sys.stderr)
        return EXIT_BAD_ARGS

    now = datetime.now(timezone.utc)
    if start > now:
        print(f"horizon-timesheet: window {label} is in the future", file=sys.stderr)
        return EXIT_EMPTY

    result = compute(start, end, args.cap * 60, args.projects_dir, args.project)
    if not result["rows"]:
        print(f"horizon-timesheet: no session activity in {label}"
              + (f" for project '{args.project}'" if args.project else ""), file=sys.stderr)
        return EXIT_EMPTY

    renderer = {"table": render_table, "csv": render_csv, "json": render_json}[args.format]
    print(renderer(result, label))
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
