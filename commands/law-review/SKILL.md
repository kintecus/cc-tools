---
name: law-review
description: >
  Review a diff, PR, plan, or spec against named software laws (hacker laws):
  Gall's Law, YAGNI, second-system effect, least astonishment, Chesterton's Fence,
  Hyrum's Law, Kernighan's Law, distributed-computing fallacies, Kerckhoffs,
  Goodhart, and a solved-problem check. Reports system-level design violations, not
  style. Scales review depth by blast radius and asks for evidence of outcomes.
  Triggers: "law review", "/law-review", "check this against hacker laws", "is this
  overbuilt", "review for simplicity", "what laws does this break".
disable-model-invocation: true
---

# /law-review

Review code or plans for **system-level** qualities, using named laws as a shared vocabulary. Line-level correctness and style belong to other reviewers (`/code-review`, linters). This review asks a different question: is this the simplest system that works, does it follow known idioms, and does it respect the contracts and history it touches?

The approach comes from Dave Kerr (author of the hacker-laws repo) on The Changelog, Nov 2026. Agents one-shot systems that work but are needlessly clever, so review shifts from syntax to violations of laws like YAGNI, Gall's Law, and least astonishment.

This skill is **read-only**. It reports; it does not edit.

## Arguments

- *(none)*: current branch vs its base, plus uncommitted changes.
- `<PR number>`: that pull request.
- `<path>`: a plan, spec, ADR, or design doc (review the design before code exists).
- `--laws gall,yagni,...`: limit to a subset (ids match the headings in the catalog).
- `--max <n>`: maximum findings (default 7).

## Step 1: Gather the target

- **Branch:** find the base with `git merge-base HEAD origin/main` (fall back to `origin/master`). Read `git diff <base>...HEAD` and `git diff HEAD`. Start with `--stat` and read file-by-file; don't dump a huge diff at once.
- **PR:** run `gh pr diff <n> --name-only` first. If the branch is checked out locally, read the diff with `git`, not by paging `gh pr diff`. Read the PR body: it may already answer a law (for example, "installed clients keep working because...").
- **Plan or spec:** read the file and the code it references.

## Step 2: Load the project's own guardrails

Project rules override the generic catalog. Read whichever exist: `CLAUDE.md`, `AGENTS.md`, `.claude/rules/*.md` that match the changed paths, `docs/adr/` entries the change touches, and invariants or architecture docs. Note any laws the project already names, any listed "fences" (known deliberate oddities), and the project's dependency policy. A project that says "stdlib or twenty lines of our own code first" changes how the solved-problem check applies.

## Step 3: Triage by blast radius

Classify each changed file before applying laws:

| Tier | Typical paths | Depth |
|---|---|---|
| High | Auth, sessions, permissions/ACL, tokens, crypto and signing, payments, migrations and data deletion, public API or wire contracts, anything installed on user devices | Line by line. Check the security laws. Ask for a one-sentence threat model if none exists. |
| Medium | Core domain logic, background jobs, external integrations | Structure plus the reliability laws |
| Low | UI copy and layout, internal tooling, docs, tests (except for Goodhart) | Skim for structure only |

## Step 4: Apply the laws

Read `${CLAUDE_PLUGIN_ROOT}/commands/law-review/references/laws.md`. For each law, look for its listed **signals** and check its **not a violation when** clause before flagging. Rules:

- Flag only when a signal is present in this change. Don't flag a law because it could apply in theory.
- Don't fill the quota. Zero findings is a valid, useful result.
- The smallest fix is often a deletion. Say so.
- If a finding rests on intent you can't see (for example, a second caller planned for next week), phrase it as a question, not a verdict.

## Step 5: Evidence check

Passing tests are hygiene, not evidence. Check whether the change (PR body, commits, or attached artifacts) shows the outcome working, in a form that matches the interface:

- CLI or TUI: a terminal recording or captured session
- UI: screenshots or a short video
- Service or API: request and response logs from a real run or smoke test
- High-tier changes: the refusal paths running (wrong, missing, or other-tenant credentials)

If evidence is missing, say what specific artifact would close the gap.

## Step 6: Report

```markdown
## Law review: <target>

**Blast radius:** <high/medium/low files, one line each tier>

### Findings
1. **<Law>** - `<file:line>` - <what the change does>.
   *Why it matters:* <concrete cost or failure, not a restatement of the law>.
   *Smallest fix:* <often a deletion or a simpler shape>.
2. ...

**No findings:** <laws checked with nothing to flag, comma-separated>

### Evidence
<present / missing: what artifact would close the gap>

### Mental-model check
<2-3 questions a human owner should be able to answer about this change before merging, e.g. "What happens to existing clients when X?", "Where does Y get retried?">
```

Rank findings most severe first: security and contract breaks, then irreversible scope, then simplicity. Keep each finding to three short lines. The mental-model check is there because a team's speed is limited by how well its shared mental model matches what the system actually does. Those questions are how the human re-syncs with what the agent built.
