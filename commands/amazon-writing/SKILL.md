---
name: amazon-writing
description: Apply Amazon-style writing rigor to documents - eliminating weasel words, replacing adjectives with data, enforcing narrative prose, and ensuring every claim is evidence-backed. Use this skill when the user asks to "finalize" a document, requests "Amazon style" writing, says "make it crisp", "tighten this up", "final version", "final document", "no fluff", or wants a polished deliverable with high writing standards. Also trigger when the user asks to review a document for vague language, unsupported claims, or structural weakness.
---

# Amazon writing skill

Apply Amazon's internal writing standards to produce documents that are precise, data-driven, and ruthlessly clear. Every word earns its place, every claim has evidence, every recommendation has specific next steps.

## When to use

- User requests a "final document", "final version", or "finalize"
- User says "Amazon style", "make it crisp", "tighten this up", "no fluff"
- User asks to review a document for vague or weak language
- User wants a polished deliverable (report, memo, strategy doc, proposal)
- User asks to "de-weasel" or remove vague qualifiers

## Relationship to prose-deslop

This skill and `prose-deslop` solve different problems and work well together.

- **Amazon writing** handles structural rigor: eliminating weasel words, requiring evidence for claims, enforcing narrative flow, ensuring customer-centric framing.
- **Prose-deslop** handles voice: making text sound like the user rather than a corporate AI.

**Recommended workflow for final documents:**

1. Apply Amazon writing rigor (this skill) to tighten structure and eliminate weak language
2. Then apply prose-deslop in "humanize" mode with the appropriate format file to restore natural voice
3. The result should be rigorous AND human - not a sterile corporate document

If the user has not specified a prose-deslop format, skip step 2 unless the output reads like corporate AI. Use judgment.

## Core rules

### 1. Kill weasel words

Scan for and eliminate these on every pass. No exceptions.

**Banned words and phrases:** significantly, substantially, considerably, fairly, quite, very, extremely, arguably, likely, probably, generally, typically, often, usually, mostly, nearly, approximately, relatively, somewhat, rather, pretty, widely accepted, many experts, some studies suggest, it is believed that.

**Hedging verbs to scrutinize:** might, could, may, should. These are acceptable only when expressing genuine uncertainty - not as a hedge to avoid committing to a claim. If the thing is true, state it as true. If uncertain, say what data would resolve the uncertainty.

**Replacement strategy:** Don't just delete weasel words. Replace with specifics. "Sales increased significantly" becomes "Q4 unit sales increased 23% YoY across NA operations." If exact data isn't available, use X-placeholders: "Unit sales increased by X% compared to Q3, measured across X markets."

### 2. Replace adjectives with data

Every adjective should trigger the question: "What number would make this concrete?"

- "Fast response time" -> "Sub-100ms p99 response time"
- "High customer satisfaction" -> "94% CSAT based on 10,000+ survey responses"
- "Large user base" -> "2.3M monthly active users as of Q4 2024"

When data isn't available, flag it explicitly: "Customer satisfaction improved [exact metric needed - suggest running Q1 CSAT survey]."

### 3. Evidence standards

Every quantitative claim needs: source, time period, scope, and methodology where relevant. Not every sentence needs a footnote - but any claim that would prompt "says who?" needs backing.

Apply the "so what" test: after stating a data point, explicitly connect it to a business outcome or customer impact. Data without interpretation is noise.

### 4. Narrative prose structure

Write in complete paragraphs with topic sentences. Avoid bullet points in the document body - they break analytical flow and let writers avoid explaining relationships between ideas.

Exceptions where bullets are acceptable:

- Action item lists at the end of a section
- Technical specifications or requirements
- Comparison tables (use actual tables)

Lead with conclusions, then evidence. Busy readers should get the point from the first sentence of each paragraph.

### 5. Customer-centric framing

Frame analysis from the customer perspective first. Before discussing internal benefits, answer: "What changes for the customer?"

Be specific about which customers. Replace "customers" with "Prime members ordering groceries weekly" or "SMBs using fewer than 10 compute instances." The more precise the segment, the better the analysis.

### 6. Active voice

Eliminate passive constructions. "Mistakes were made" becomes "The engineering team deployed incorrect configuration settings." If you can't identify the actor, that's a sign the analysis is incomplete.

### 7. Abbreviation discipline

Multi-word terms repeated throughout a document should be introduced with their abbreviation in parentheses on first use, then referred to by abbreviation only. Example: "The media planning tool (MPT) enables..." - subsequent references use "MPT" throughout.

**Exceptions - do not define these, just use them:** Abbreviations that are universally understood within the document's domain context don't need introduction. For a product or marketing document: URL, CTR, CPC, CPM, API, UI, UX, CRM, SLA, ROI, KPI, and similar. Use judgment - if a reasonably informed reader in that domain would recognize it without a definition, skip the introduction.

**The test:** If you'd feel odd writing "click-through rate (CTR)" in an ad-tech document, you're probably over-defining. If the document mixes audiences (technical + executive), err toward defining once.

### 8. Specific next steps

Never end with vague recommendations. Every document should close with: who does what, by when, with what success criteria. "We should explore this further" is not a next step. "Product team to complete user research with 20 target-segment interviews by March 15, reporting findings in a follow-up memo" is.

## Process

When applying this skill to a document:

1. **First pass - structure**: Check that the document leads with conclusions, uses topic sentences, flows logically from most to least important
2. **Second pass - language**: Eliminate weasel words, replace adjectives with data, convert passive to active voice
3. **Third pass - evidence**: Verify claims have backing, add X-placeholders where data is missing, apply the "so what" test
4. **Fourth pass - customer lens**: Ensure customer impact is addressed before internal benefits
5. **Fifth pass - action items**: Verify the document ends with specific, measurable next steps
6. **Final pass - voice** (optional): If output sounds sterile, apply prose-deslop. Read `${CLAUDE_PLUGIN_ROOT}/commands/prose-deslop/SKILL.md` and the appropriate format file.

## Quality checklist

Before delivering, verify:

- Zero weasel words remain (re-scan the banned list)
- All adjectives are backed by data or flagged with placeholders
- Every paragraph opens with a topic sentence stating its conclusion
- Customer impact is explicit, not implied
- Next steps specify who, what, when, and success criteria
- Active voice throughout
- No orphan data points (every metric connects to a "so what")
- Multi-word terms introduced with abbreviation on first use; domain-standard abbreviations used without definition
- ==TODO ADD A RULE ABOUT SPELLING OUT NUMBERS==

## Reference

For the full Amazon writing system prompt that this skill is derived from, see `references/source-prompt.md`.
