---
name: ask-gemini
description: >
  Delegate a research question to Google Gemini and return its answer inline.
  Invoke PROACTIVELY for research tasks where Gemini's Google Search grounding
  gives better current data than Claude's training cutoff (latest library
  versions, recent releases, news, pricing, current state of an API/spec, "what
  changed in X recently"). Also invoke when the user explicitly asks for
  Gemini's take or a second opinion. Do NOT invoke for implementation tasks,
  debugging, code review, questions answerable from local files, or things
  Claude already knows confidently. Triggers: "ask gemini", "what does gemini
  think", "/ask-gemini". The wrapper script ships with this skill.
---

# Ask Gemini

Delegate a single research question to Google Gemini via the bundled CLI/API
wrapper and return the answer inline.

The wrapper is `${CLAUDE_PLUGIN_ROOT}/commands/ask-gemini/ask-gemini`. It is also
on `PATH` as bare `ask-gemini` (a symlink in `~/.claude/bin/`), so either form
works.

## Decision: should this skill fire?

This skill exists for **two distinct trigger paths**. Most invocations are the
proactive path.

### Path A — Proactive on research tasks (auto-trigger)

Fire WITHOUT being asked when ALL of these hold:

1. The user is asking a **research question** — i.e. they want a fact about the
   world, not a code change. Phrasings like "what's the latest", "what's the
   current state of", "compare X vs Y", "what are the options for", "is X still
   maintained", "when did X release", "what changed in X recently".
2. The answer would benefit from **information beyond Claude's training cutoff
   (Jan 2026)**. Library versions, framework releases, pricing pages, API
   deprecations, news, market state, recent incidents.
3. The answer is NOT in the local codebase, recent git history, or this
   conversation. (Check first; if it's local, don't burn quota.)

When firing on this path, ALWAYS pass `--search`. Grounding is already on by
default for the cli backend, but `--search` is the explicit signal and also
steers the prompt — harmless and recommended.

Tell the user briefly that you're consulting Gemini and why, then run.

### Path B — Explicit second-opinion / Gemini call

Fire when the user explicitly asks. Phrasings: "ask gemini", "what does gemini
think", "get a second opinion from gemini", "see what gemini says",
`/ask-gemini ...`.

Use `--search` only if the question is about current/external info; otherwise no
grounding.

### Do NOT fire when

- The task is implementation, refactoring, debugging, code review, or any file
  edit.
- The user is asking about their own files, history, or session state. Read the
  files instead.
- The question is well within Claude's confident knowledge (general programming
  questions, well-known APIs unchanged in years, language fundamentals). Don't
  burn quota for things you know.
- The user has already told you in this session not to use Gemini, or said
  "answer it yourself."
- You're inside a loop or about to make multiple Gemini calls in quick
  succession. The wrapper is one-shot per user request, period.

## Backends

The wrapper has two backends with **separate, divergent** quota pools and model
catalogs. `cli` is the default.

- `--backend cli` — **`agy -p` (Antigravity CLI)** via OAuth-personal login.
  This is the **default backend**. Antigravity CLI replaced the old `gemini`
  CLI at Google I/O 2026; `gemini` stops serving accounts on 2026-06-18. Notes:
  Google Search grounding is **on by default** (cannot be toggled off); print
  mode has **no model flag** — it uses the account default (Gemini 3.5 Flash),
  so `--model` is ignored here; `--json` only appends a "respond as JSON"
  instruction and cannot guarantee well-formed JSON. 90s timeout
  (`ASK_GEMINI_CLI_TIMEOUT` overrides).
- `--backend api` — AI Studio REST API, the **fallback**. **flash-class only**:
  the free tier serves no pro-class model (every pro model returns an instant
  `limit:0` 429), so there is **no `pro` alias** and `--model pro` is rejected.
  Free-tier limits (May 2026): `gemini-3.5-flash` ~30 RPM / 1M TPM / 1500 RPD.
  Key at `$GEMINI_API_KEY` or `~/.config/ask-gemini/api-key`. `--json` is
  reliable only on this backend.

Default selection (when neither user nor caller specifies): `$ASK_GEMINI_BACKEND`
env var if set, else `cli` if `agy` is installed, else `api` if a key exists.
Don't override unless the user does.

**Resilience (handled by the wrapper, not this skill):** cross-backend fallback
is bidirectional and automatic unless `--backend` was explicitly forced — a cli
failure (timeout / non-zero exit) falls back to api, and api exhaustion (5xx/429
after retries) falls back to cli. The api path retries transient 429/503/500 and
honours the server-supplied `retryDelay` on a 429. Every call is logged to
`~/.config/ask-gemini/calls.log` (`timestamp · backend · model · status`) — read
that file first when diagnosing a rate-limit complaint.

## Invocation

```bash
# Proactive research with Google Search grounding (most common Path A use)
ask-gemini --search "<the user's research question>"

# Explicit second opinion, default (cli) backend
ask-gemini "<question>"

# User explicitly forced a backend
ask-gemini --backend cli "<question>"
ask-gemini --backend api "<question>"

# Reliable structured output — api backend only
ask-gemini --backend api --json "<structured prompt>"
```

## Output handling

1. Capture stdout. It is Gemini's answer in plain text.
2. Frame it for the user: lead with one sentence on why you consulted Gemini
   ("Checked Gemini with Google Search grounding for current data on X."), then
   present the answer in a quote block or as-is.
3. If the answer contradicts something you said earlier in the session, surface
   the disagreement honestly. Don't paper over it; tell the user both views and
   which one is grounded in fresh data.
4. If the wrapper exits non-zero or stdout is empty, report the failure plainly.
   Common: 429 (api quota), cli timeout, network. Do not fabricate.
5. Cite Gemini's sources verbatim when the response includes them. Don't
   paraphrase URLs.

## /ask-gemini slash command

When the user types `/ask-gemini <args>`, treat the arg string as the question.
Recognize prefixes:

- `search:` → `--search`
- `cli:` / `api:` → `--backend cli|api`

Prefixes can combine: `/ask-gemini api search: <question>`.

When invoked via slash command, this is always Path B (explicit) — no need to
re-evaluate triggers.
