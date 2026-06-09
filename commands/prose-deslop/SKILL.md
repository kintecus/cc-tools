---
name: prose-deslop
description: Transform AI-generated text into Ostap's natural writing style, or polish drafts while preserving voice. Use when the user asks to "de-slop", "humanize", "make it sound like me", or "polish" any text.
---

# Prose De-slop Skill

## Purpose
Transform AI-generated text into Ostap's natural writing style, or polish Ostap's drafts while preserving his voice.

## When to Use
- User asks to "de-slop", "humanize", "make it sound like me", or "polish" any text
- User provides AI-generated content that needs voice transformation
- User provides a draft that needs refinement

## Core Voice Patterns

### Structural
- **Direct entry**: No preambles, jump straight to the point
- **Short paragraphs**: Often single sentences, maximum 2-3 sentences
- **Casual punctuation**: Comma splices are fine, strategic run-ons
- **Lowercase starts**: Common in casual contexts (slack, quick messages)
- **Dash usage**: Regular dashes (-) for asides, never emdashes (—)
- **Fragment comfort**: Incomplete thoughts that land better than polished ones

### Linguistic
- **No hedging theater**: Skip "I think", "it seems", "perhaps" unless uncertainty is real
- **Strategic informality**: "you know", "yeah", "things like that" for emphasis or closure
- **Questions as tools**: Rhetorical questions or thinking-out-loud questions, not engagement bait
- **Technical precision + casual delivery**: Expert language without over-explanation
- **Subtle non-native patterns**: Occasional article variations, different preposition choices (but natural, not forced)

### What to Remove (AI tells)
- Preambles and throat-clearing ("I'd be happy to", "Let me help", "Here's what I'm thinking")
- Excessive hedging ("might", "could potentially", "it's worth noting")
- Formal transitions ("Furthermore", "Additionally", "In conclusion")
- Bullet point overuse (use prose unless structure demands bullets)
- Enthusiasm markers ("Great question!", "Excellent point!")
- Safe corporate language ("leverage", "synergy", "circle back")

## Process

### Step 1: Determine Mode and Format
Use the `AskUserQuestion` tool to ask the user:
1. **Direction**:
   - "Humanize" (AI → Ostap's style)
   - "Polish" (Ostap's draft → refined version)

2. **Format** (load corresponding .md file):
   - Slack message
   - Email
   - PRD (Product Requirements Document)
   - Vision doc
   - [Future formats to be added]

Ask both questions in a single `AskUserQuestion` call before proceeding.

**If the user selects Email**: ask a follow-up question for the email sub-type:
   - Personal (casual - friends, family, acquaintances)
   - Professional (stakeholder comms, escalations, updates)
   - BLUF (military-style Bottom Line Up Front)

Then apply the matching section from `formats/email.md`.

### Step 2: Load Format Guidelines
Read the appropriate format file from `${CLAUDE_PLUGIN_ROOT}/commands/prose-deslop/formats/[format].md` for context-specific rules.

### Step 3: Transform

#### Humanize Mode (AI → Ostap)
1. Strip all AI tells and preambles
2. Break into shorter paragraphs (1-3 sentences max)
3. Convert formal transitions to casual connectors or remove entirely
4. Replace bullet lists with prose where appropriate
5. Add strategic informality markers (1-2 per message, not every paragraph)
6. Casualize punctuation (comma splices, dashes for asides)
7. Apply format-specific patterns from loaded .md file
8. Preserve technical accuracy and precision

#### Polish Mode (Ostap → Refined)
1. Keep voice and directness intact
2. Fix actual errors (spelling, grammar mistakes)
3. Tighten wordiness without formalizing
4. Maintain paragraph rhythm and structure
5. Preserve all stylistic choices (casual punctuation, fragments, lowercase)
6. Apply format-specific polish from loaded .md file
7. Don't remove informality - that's the voice

### Step 4: Output
Present the transformed text without meta-commentary. If significant choices were made, add a brief note after.

## Examples

### Before (AI slop):
```
I'd be happy to help you understand this approach. Here are the key considerations:

• First, we need to think about the user experience
• Additionally, we should consider the technical implications
• Finally, it's worth noting that this aligns with our broader strategy

I think this could potentially be a great solution for our needs.
```

### After (Humanized for Slack):
```
ok so here's the thing - we need to look at UX first, then figure out the technical side. 

this actually fits pretty well with what we're already doing strategy-wise. should work.
```

### Before (Ostap's draft):
```
i think we shoudl probably considre doing this becuase it makes sense from a technical perspetive and also the users will benfit from it in the long run
```

### After (Polished):
```
we should do this - makes sense technically and users benefit long-term
```

## Critical Rules
- Never add intentional typos
- Never force "weird English" - keep variations subtle and natural
- Never ask follow-up questions after transformation (just deliver)
- Preserve technical accuracy always
- Don't explain the transformation unless user asks
- If format file doesn't exist, proceed with core patterns and note which format is missing

## Format File Template
Each format file should include:
- Typical length/structure
- Formality level
- Specific patterns for that format
- Examples

See existing format files in `${CLAUDE_PLUGIN_ROOT}/commands/prose-deslop/formats/`
