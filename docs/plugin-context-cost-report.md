# Plugin context cost report

Generated: 2026-05-28 (supersedes 2026-04-03)

Measured against the currently enabled plugin set in `~/.claude/settings.json`:
plantuml, statusline-compact, retroscope, playbook, semver, context,
git-branch-naming, kb-grooming, skill-creator, tools@kintecus, mermaid,
technology-explainer. `essentials@nicknisi` is no longer enabled (its researcher
agent — the April report's biggest offender — is already gone; a 424K leftover
sits unused in the cache and can be reclaimed).

## Always-loaded context (every session)

| Source | ~Tokens | Notes |
|--------|--------:|-------|
| **tools@kintecus inject-rules.sh** | **~418** | SessionStart hook: base rules + daily note. Non-cacheable (note changes during day). Was ~134 in April; grew with more base-rule plugins. |
| **Skill list descriptions (all plugins)** | **~600+** | One frontmatter description line per skill in system reminders; ~40 skills now enabled. |
| **kintecus skill descriptions (subset of above)** | **~1,375** | 14 kintecus skills' frontmatter descriptions, always loaded so Claude knows when to match them. |

The April baseline of ~9,110 tokens is gone: ~7,146 of it was the four
essentials@nicknisi agents, which are no longer loaded. Current always-loaded
baseline is well under 2,500 tokens (~1.2% of a 200K window, ~0.25% of 1M).

## On-demand context (loaded only when a skill is invoked)

| Plugin | Skills | ~Tokens |
|--------|-------:|--------:|
| **tools@kintecus** | 14 | **~22,484** |
| **technology-explainer** | 6 | ~3,199 |
| **mermaid** | 3 | ~2,913 |
| **kb-grooming** | 2 | ~2,591 |
| **context** | 2 | ~1,982 |
| **plantuml** | 3 | ~1,928 |
| **git-branch-naming** | 2 | ~1,757 |
| **semver** | 2 | ~1,708 |
| **retroscope** | 2 | ~1,704 |
| **playbook** | 2 | ~872 |
| **statusline-compact** | 1 | ~427 |
| **TOTAL** | **39** | **~41,567** |

skill-creator (~8,093 in April) is loaded on demand and only when invoked; not
re-measured here.

## kintecus/tools per-skill footprint (SKILL.md + bundled references)

tools@kintecus has grown from 6 skills (~7K tokens) in April to 14 skills
(~22.5K), now more than half the total on-demand surface across all plugins.

| Skill | ~Tokens | Notes |
|-------|--------:|-------|
| clippings-digest | ~9,950 | Largest. SKILL.md ~3.9K tok + component-kit/HTML template refs ~6K. Heavy but only loads on digest runs. |
| prose-deslop | ~7,296 | SKILL.md small; 4 format files (email/slack/prd/vision-doc) dominate. |
| horizon | ~7,003 | SKILL.md ~3K tok + 4 reference files (output-template, extract-spec, config-schema, cli-contracts). |
| amazon-writing | ~3,494 | SKILL + source-prompt reference. |
| calendar | ~2,894 | Large SKILL.md, no refs. |
| obsidian-vault | ~2,054 | |
| ask-gemini | ~1,635 | |
| review-plan | ~1,230 | |
| reflect | ~1,208 | |
| commit | ~966 | |
| research | ~927 | |
| pm-principles | ~807 | |
| pr | ~753 | |
| daily-note | ~630 | |

## Recommendations

| Action | Savings | Impact |
|--------|--------:|--------|
| **Reclaim cache leftovers** | ~424K disk + cleanliness | `nicknisi/` (disabled) + 10 stale `kintecus/tools/*` versions below 0.15.0. Disk only, zero context. |
| **Split clippings-digest references** | up to ~6K tok per invocation | Component-kit + HTML template only needed when actually emitting the HTML page. Could gate behind a sub-step so a quick digest doesn't pay for the design system. |
| **Trim large SKILL.md bodies** | ~1-3K tok each | calendar (~2.9K) and obsidian-vault (~2K) carry no references — the cost is the SKILL.md itself. Worth a pass to move detail into `references/` so it loads only when needed. |
| **Keep everything else** | - | On-demand cost is paid only on invocation; always-loaded baseline is now negligible. |

The April report's headline fix (remove the researcher agent) is already done.
No remaining always-loaded waste worth chasing. The real story now is that
tools@kintecus's own on-demand surface tripled — if any optimization is worth
doing, it's deferring the heavy reference bundles (clippings-digest, prose-deslop,
horizon) so they load only on the sub-path that needs them, not on every
invocation of those skills.
