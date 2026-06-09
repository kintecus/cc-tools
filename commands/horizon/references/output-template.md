# Output template — weekly retro

The Markdown template the Stage 4 synthesis renders into. Frontmatter is
parsed by Obsidian; the `<!-- horizon-metrics:… -->` HTML comment is for
future tooling (e.g. month/quarter aggregators).

```markdown
---
date: {sunday-of-week-YYYY-MM-DD}
week: {YYYY-Www}
range: "{Mon-date} – {Sun-date}"
project: {project-basename or _cross-project}
horizon: weekly
model: {sonnet | opus}
generated: {ISO-8601 timestamp}
---

# Weekly retro: {YYYY-Www} ({Mon-date} – {Sun-date})

## Themes
{3-5 narrative bullets. What was this week actually about, beneath the activity?}

## Shipped vs stalled
- **Shipped:**
  - {concrete outcome}
- **Stalled:**
  - {started but didn't land + likely reason — user-bottlenecked items only}
- **Waiting on others:** (optional — only include if non-empty)
  - {item ready on user side, blocked on a counterparty: client reply,
     interview confirmation, vendor support, etc.}

## Tangents and yak-shaves
{Unplanned work, scope creep. Honest, not punitive. Naming a tangent here
beats pretending it was on plan.}

## Decisions
- {tech, project, or personal choice worth remembering}

## Open loops
- [ ] {item that carries into next week, with one-line context}

## Timesheet
{Optional — omit the whole section if --no-timesheet. Defensible per-project
active engaged time for hourly billing. Render the rows verbatim from the
timesheet JSON; do not round or re-derive.}

| Project | Billable (active_h) | Sessions |
| --- | --- | --- |
| {project} | {active_h}h | {n} |

- **Method:** active = sum of inter-message gaps, idle stretches > 5 min
  dropped. A conservative floor on hands-on-CC time.
- **Not billable as-is:** excludes off-CC work (calls, phone, thinking away
  from keyboard); counts long agent runs as user time (upper bound — the
  `--cap 10` variant is the looser bound). Cross-project concurrency (two
  clients in one minute) is a human judgment call, not resolved here.

## Footer
- **Hours:** {Xh Ym} across {N} sessions
- **Cost:** ${actual} actual / ${naive} naive ({sonnet | opus})
- **Projects:** [[A]] ({Xh}), [[B]] ({Yh})
- **Top tools:** Bash ({n}), Read ({n}), Edit ({n})

<!-- horizon-metrics:{"hours_total":H,"cost_actual":X.XX,"cost_naive":Y.YY,"sessions":N,"projects":{"a":Ha,"b":Hb},"top_tools":{"Bash":n,"Read":n},"timesheet":{"a":active_h_a,"b":active_h_b}} -->
```

## Section semantics

- **Themes** — what was this week about, named in 3-5 narrative beats. Not
  "I did X then Y"; closer to "shipping is competing with research because…".
- **Shipped vs stalled vs waiting on others** — concrete outcomes split by
  who holds the next move.
  - "Shipped" = landed in a usable state (merged, deployed, sent).
  - "Stalled" = real intent + real effort, but no outcome yet, AND the next
    move is the user's. One-line reason for each.
  - "Waiting on others" = artifact is ready on the user's side; the next
    move is someone else's (panel-date confirmation, client reply, vendor
    response, PR review). Do NOT put these in Stalled — that conflates user
    bottlenecks with counterparty bottlenecks and produces misleading
    self-criticism. Omit the section entirely if no such items exist.
- **Tangents and yak-shaves** — work that wasn't planned. Renamed from "drift"
  because we have no plan-input; tagging it as "tangent" is honest, not a
  judgment.
- **Decisions** — choices made this week worth remembering 6 months out.
  Tech ("switched from x to y because"), project ("paused Z to focus on W"),
  personal ("decided to push the dental thing to June").
- **Open loops** — what carries into next week, with enough context to pick
  it up cold.
- **Timesheet** — optional, omitted under `--no-timesheet`. Defensible
  per-project active engaged time for hourly billing, computed deterministically
  by `horizon-timesheet.py` (Step 5c), NOT by the LLM. The synthesis renders the
  rows verbatim. Distinct from Footer `Hours`: Footer is overlapping wall-clock
  span-sum (overcounts); Timesheet `active_h` is inter-message gaps with idle
  > 5 min dropped (a conservative floor on keyboard time). The method/caveat
  bullets are load-bearing — they are what make the number defensible to a
  client, so keep them.
- **Footer** — all numeric, all from `week-stats.json`. The synthesis must
  not invent or recompute these.

## Project wikilink rules

Map session `cwd` to project labels for the Projects line:

| cwd contains | Wikilink |
| --- | --- |
| `/satori/` | `[[Satori Ads]]` |
| `/client-project/` | `[[Client]]` |
| `/cc-tools` or `personal/cc-tools` | `[[tools@kintecus]]` |
| `/puch` | `[[puch]]` |
| `/homelab` | `[[Homelabbing on MBP]]` |
| `/finances` | `[[Finances]]` |
| `/meds` | `[[meds]]` |
| `/music-agent` | `[[music-agent]]` |
| `/tribe-coding` | `[[tribe-coding]]` |
| `/dotfiles` | `dotfiles` (no wikilink) |
| workspace root (`/code` alone) | `global session` |
| anything else | folder basename, no wikilink |
