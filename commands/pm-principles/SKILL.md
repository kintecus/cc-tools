---
name: pm-principles
description: Interview the PM to articulate their personal product management principles, working style, strengths, and anti-patterns. Generates a PRINCIPLES.md that other skills reference. Use when the user wants to define or update their PM operating system.
disable-model-invocation: true
---

# PM Principles

Generate a personal PM principles document through structured interview.

## Usage

```
/pm-principles
```

## Context

This skill captures the PM's personal operating system - not a framework, not someone else's methodology, but how they actually think and work at their best (and what goes wrong when they're not at their best).

## Interview areas

Conduct as a conversation, not a questionnaire. Use the `AskUserQuestion` tool to present 2-3 questions at a time. Wait for responses before proceeding to the next area.

### 1. Problem-solving style

- How do you typically approach a new problem?
- When do you do your best thinking? (Alone? Whiteboard? Discussion?)
- What's your instinct when facing ambiguity - structure it or explore it?

### 2. Strengths and differentiators

- What do teams consistently value about working with you?
- When has your contribution clearly changed a project's outcome?
- What can you do that most PMs can't (or won't)?

### 3. Process preferences

- What's the minimum viable process you need to feel in control?
- What process rituals do you find genuinely useful vs performative?
- How do you balance documentation with speed?

### 4. Communication style

- How do you prefer to communicate with engineering? Leadership? Clients?
- When do you write vs talk vs draw?
- What's your approach to conflict or disagreement?

### 5. Anti-patterns and triggers

- When do you over-scope or over-engineer?
- What situations trigger your worst PM instincts?
- What does burnout look like for you? What are the early signs?

### 6. Influences and philosophy

- What PM-adjacent books/thinkers have shaped your approach?
- What do you take from each? What do you reject?
- What's your one-sentence PM philosophy?

## Output

Generate `PRINCIPLES.md` in the skill directory (`${CLAUDE_PLUGIN_ROOT}/commands/pm-principles/PRINCIPLES.md`).

### Format

```markdown
# PM Principles - {Name}

> Generated: {date}. A living document - update when your thinking evolves.

## How I think

{Problem-solving style, thinking preferences, relationship with ambiguity}

## What I'm good at

{Genuine strengths, backed by evidence from the interview}

## How I like to work

{Process preferences, communication style, tools and rhythms}

## What goes wrong

{Anti-patterns, triggers, burnout signals. Honest self-awareness.}

## Influences

{What shaped the approach, what's taken and rejected from each}

## In one sentence

{The PM philosophy distilled}
```

## Notes

- This is not a resume or self-marketing doc. It's a mirror.
- Push gently on vague answers. "I'm a good communicator" - how specifically?
- If the PM struggles to name strengths, ask about specific past projects and what went well.
- Anti-patterns section is the most valuable part. Don't let the PM skip it.
- This doc gets referenced by other skills (critique-idea, onboard-project). Keep it honest.
