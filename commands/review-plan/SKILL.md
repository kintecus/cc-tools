---
name: review-plan
description: >
  Manually trigger a fresh-context review of an implementation plan.
  Use after exiting plan mode, or to review a plan pasted from another session or document.
  Critiques the plan for gaps, blind spots, and ordering issues, then iterates it before any code.
  Keywords: review plan, review-plan, critique plan, plan review, check my plan.
---

# Review Plan

Run a fresh-context review of an implementation plan.

## Steps

### 0. Clear the pending-review gate marker

A `PreToolUse` edit-gate prompts before the first post-plan code edit until the
pending-review marker is cleared. Running this skill *is* the review, so clear it
first so the gate does not fire mid-review:

```bash
rm -f "${TMPDIR:-/tmp}/cc-plan-review-pending-${CLAUDE_CODE_SESSION_ID}" 2>/dev/null || true
```

`CLAUDE_CODE_SESSION_ID` is set in the Bash context and matches the hook
`session_id` used to key the marker. Best-effort: ignore any failure.

### 1. Locate the plan

- If a plan was just produced in this session (via plan mode / `ExitPlanMode`) → use that plan text.
- If the user passed a plan as an argument or pasted one → use that.
- If no plan is available → ask the user to paste the plan to review.

### 2. Run the review protocol

Read `${CLAUDE_PLUGIN_ROOT}/commands/review-plan/references/protocol.md` and follow it exactly:

- Isolate the plan artifact — pass only the plan text to the reviewer, never the planning chat.
- Spawn a fresh-context `Task` subagent with the review prompt from the protocol.
- The review must produce prioritized findings with a concrete suggestion for **every** finding.

### 3. Apply and present

- Show the findings table verbatim.
- Revise the plan with the suggestions (CRITICAL/HIGH always; MEDIUM/LOW unless the user opts out).
- Present the revised plan and the verdict.
- On a `RECONSIDER APPROACH` verdict → stop and ask the user how to proceed; do not implement.

Implement only after the revised plan is accepted.
