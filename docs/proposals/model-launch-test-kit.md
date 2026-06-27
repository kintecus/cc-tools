# Spec 2: model-launch test kit ("10 tests")

## Origin
Ali K. Miller (TITV 2026-06-26): keep a fixed set of representative tasks so the day a new model drops you can benchmark *your own* use cases in an hour, not vibes. "Have that set of 10 tests that the second the model comes out, you are ready to test." She emailed every client within 24h of Fable 5 launching.

## Goal
A versioned, repeatable kit that answers one question fast: **does the new model do MY actual work better/cheaper/faster?** Not MMLU. Not someone's leaderboard. Your jobs-to-be-done.

## Design principles
- **Drawn from real work**, not synthetic. Each test is a frozen copy of a task you genuinely do.
- **Fixed inputs, gradeable outputs.** Each test ships its input + a rubric of "what good looks like" (Miller's `/GOAL` rubric idea, reused here as the grading criterion).
- **Cheap to run.** One command, ~1 hour wall-clock, runs on your $200 Max sub.
- **Diffable across models.** Same prompts -> compare Opus 4.8 vs the new model side by side. Save outputs per `(test, model, date)`.
- **Span your real surface area** - mix of code, PM/writing, agentic, and judgment tasks, because "the model" eval is now the *full harness*, not raw reasoning.

## The 10 tests (calibrated to your projects)

### Code (3)
1. **walletsvc refactor judgment** - feed a real diff (e.g. the r5 dead-code-cleanup working tree) and ask: what's safe to delete, what's load-bearing, what's risky? Rubric: catches the load-bearing items, no false "safe to delete" on used code.
2. **puch math-problem generation** - generate N age-appropriate math problems with the puch constraints (learning-first, no dark patterns, correct difficulty curve). Rubric: pedagogically sound, correct answers, no trivial/duplicate items.
3. **Bug-in-a-haystack** - a known past bug from a real repo, the surrounding file, "find and explain the bug." Rubric: finds it, explains root cause, no hallucinated fixes.

### PM / writing (3)
4. **Jira wiki-markup conversion** - convert a markdown spec to Jira wiki markup (`{code}`, `*bold*`, `h2.`). Rubric: valid wiki markup, no leftover markdown, your house rules respected.
5. **Amazon-style tightening** - run a fluffy draft through the "eliminate weasel words, data over adjectives, narrative prose" bar. Rubric: weasel words gone, claims evidence-backed, voice preserved.
6. **Decision-doc synthesis** - given a raw voice-exchange transcript (you have real ones in movie-grants/raw/), produce a decision doc + index line. Rubric: captures the actual decisions, no invented ones, your terse style.

### Agentic / harness (2)
7. **Daily-note triage** - given a week of daily notes, triage open todos by priority/area (your `/triage-week` job). Rubric: correct prioritization, asks about genuinely-ambiguous items, doesn't invent todos.
8. **Multi-step repo task** - a small bounded "find X across repos, do Y" (like the git-push sweep). Rubric: completes without unsafe actions, respects confirm-before-write, accurate report.

### Judgment / de-risk (2)
9. **Push-back test** - hand it a deliberately flawed plan/architecture. Rubric: it challenges the flaw (your "push back when warranted" standard) instead of agreeing.
10. **Stale-knowledge guard** - ask about a fast-moving external API/console where the answer changed post-cutoff. Rubric: it flags uncertainty / says "verify live" instead of confidently narrating from memory (your hard-won Sentry/Transactions-dataset lesson).

## What each test file holds
```
tests/<id>-<slug>/
  input.md         # frozen task input
  GOAL.md          # /GOAL rubric: goal + "what good looks like"
  baseline/        # saved outputs per model+date for diffing
    opus-4.8_2026-06-27.md
```

## How to run
- **Manual day-one:** `/model-test <model-id>` (or just paste the kit into a session on the new model) -> runs all 10 -> writes outputs to `baseline/<model>_<date>/` -> prints a one-line verdict per test (better/same/worse vs current default) + token cost per test.
- **Grading:** Miller's own 30/70/90 lens as the scale - mark each task's capability bucket. Optionally use a secondary model as judge for the gradeable ones (test 1, 3, 4, 5) per her "AI as judge at 90%+" idea.

## Where it lives
Natural home: extend the existing eval scaffolding. You already have `~/code/personal/pidcast/evals/` (provider comparison) and the `skill-creator` eval tooling. Two options:
- **(A)** A standalone `~/code/personal/model-launch-kit/` repo - clean, portable, not coupled to one project.
- **(B)** A `cc-tools` command `/model-test` that knows where the kit lives.
- **Recommended:** A small standalone kit repo (A) for the frozen inputs + baselines, plus a thin `/model-test` runner command (B) that points at it. Keeps test data versioned separately from the runner.

## Reality check / caveats
- **Subscription, not API:** on your $200 Max sub you won't get clean per-token cost numbers the way API users do. Cost-per-test will be approximate. The *quality* delta is the real payoff; treat cost as secondary (matches Miller - she stays under the cap on purpose and optimizes for quality, not token accounting).
- **Maintenance cost:** a test kit rots too. Tests 1-2 reference live working trees; freeze copies into the kit so they don't move under you. Test 10 needs a fresh "what changed recently" target each time.
- **Don't over-build:** start with maybe 5 tests you'd actually run, prove the workflow, then grow to 10. Ten is Miller's number, not a law.

## Build estimate (rough)
Frozen inputs + rubrics for ~5 tests + a thin runner: ~M effort, most of it your time picking/curating the real tasks (only you know which diffs/drafts are representative). The runner itself is small.
