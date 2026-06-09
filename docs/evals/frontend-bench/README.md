# Frontend bench: build-partner vs frontend-design

A repeatable head-to-head between two design philosophies for frontend work:

- **`/build-partner`** (this plugin) - restraint-forward. Less-but-better, deference, information-design honesty, long-lived over fashionable. Rooted in Rams, Tufte, Norman, Shape Up.
- **`frontend-design`** (Anthropic's built-in skill) - boldness-forward. Distinctive typography, dominant+accent color, orchestrated motion, anti-"AI slop", intentional maximalism or refined minimalism.

The two genuinely disagree about the visual layer. This bench exists to see that disagreement concretely, not to crown a permanent winner.

## This is not a neutral contest

The rubric is **deliberately weighted to surface the tension**. Half its dimensions favor restraint (information design, restraint & longevity) and half favor boldness (aesthetic distinctiveness / anti-slop). A "tie" is the expected, informative outcome - it tells you which agent to reach for per task, not which is "better." Read the verdict as *"for this brief, X's tradeoff fit better, because Y"*, never as a leaderboard.

## Procedure

1. Open **two fresh Claude Code sessions** (no shared context — context bleed contaminates the comparison).
2. **Arm A — build-partner:** invoke `/build-partner`, paste `brief.md`, and build it.
   - **Isolation:** `frontend-design` auto-triggers (it has no `disable-model-invocation`). For a clean comparison, tell build-partner to **own the visual layer itself for this eval — do not invoke `frontend-design`**. Otherwise the arms converge and you're testing the same skill twice.
3. **Arm B — frontend-design:** in the other session, build the same `brief.md` under the `frontend-design` skill (let it trigger normally).
4. Save each arm's output under `runs/<date>-<arm>/` (gitignored — heavy, throwaway).
5. Score both arms against `rubric.md`. Write the scored comparison and a one-paragraph verdict to `verdicts/<date>-verdict.md` (committed).

## What to commit vs ignore

- **Committed:** `brief.md`, `rubric.md`, this `README.md`, and everything under `verdicts/`.
- **Ignored:** `runs/` (the generated HTML/CSS/JS per arm — bulky and disposable; the verdict is the durable artifact). See the repo `.gitignore` entry `docs/evals/frontend-bench/runs/`.

## Note

This `docs/` tree is repo-only — `sync-to-cache.sh` does not copy it into the plugin cache, so the bench never loads as plugin context. That's intentional; it's documentation, not a skill.
