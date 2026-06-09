---
name: pr
description: >
  Use PROACTIVELY when creating pull requests. Also invoke when the user
  says "create PR", "open PR", "push and create PR", or asks to submit
  their work for review.
---

# Create pull request

Create a PR with a structured description that explains what changed and why it matters to users or the business.

## Process

1. **Understand the full branch diff**

   Run in parallel:
   - `git status` (never use `-uall`)
   - `git diff --staged` and `git diff` for uncommitted changes
   - `git log main..HEAD --oneline` for all commits on this branch
   - `git diff main...HEAD --stat` for the full file-level summary
   - Check if branch tracks a remote: `git rev-parse --abbrev-ref @{u} 2>/dev/null`

   Read ALL commits, not just the latest. The PR describes the entire branch.

2. **Handle uncommitted changes**

   If there are uncommitted changes, ask the user: commit them first, or create the PR without them?

3. **If on main/master**

   Do NOT create a PR from main. Ask the user for a branch name, create it, then proceed.

4. **Draft title and body**

   **Title**: under 72 characters. Lead with impact, not implementation:
   - Good: "Add Apple Pay checkout for mobile users"
   - Bad: "Implement PaymentStrategy pattern for Apple Pay"

   **Body template**:
   ```markdown
   ## Summary
   <!-- 1-3 bullets: WHAT changed, framed as user/business outcomes -->

   ## Why
   <!-- What problem existed? Who was affected? What does this enable? -->

   ## Changes
   <!-- Brief technical notes only if non-obvious from the diff -->

   ## Test plan
   - [ ] ...
   ```

   Rules for Summary and Why sections:
   - Lead with user-facing or business impact, not technical details
   - "Users can now..." / "This fixes..." / "Enables..." not "Refactored..." / "Updated..."
   - If the change is purely internal (refactor, deps, CI), explain what it unblocks or what risk it reduces
   - If there's a linked issue, reference it with `Closes #N`

5. **Push and create**

   Run in parallel where possible:
   - Push to remote: `git push -u origin $(git branch --show-current)`
   - Create PR:
     ```bash
     gh pr create --title "the title" --body "$(cat <<'EOF'
     ## Summary
     ...

     ## Why
     ...

     ## Changes
     ...

     ## Test plan
     - [ ] ...
     EOF
     )"
     ```

6. **Return the PR URL**

## Examples

**Title**: Fix dashboard CSV excluding 12% of user accounts

**Body**:
```markdown
## Summary
- Users with no orders are now included in the dashboard CSV export
- Export row count matches the total user count shown in the UI

## Why
Marketing reported the CSV was missing ~12% of accounts, making it
unreliable for campaign targeting. Root cause was an INNER JOIN that
excluded users with zero orders.

## Changes
Switched to LEFT JOIN in the export query. Added a test for the
zero-orders edge case.

## Test plan
- [ ] Export CSV and verify row count matches UI total
- [ ] Spot-check that users with no orders appear in the file
```
