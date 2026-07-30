#!/bin/bash
# Claude Code compact statusline (SINGLE-LINE LAYOUT)
# Reads JSON from stdin (piped by Claude Code)
#
# Layout:
#   5h 12% ~2h14m  7d 45% ~3d5h  $0.42  Opus 5  xhigh  52%  1M  owner/repo  main*  #3
#
# Progressive hiding: when terminal is narrow, drops segments to leave room
# for Claude Code system notifications. Drop order: repo, cost, effort.
#
# Brightness-coded values: dim at low usage, brighter as they climb,
# yellow >90%, red at 100%. Text indicators: !! warning, XX exhausted.
#
# Data source: Claude Code statusline input JSON.
#   rate_limits                                      v2.1.80+
#   effort, pr, workspace.repo, exceeds_200k_tokens  v2.1.2xx
#
# Perf: the payload is parsed in ONE jq call and git state comes from ONE
# `git status -b` call. Segment widths are tracked as plain-text twins while the
# coloured strings are built, so measuring the line costs no subprocess.
# Keep it that way - this runs on every render.
#
# Targets bash 3.2 (what /bin/bash is on macOS): no EPOCHSECONDS, no ${x,,},
# no associative arrays.
#
# Derived from the `statusline-compact` plugin in Tribe-Coding/claude-plugins,
# MIT License, Copyright (c) 2025 Tribe Coding.
# https://github.com/Tribe-Coding/claude-plugins

input=$(cat)

# ANSI colors
rst=$(printf '\033[0m')
dim=$(printf '\033[38;5;242m')
very_dim=$(printf '\033[38;5;237m')
bright_red=$(printf '\033[38;5;167m')
yellow=$(printf '\033[38;5;178m')
green=$(printf '\033[38;5;108m')

DOLLAR='$'

# Brightness gradient for percentage values
# Low usage fades into background, high usage draws attention
pct_color() {
  local val=$1
  if [ "$val" -ge 100 ] 2>/dev/null; then
    printf '\033[38;5;167m'    # red - exhausted
  elif [ "$val" -gt 90 ] 2>/dev/null; then
    printf '\033[38;5;178m'    # yellow - warning
  elif [ "$val" -ge 60 ] 2>/dev/null; then
    printf '\033[0m'           # default - notable
  elif [ "$val" -ge 30 ] 2>/dev/null; then
    printf '\033[38;5;246m'    # light dim - moderate
  else
    printf '\033[38;5;240m'    # dim - low, fade out
  fi
}

# Format time remaining from epoch seconds. Reads $now from the caller so the
# common path costs zero `date` subprocesses.
format_time_remaining() {
  local reset_epoch="$1"
  local threshold_hours="$2"
  if [ -z "$reset_epoch" ]; then
    echo ""
    return
  fi
  local diff=$(( reset_epoch - now ))
  if [ "$diff" -le 0 ]; then
    echo "now"
    return
  fi
  local days=$(( diff / 86400 ))
  local hours=$(( (diff % 86400) / 3600 ))
  local mins=$(( (diff % 3600) / 60 ))

  local total_hours=$(( days * 24 + hours ))

  if [ "$total_hours" -ge "$threshold_hours" ]; then
    if [ "$days" -gt 0 ]; then
      if [ "$hours" -ge 12 ]; then
        days=$(( days + 1 ))
      fi
      echo "~${days}d"
    else
      if [ "$mins" -ge 30 ]; then
        hours=$(( hours + 1 ))
      fi
      echo "~${hours}h"
    fi
  else
    if [ "$days" -gt 0 ]; then
      echo "${days}d${hours}h"
    elif [ "$hours" -gt 0 ]; then
      echo "${hours}h${mins}m"
    else
      echo "${mins}m"
    fi
  fi
}

# Apply dim to time units (~, h, m, d)
dim_time_units() {
  local remaining="$1"
  local result=""
  local i char
  for ((i=0; i<${#remaining}; i++)); do
    char="${remaining:$i:1}"
    case "$char" in
      '~'|h|m|d) result="${result}${dim}${char}${rst}" ;;
      *) result="${result}${char}" ;;
    esac
  done
  echo -n "$result"
}

# ===== PAYLOAD: one jq pass, fixed field order =====
# `// ""` keeps positions stable for absent fields. A genuine 0 survives, since
# jq only treats null and false as falsy.
#
# Every line is prefixed with a sentinel "|" that the read loop strips. Without
# it, a payload whose last fields are all absent (no pr, no repo) would end in
# blank lines, and command substitution strips trailing newlines - the tail
# fields would silently vanish and the arity guard below would reject a payload
# that was in fact fine.
JQ_FIELDS='[
  (.workspace.current_dir // ""),
  (.model.display_name // ""),
  (.context_window.used_percentage // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.rate_limits.seven_day.resets_at // ""),
  (.cost.total_cost_usd // ""),
  (.effort.level // ""),
  (.pr.number // ""),
  (.pr.review_state // ""),
  (if .exceeds_200k_tokens then "1" else "" end),
  (.workspace.repo.owner // ""),
  (.workspace.repo.name // "")
] | .[] | "|" + tostring'

f=()
while IFS= read -r _line; do
  f[${#f[@]}]="${_line#|}"
done <<< "$(printf '%s' "$input" | jq -r "$JQ_FIELDS" 2>/dev/null)"

# Bail quietly if jq failed or the payload was not what we expect
if [ "${#f[@]}" -lt 14 ]; then
  exit 0
fi

cwd="${f[0]}"
model="${f[1]}"
used_pct="${f[2]}"
five_hour_pct="${f[3]}"
five_hour_resets="${f[4]}"
seven_day_pct="${f[5]}"
seven_day_resets="${f[6]}"
session_cost_usd="${f[7]}"
effort_level="${f[8]}"
pr_number="${f[9]}"
pr_review_state="${f[10]}"
exceeds_200k="${f[11]}"
repo_owner="${f[12]}"
repo_name="${f[13]}"

# ===== GIT: one call yields branch + dirty =====
# `status -b --porcelain=v1` prints the branch header first, then one line per
# change. Two facts, one fork.
branch=""
dirty=""
git_out=$(git -C "$cwd" status --porcelain=v1 -b --untracked-files=normal 2>/dev/null)
if [ $? -eq 0 ] && [ -n "$git_out" ]; then
  first_line="${git_out%%$'\n'*}"
  hdr="${first_line#\#\# }"
  case "$hdr" in
    "No commits yet on "*) branch="${hdr#No commits yet on }" ;;
    *"(no branch)"*)       branch="" ;;
    *)                     branch="${hdr%%...*}" ;;
  esac
  # Anything beyond the header line means the worktree is dirty
  if [ "$git_out" != "$first_line" ]; then
    dirty="true"
  fi
fi

# `date` is only needed when a reset countdown will actually render (>=60%)
now=0
five_int="${five_hour_pct%.*}"
seven_int="${seven_day_pct%.*}"
if [ "${five_int:-0}" -ge 60 ] 2>/dev/null || [ "${seven_int:-0}" -ge 60 ] 2>/dev/null; then
  now=$(date +%s)
fi

# ===== BUILD SEGMENTS =====
# SEG[] holds the coloured string, PLAIN[] its printable twin (used for width).
SEG=()
PLAIN=()

set_seg() { # index, colored, plain
  SEG[$1]="$2"
  PLAIN[$1]="$3"
}

I_5H=0; I_7D=1; I_COST=2; I_MODEL=3; I_EFFORT=4
I_CTX=5; I_1M=6; I_REPO=7; I_BRANCH=8; I_PR=9

for i in 0 1 2 3 4 5 6 7 8 9; do SEG[$i]=""; PLAIN[$i]=""; done

# --- 5h / 7d rate limit segments ---
build_limit_seg() { # index, label, pct, resets_at, threshold_hours
  local idx="$1" label="$2" pct="$3" resets="$4" threshold="$5"
  [ -z "$pct" ] && return
  local int="${pct%.*}"
  local color suffix_c suffix_p time_c time_p remaining

  color=$(pct_color "$int")
  suffix_c=""; suffix_p=""
  if [ "$int" -ge 100 ] 2>/dev/null; then
    suffix_c=" ${bright_red}XX${rst}"; suffix_p=" XX"
  elif [ "$int" -gt 90 ] 2>/dev/null; then
    suffix_c=" ${yellow}!!${rst}"; suffix_p=" !!"
  fi

  time_c=""; time_p=""
  if [ "$int" -ge 60 ] 2>/dev/null; then
    remaining=$(format_time_remaining "$resets" "$threshold")
    if [ -n "$remaining" ]; then
      time_c=" $(dim_time_units "$remaining")"
      time_p=" $remaining"
    fi
  fi

  set_seg "$idx" \
    "${dim}${label}${rst} ${color}${int}%${rst}${time_c}${suffix_c}" \
    "${label} ${int}%${time_p}${suffix_p}"
}

build_limit_seg "$I_5H" "5h" "$five_hour_pct" "$five_hour_resets" 2
build_limit_seg "$I_7D" "7d" "$seven_day_pct" "$seven_day_resets" 48

# --- Session cost: "$0.42" ---
if [ -n "$session_cost_usd" ]; then
  # printf emits the locale's decimal separator, so split on either form
  cost_fmt=""
  printf -v cost_fmt "%.2f" "$session_cost_usd" 2>/dev/null
  if [ -n "$cost_fmt" ]; then
    cost_int="${cost_fmt%[.,]*}"
    cost_frac="${cost_fmt#$cost_int}"
    set_seg "$I_COST" \
      "${dim}${DOLLAR}${rst}${cost_int}${dim}${cost_frac}${rst}" \
      "${DOLLAR}${cost_fmt}"
  fi
fi

# --- Model: strip "Claude " prefix and parenthetical suffix (e.g. "(1M context)") ---
# Brightness = capability tier: Opus bright, Sonnet default, Haiku dim.
model_plain="${model#Claude }"
model_plain="${model_plain%% (*)}"
case "$model_plain" in
  *[Oo]pus*)   tier_color=$(printf '\033[1;97m');     tier_word="Opus" ;;
  *[Ff]able*)  tier_color=$(printf '\033[1;97m');     tier_word="Fable" ;;
  *[Ss]onnet*) tier_color=$(printf '\033[38;5;252m'); tier_word="Sonnet" ;;
  *[Hh]aiku*)  tier_color=$(printf '\033[38;5;245m'); tier_word="Haiku" ;;
  *)           tier_color="";                         tier_word="" ;;
esac
model_colored="$model_plain"
if [ -n "$tier_word" ]; then
  model_colored="${model_plain//$tier_word/${tier_color}${tier_word}${rst}}"
fi
# Dim a dotted version number ("4.5"); a bare major ("5") is left alone
if [[ "$model_plain" =~ ([0-9]+\.[0-9]+) ]]; then
  ver="${BASH_REMATCH[1]}"
  model_colored="${model_colored//$ver/${dim}${ver}${rst}}"
fi
set_seg "$I_MODEL" "$model_colored" "$model_plain"

# --- Effort level ---
# Shown only when it deviates from "medium". Claude Code resolves effort from
# --effort > ultracode > settings.effortLevel with no single published default,
# so "medium" is treated as the neutral middle and stays hidden.
case "$effort_level" in
  ""|medium) ;;
  low)       set_seg "$I_EFFORT" "${very_dim}low${rst}" "low" ;;
  high)      set_seg "$I_EFFORT" "${dim}high${rst}" "high" ;;
  xhigh|max) set_seg "$I_EFFORT" "${yellow}${effort_level}${rst}" "$effort_level" ;;
  *)         set_seg "$I_EFFORT" "${dim}${effort_level}${rst}" "$effort_level" ;;
esac

# --- Context: bare percentage (distinguishable from 5h/7d by lack of prefix) ---
if [ -n "$used_pct" ]; then
  context_int="${used_pct%.*}"
  ctx_c=$(pct_color "$context_int")
  ctx_colored="${ctx_c}${used_pct}%${rst}"
  ctx_plain="${used_pct}%"
  if [ "$context_int" -ge 80 ] 2>/dev/null; then
    ctx_colored="${ctx_colored} ${bright_red}!!${rst}"
    ctx_plain="${ctx_plain} !!"
  fi
  set_seg "$I_CTX" "$ctx_colored" "$ctx_plain"
fi

# --- 1M marker: session crossed 200k, so the 1M-context model variant is live ---
if [ -n "$exceeds_200k" ]; then
  set_seg "$I_1M" "${dim}1M${rst}" "1M"
fi

# --- Repo: owner/name from the origin remote, else the cwd basename ---
if [ -n "$repo_owner" ] && [ -n "$repo_name" ]; then
  set_seg "$I_REPO" "${dim}${repo_owner}/${rst}${repo_name}" "${repo_owner}/${repo_name}"
elif [ -n "$cwd" ]; then
  short_dir="${cwd##*/}"
  set_seg "$I_REPO" "${short_dir}${dim}/${rst}" "${short_dir}/"
fi

# --- Branch: "main" or "main*" (yellow if dirty) ---
# Truncate long branches: "chore/statusline-compact-model-label" -> "chore/sta..label"
MAX_BRANCH=20
if [ -n "$branch" ]; then
  display_branch="$branch"
  if [ "${#branch}" -gt "$MAX_BRANCH" ]; then
    prefix="${branch%%/*}"
    suffix="${branch##*/}"
    if [ "$prefix" != "$branch" ]; then
      # Has a prefix/ - truncate the description part
      budget=$(( MAX_BRANCH - ${#prefix} - 1 - 2 ))  # -1 for /, -2 for ..
      if [ "$budget" -gt 4 ]; then
        keep_start=$(( budget / 2 ))
        keep_end=$(( budget - keep_start ))
        display_branch="${prefix}/${suffix:0:$keep_start}..${suffix: -$keep_end}"
      else
        display_branch="${branch:0:$(( MAX_BRANCH - 2 ))}.."
      fi
    else
      display_branch="${branch:0:$(( MAX_BRANCH - 2 ))}.."
    fi
  fi
  if [ -n "$dirty" ]; then
    set_seg "$I_BRANCH" "${yellow}${display_branch}*${rst}" "${display_branch}*"
  else
    set_seg "$I_BRANCH" "${display_branch}" "${display_branch}"
  fi
fi

# --- PR badge for the current branch, coloured by review state ---
if [ -n "$pr_number" ]; then
  case "$pr_review_state" in
    approved)          pr_color="$green" ;;
    changes_requested) pr_color="$bright_red" ;;
    draft)             pr_color="$very_dim" ;;
    *)                 pr_color="$dim" ;;
  esac
  set_seg "$I_PR" "${pr_color}#${pr_number}${rst}" "#${pr_number}"
fi

# ===== ASSEMBLE =====
# Joins the given segment indices with 2-space gaps, tracking visual width from
# the PLAIN twins so no sed/wc subprocess is needed.
JOINED=""
JOINED_W=0
join_idx() {
  local i
  JOINED=""
  JOINED_W=0
  for i in "$@"; do
    [ -z "${PLAIN[$i]}" ] && continue
    if [ -n "$JOINED" ]; then
      JOINED="${JOINED}  ${SEG[$i]}"
      JOINED_W=$(( JOINED_W + 2 + ${#PLAIN[$i]} ))
    else
      JOINED="${SEG[$i]}"
      JOINED_W=${#PLAIN[$i]}
    fi
  done
}

# ===== PROGRESSIVE HIDING =====
# Claude Code appends system notifications to the right of the last statusline
# line. Reserve: 0 because notifications are rare and the statusline is already
# tight.
NOTIFICATION_RESERVE=0

term_width=$(tput cols 2>/dev/null)
if ! [ "$term_width" -ge 40 ] 2>/dev/null; then
  term_width=""
fi

# Level 0: everything
join_idx $I_5H $I_7D $I_COST $I_MODEL $I_EFFORT $I_CTX $I_1M $I_REPO $I_BRANCH $I_PR

if [ -n "$term_width" ]; then
  available=$(( term_width - NOTIFICATION_RESERVE ))

  if [ "$JOINED_W" -gt "$available" ]; then
    # Level 1: drop repo
    join_idx $I_5H $I_7D $I_COST $I_MODEL $I_EFFORT $I_CTX $I_1M $I_BRANCH $I_PR
  fi
  if [ "$JOINED_W" -gt "$available" ]; then
    # Level 2: drop session cost
    join_idx $I_5H $I_7D $I_MODEL $I_EFFORT $I_CTX $I_1M $I_BRANCH $I_PR
  fi
  if [ "$JOINED_W" -gt "$available" ]; then
    # Level 3: drop effort
    join_idx $I_5H $I_7D $I_MODEL $I_CTX $I_1M $I_BRANCH $I_PR
  fi
fi

echo "$JOINED"
