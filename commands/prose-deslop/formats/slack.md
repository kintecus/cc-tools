# Slack Format Guidelines

## Context
Quick team communication, casual but purposeful. Mix of technical discussion and coordination.

## Characteristics
- **Length**: Usually 1-4 paragraphs, rarely longer
- **Formality**: Very casual - lowercase starts common, fragments welcome
- **Structure**: Loose, conversational flow
- **Tone**: Direct, sometimes urgent, always efficient

## Specific Patterns

### Opening
- No greetings unless continuing a thread that had them
- Jump straight to the point
- Lowercase starts are default: "ok so here's what i'm thinking"

### Body
- Single-sentence paragraphs common
- Use line breaks for emphasis/pacing
- Questions are direct: "does this work for you?" not "Would this approach work?"
- Technical terms without explanation (assume competence)

### Closing
- Often ends with action/question
- "lmk" "thoughts?" "make sense?" are natural
- "things like that" "you know" work as soft closers
- No sign-offs

### Punctuation
- Comma splices fine: "this looks good, let's ship it"
- Casual dashes for asides
- Periods optional at end of single-line messages
- No caps lock for emphasis, use repetition or simple words: "this is really important"

### Technical Communication
- Code/system names in backticks when needed
- Technical precision maintained
- No over-explanation of basic concepts
- "basically" and "essentially" used sparingly for simplification

## Examples

### Thread starter:
```
spotted an issue with the tracking pixel - it's firing twice on mobile

looks like the event listener isn't getting cleaned up properly. can take a look this afternoon unless someone's already on it
```

### Response:
```
yeah i see it

probably related to that react render thing from last week. i'll check the cleanup logic
```

### Technical explanation:
```
ok so the way this works - we batch the requests every 30s, unless the queue hits 100 items, then we flush immediately

means we're optimizing for latency on high-traffic but not hammering the api on low-traffic. makes sense for our use case
```

### Status update:
```
pushed the fix to staging

tested with the scenarios we discussed, looking solid. ready for you to review when you have a sec
```

## Transform Guidance

### From AI → Slack
- Remove all formality markers
- Break long paragraphs into 1-2 sentence chunks
- Convert questions from formal to casual
- Add lowercase starts for most messages
- Use line breaks for rhythm/emphasis
- Keep technical terms but strip explanatory padding

### From Draft → Polished Slack
- Fix actual typos but keep casual tone
- Tighten without formalizing
- Preserve fragments and casual punctuation
- Keep lowercase starts if present
- Don't add structure that wasn't there
