#!/bin/bash
# Shared helper for the plan-review gate. Sourced by plan-review-gate.sh,
# plan-review-clear.sh, and plan-review-checkpoint.sh so the marker path
# convention has a single source of truth and can never drift between the
# set / check / clear sides of the gate.
#
# A marker file at this path means: "a plan was accepted in this session but
# no fresh-context review has been resolved yet — the next code edit should
# prompt." Session-keyed so concurrent sessions never cross-block; lives in
# $TMPDIR (cleared on reboot) so staleness is self-limiting.

# Echo the marker path for a given session id. Returns non-zero (and echoes
# nothing) if the id is empty, so callers can guard on it.
plan_review_marker_path() {
  local sid="${1:-}"
  [[ -n "$sid" ]] || return 1
  # Strip anything that isn't a safe filename char, so a malformed id can never
  # escape the temp dir (path-traversal / injection guard).
  sid="${sid//[^A-Za-z0-9._-]/}"
  [[ -n "$sid" ]] || return 1
  local dir="${TMPDIR:-/tmp}"
  dir="${dir%/}"  # strip any trailing slash so the path has no double //
  printf '%s/cc-plan-review-pending-%s' "$dir" "$sid"
}

# Read a hook's stdin JSON (passed as $1) and echo its .session_id. Echoes
# nothing on any failure (no jq, malformed JSON, missing field). Never errors
# out the caller.
plan_review_session_id() {
  local raw="${1:-}"
  [[ -n "$raw" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  printf '%s' "$raw" | jq -r '.session_id // empty' 2>/dev/null || true
}
