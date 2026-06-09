# Plan Review Protocol

Critique an implementation plan with a **fresh-context subagent** before any code is written. The
value is independence: the reviewer has not seen the planning conversation, so it does not inherit
its assumptions. This is the plan-and-review pattern — review surfaces intent-level errors *before*
tokens are burned generating broken code.

## When to run

- A plan was just accepted via `ExitPlanMode` and the user agreed to a review. The review offer is owed on every acceptance regardless of the edit-approval mode chosen — "auto-accept edits" is not a decline of the review, only a separate edit-approval setting.
- The user ran `/review-plan` (the plan may be pasted from outside this session).

If no plan is in context, ask the user to paste the plan to review.

## Step 1 — Isolate the plan artifact

Extract the plan text **only**. Do not pass the planning conversation, your rationale, file contents
you explored, or chat history. The subagent must judge the plan on its own merits. If the plan
references files, list their paths so the reviewer can read them itself with fresh eyes.

## Step 2 — Spawn the reviewer subagent

Use the `Task` tool. Default `subagent_type: Plan` (read-only, can inspect the codebase); use
`general-purpose` if the plan needs broader tool access. Inherit the model — same model, fresh
context is what matters. Pass this prompt, with `<PLAN>` replaced by the plan text:

```
You are reviewing an implementation plan written by another agent. You did NOT write it and have
no stake in it. Be a skeptical senior reviewer. Read any files the plan references before judging.

Find every gap, blind spot, unclear point, ordering problem, missing edge case, untested
assumption, and unhandled failure mode in the plan below.

For EVERY finding, output a row:
  - Priority: CRITICAL (plan fails or causes damage) | HIGH (likely rework) | MEDIUM (quality
    gap) | LOW (polish)
  - Finding: what is wrong, missing, or ambiguous — one sentence.
  - Suggestion: a concrete, specific change to the plan that resolves it. Not "consider X" —
    state what the revised plan should say.

Rules:
- Produce a suggestion for EVERY finding. Do not stop after the top few. Exhaust the list.
- If a step is ambiguous, say what it should specify, not just that it is vague.
- If the plan is sound in some area, say so briefly — do not invent problems.
- End with a one-line verdict: SHIP AS-IS | REVISE (minor) | REVISE (major) | RECONSIDER APPROACH.

<PLAN>
```

## Step 3 — Apply the review

When the subagent returns:

1. Show the user the findings table verbatim — priority, finding, suggestion.
2. Revise the plan: apply CRITICAL and HIGH suggestions; apply MEDIUM/LOW unless the user opts out.
3. Present the **revised plan** and the verdict.
4. If the verdict is `RECONSIDER APPROACH` → do not implement. Surface this prominently and ask the
   user how to proceed.

## Step 4 — Optional second pass

For large or high-risk plans, offer one more round: feed the *revised* plan back through Step 2.
Stop when a pass returns no CRITICAL or HIGH findings — do not loop indefinitely.

Only after the plan is revised and accepted: proceed to implementation.

## Anti-patterns

- Reviewing the plan yourself in the planning context — you authored it, your judgment is biased.
- Passing the planning chat history to the subagent — it then inherits the same blind spots.
- Accepting only the top 2-3 findings — the per-finding suggestion step exists to exhaust the list.
- Looping reviews forever — two passes is the practical ceiling.
