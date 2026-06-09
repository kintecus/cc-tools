# PRD Format Guidelines

## Context
Product Requirements Documents - structured thinking about features, problems, and solutions. More formal than Slack but still Ostap's voice.

## Characteristics
- **Length**: Variable - can be several pages
- **Formality**: Professional but not corporate
- **Structure**: Clear sections, logical flow, some bullets when appropriate
- **Tone**: Direct, analytical, opinionated when warranted

## Specific Patterns

### Document Structure
- Clear headers for sections
- Mix of prose and structured elements (tables, bullets when they serve purpose)
- No executive summary fluff - get to the substance
- Proper capitalization in headers and formal sections

### Opening
- Start with the problem or context, no preamble
- Can use "we" for team context
- First paragraph sets up why this document exists

### Body Sections
- **Problem statements**: Direct, data-backed when possible
- **Context**: Enough background, not a history lesson
- **Solutions**: Analytical, consider trade-offs
- **Technical details**: Precise, assumes competence
- Paragraphs can be longer (3-5 sentences) when building an argument

### Lists and Bullets
- Use when structure helps (requirements, options, comparisons)
- Don't use for things that flow better as prose
- Keep bullet text substantial, not fragments
- OK to have sub-bullets when showing hierarchy

### Technical Writing
- Precise terminology
- Define terms only when necessary
- Include relevant data, metrics, examples
- Trade-off analysis is explicit: "this costs us X but gives us Y"

### Opinions and Recommendations
- Direct: "we should do X because Y"
- Not hedged: "I recommend" not "it might be worth considering"
- Reasoning is clear
- OK to say "this is the wrong approach" with justification

## Examples

### Problem Statement Section:
```
## Problem

Our current ad serving logic makes decisions at the request level, which creates two issues:

First, we're optimizing for individual auctions rather than user-level performance. A user who clicks once gets the same treatment as a user who never engages. This leaves money on the table - we're not capturing the value of high-intent users.

Second, the existing approach creates data silos. Each request is independent, so patterns that span sessions are invisible to the system. We see this in the conversion data where 40% of conversions happen on second or third visit, but we're not adjusting bids accordingly.
```

### Solution Comparison:
```
## Approach Options

**Option 1: Session-based tracking**
Build a session layer that aggregates requests within a 30-minute window. Simpler to implement, works with existing infrastructure. Downside: misses cross-session patterns and requires arbitrary timeout tuning.

**Option 2: User-level decisioning** 
Track user history over 30 days, make bid decisions based on predicted user value. Captures more signal, better long-term optimization. Requires new storage layer and model retraining pipeline.

Recommendation: Option 2. The infrastructure work pays off - early tests show 15-20% improvement in ROAS for retargeting campaigns. The session approach is a half-measure that we'd need to rebuild anyway.
```

### Technical Requirements:
```
## Technical Approach

The system needs three components:

1. **User profile store** - 30-day retention, sub-50ms read latency, handles 100k writes/sec. DynamoDB works here, cost is manageable at ~$2k/month at current scale.

2. **Feature pipeline** - processes events in near real-time (5-minute lag acceptable), outputs to profile store. Can extend existing Kinesis setup.

3. **Bid adjustment service** - reads profiles during auction, applies ML model, returns bid modifier. Separate service because it needs different scaling characteristics than main bidder.

Key constraint: can't add more than 10ms to auction latency. Means we need aggressive caching and circuit breakers if profile store is slow.
```

## Transform Guidance

### From AI → PRD
- Keep structure but make it denser
- Remove corporate language ("leverage", "synergies")
- Make recommendations direct, not wishy-washy
- Cut transitional phrases ("moving on to", "next we'll discuss")
- Preserve technical precision
- Keep some formality in headers/structure
- Use bullets only where they add clarity
- Maintain analytical tone but make it opinionated

### From Draft → Polished PRD
- Fix errors but keep voice
- Tighten arguments without losing substance
- Ensure logical flow between sections
- Check that claims have support
- Verify technical details are accurate
- Don't over-formalize the prose
- Keep direct recommendations intact
