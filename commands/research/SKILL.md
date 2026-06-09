---
name: research
description: >
  Research a technology, library, API, or architecture pattern using web search.
  Use PROACTIVELY when the user needs external information not available in the
  local codebase. Triggers: "research X", "look up X", "find docs for X",
  "what are the options for X", "compare X vs Y", "evaluate X for our use case".
  Do NOT trigger on: debugging questions, implementation tasks, things answerable
  from local code or git history, simple coding questions where you already know
  the answer confidently.
---

# Web research

Research technologies, libraries, APIs, and architecture patterns via web search. Two modes: quick lookup for factual questions, deep research for decisions.

## Step 1: Decide mode

**Quick lookup** - use when:
- Single factual question ("what's the API for X", "current version of X")
- Specific syntax, config option, or flag lookup
- One-concept answer that fits in a paragraph

**Deep research** - use when:
- Comparing alternatives ("X vs Y", "options for solving Z")
- Evaluating a technology for a specific use case
- Architecture or design pattern investigation
- Multi-factor analysis where trade-offs matter

If unclear, start quick. Escalate to deep if the first search reveals the topic needs more investigation.

## Step 2a: Quick lookup

1. Run one `WebSearch` for the query
2. If the top result looks authoritative (official docs, well-known blog), `WebFetch` it for details
3. Return the answer directly, with source URL

Format:
```
[concise answer]

Source: [url]
```

No preamble, no "here's what I found", no summary headers. Just the answer.

## Step 2b: Deep research

1. Run 2-4 `WebSearch` calls with different angles (e.g., "X vs Y comparison", "X production experience", "Y limitations")
2. `WebFetch` the 2-3 most authoritative sources (official docs, experience reports, benchmarks)
3. Cross-reference findings - flag conflicting information explicitly
4. Synthesize into structured output

Format:
```
## Research: [topic]

### Summary
[2-3 sentence synthesis of findings]

### Findings
- [key point] - [source]
- [key point] - [source]
- [conflicting info flagged if found]

### Recommendation
[what to do, contextualized to the user's stack and project - read from CLAUDE.md, don't hardcode preferences]

### Trade-offs
[what you give up with the recommended approach]
```

Read the project's CLAUDE.md and workspace CLAUDE.md for stack context when forming recommendations. Never hardcode technology preferences.

## Step 3: Memory persistence (deep research only)

After deep research, evaluate whether findings are worth persisting to auto-memory (`~/.claude/projects/-Users-ostaps-code/memory/`).

**Save when:**
- A technology decision was reached ("chose X over Y because Z")
- A non-obvious finding would save significant time if encountered again
- The user explicitly says "remember this"

**Don't save:**
- Syntax lookups, version numbers, API signatures
- One-off questions unlikely to recur
- Information that changes frequently (pricing, rate limits)

When saving: create `research_<topic>.md` with standard memory frontmatter (type: reference), and update MEMORY.md index.

## Rules

- Before searching the web, check if the answer is in the local codebase. Grep first if there's any chance the project already has what's needed.
- Don't trigger on "why is this error" or "how do I fix" questions - those are debugging, not research.
- Don't apply deep research ceremony to quick lookups. Most queries are quick.
- Don't recommend tools or frameworks already specified in the user's CLAUDE.md - just reference what's there.
- If a search returns no useful results, say so. Don't pad with generic advice.
