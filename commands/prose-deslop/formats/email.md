# Email Format Guidelines

Emails have three sub-types. After the user selects "Email" as format, ask which type:
- **Personal** - casual emails to friends, family, acquaintances
- **Professional** - stakeholder comms, escalations, updates, decision requests
- **BLUF** - military-style Bottom Line Up Front

Apply the matching section below.

---

## Personal

### Context
Casual emails to friends, family, or acquaintances. Not work-related or lightly work-adjacent.

### Characteristics
- **Length**: 1-4 paragraphs. Short and conversational.
- **Formality**: Low. Closer to Slack than professional email.
- **Structure**: No headers needed. Natural flow.
- **Tone**: Warm, casual, direct. Like texting but slightly more structured.

### Specific patterns

#### Opening
- First name only, or skip greeting entirely
- Jump straight in: "hey, quick thing -" or just start talking
- Never "Dear" anything

#### Body
- Conversational prose, no bold headers
- Fragments and run-ons are fine
- Lowercase acceptable throughout
- Emoji sparingly if it fits the relationship (but don't add if not in the source)

#### Closing
- "talk soon", "later", just a name, or nothing
- Never "Best," or "Regards,"

#### Punctuation and style
- Comma splices, dashes, casual punctuation
- Lowercase fine throughout
- Sentence fragments welcome

### Transform guidance

#### From AI -> Personal email
- Strip all formality and corporate language
- Remove structured headers - just let it flow
- Convert bullet lists to conversational prose
- Lower the register significantly
- Remove sign-offs or replace with casual ones

#### From Draft -> Polished personal email
- Fix typos but keep casual tone
- Don't formalize anything
- Preserve the conversational rhythm

### Examples

#### Before (AI slop):
```
Dear Sarah,

I hope this email finds you well. I wanted to reach out regarding our upcoming plans for the weekend. I was thinking we could potentially explore some options for dinner on Saturday evening.

Please let me know your thoughts at your earliest convenience.

Best regards,
Ostap
```

#### After (Humanized):
```
hey Sarah,

are we still on for Saturday? was thinking dinner somewhere - maybe that new place on 5th you mentioned last time.

let me know what works.

Ostap
```

---

## Professional

### Context
Stakeholder communication - escalations, updates, decision requests. Recipients are busy execs or client-side leads who scan before they read.

### Characteristics
- **Length**: 3-8 paragraphs. Longer than Slack, shorter than a PRD.
- **Formality**: Professional but not stiff. Higher than Slack, lower than a formal doc.
- **Structure**: Bold section headers for scannability. Numbered options when presenting choices.
- **Tone**: Confident, factual, direct. No hedging unless uncertainty is real.

### Specific patterns

#### Subject line
- Short, specific, no fluff: "Forecasting API - Mar 16 milestone update"
- Never "Quick update on..." or "Just wanted to..."
- Lead with the project/topic, then the what

#### Opening
- One sentence max. State what this is about and why you're writing.
- "Quick update on X and where we go from here."
- Never "I hope this email finds you well" or "Writing to give you a transparent update"
- Skip "Hi [name]," is fine, but keep it to first names only

#### Body
- Prose paragraphs for narrative sections (what happened, root cause). Not bullet lists.
- Bold section headers to break up the email ("**Where we are**", "**So what**", "**Path forward**")
- "So what" over "What this means" - more direct
- When presenting options: numbered list with bold labels, one paragraph each
- Include data points where they strengthen the argument, but don't over-prove
- Technical precision maintained - these people are technical even if they're execs

#### Asks
- Bullet list is fine for asks - makes them scannable
- Direct: "Decision on X" not "We'd appreciate your input on X"
- "Who owns this and what's the timeline?" not "We'd like to understand ownership"

#### Closing
- No "Best," or "Best regards," or "Kind regards,"
- No "Happy to set up a call" - instead "Let us know if a call works better than async"
- Just sign your name. Or skip the sign-off entirely if the email is short.
- Never "Don't hesitate to reach out"

#### Punctuation and style
- Regular dashes for asides, never emdashes
- Comma splices acceptable but less frequent than Slack
- Sentence case throughout
- No exclamation marks unless genuinely warranted

### Transform guidance

#### From AI -> Professional email
- Strip throat-clearing openers ("I wanted to reach out", "transparent update")
- Replace "We believe" / "We think" with direct statements
- Convert formal transitions ("Furthermore", "Additionally") to line breaks or simple connectors
- Replace "significant" with the actual number
- "Happy to discuss" -> "Let us know if a call works better"
- Remove "Best," sign-offs
- Break numbered lists into prose where the narrative flows better
- Keep bold section headers - they're structural, not decorative

#### From Draft -> Polished professional email
- Tighten without formalizing
- Fix awkward phrasing but keep directness
- Preserve structure and section headers
- Don't add politeness that wasn't there
- Don't convert prose to bullets or vice versa unless it clearly reads better

### Examples

#### Before (AI slop):
```
Dear Anton and Frederic,

I hope you're doing well. I wanted to reach out to provide you with a comprehensive update on our progress with the model predictions integration.

We have identified a significant accuracy gap that we believe warrants your attention. Furthermore, we have developed two potential approaches that we think could help us move forward effectively.

We would be happy to schedule a call to discuss this further at your earliest convenience.

Best regards,
Ostap
```

#### After (Humanized):
```
Hi Anton, Frederic,

Quick update on the model predictions integration and where we go from here.

**Where we are**

Mar 16 target for the first prod release is missed. We submitted the PRs on schedule, but Jean's QA found a +24% CPM deviation on DEVC vs +4% on production. Root cause: model prediction win rates produce worse results than historical.

**What we need from you**

- Decision on the parallel deployment approach
- If model predictions need to improve first - who owns that and what's the timeline?

Let us know if a call this week works better than async.

Ostap
```

---

## BLUF (Bottom Line Up Front)

### Context
Military-style communication optimized for fast decision-making. The reader gets the conclusion or required action in the first sentence. Everything after is supporting detail they can read if needed. Works well for time-sensitive requests, status reports to senior leadership, or any email where the recipient needs to act fast.

### Characteristics
- **Length**: 2-6 paragraphs. The BLUF line itself is 1-2 sentences max.
- **Formality**: Medium-high. Direct but respectful. No casual language.
- **Structure**: BLUF line first (bold or labeled), then supporting context in logical order.
- **Tone**: Decisive, clear, zero ambiguity. Every sentence earns its place.

### Specific patterns

#### Subject line
- Action-oriented: "ACTION: Approve budget reallocation by EOD Friday"
- Or informational: "INFO: Pipeline migration complete - no action needed"
- Prefix with ACTION / INFO / DECISION / REQUEST when appropriate

#### BLUF line
- First sentence of the email body. States the key message, decision needed, or action required.
- Bold or prefixed with "BLUF:" for clarity
- Must be self-contained - reader should understand what's needed without reading further
- "BLUF: We need approval to extend the deadline by two weeks due to a vendor dependency."
- Not "BLUF: I wanted to update you on the project status" - that's not a bottom line

#### Supporting context
- Organized by relevance, not chronology
- Use short paragraphs or labeled sections: "Background:", "Impact:", "Options:", "Timeline:"
- Only include what the reader needs to make the decision or understand the situation
- Data and specifics over narrative - numbers, dates, names

#### Closing
- Restate the ask if the email is long: "Request: approval by Friday COB"
- No pleasantries, no "happy to discuss"
- Sign your name

#### Punctuation and style
- Regular dashes for asides, never emdashes
- Sentence case
- No exclamation marks
- Tighter than professional - every word counts

### Transform guidance

#### From AI -> BLUF email
- Extract the actual bottom line from wherever it's buried (usually paragraph 3 or later)
- Move it to the first line, bold or label it
- Strip all throat-clearing, hedging, and preambles
- Reorganize remaining content by relevance, not original order
- Remove anything that doesn't support the BLUF or help the reader act
- Replace vague language with specifics (dates, numbers, names)
- Add subject line prefix (ACTION/INFO/DECISION) if not present

#### From Draft -> Polished BLUF email
- Verify the BLUF line is actually the bottom line, not a topic sentence
- Tighten supporting context - cut anything redundant
- Ensure the ask is unambiguous
- Check that someone could act on the BLUF line alone without reading further

### Examples

#### Before (AI slop):
```
Dear Team,

I hope everyone is doing well. I wanted to take a moment to provide an update on the infrastructure migration project that we've been working on over the past few weeks.

As you may know, we encountered some unexpected challenges with the database replication process. After careful analysis and consideration, our team has determined that we will need an additional two weeks to complete the migration safely.

We believe this extension is necessary to ensure data integrity and minimize any potential disruption to our services. We would greatly appreciate your support in approving this timeline adjustment.

Please don't hesitate to reach out if you have any questions or concerns.

Best regards,
Ostap
```

#### After (Humanized):
```
Subject: ACTION: Approve 2-week extension for infra migration

**BLUF: Requesting approval to extend the infrastructure migration deadline from April 4 to April 18. Database replication issues make the original timeline unsafe for data integrity.**

**Background**
Database replication hit an unexpected schema conflict during the staging sync on March 20. Resolving it requires re-sequencing the migration steps and adding a validation pass.

**Impact of extension**
- No production downtime during the extra two weeks
- Reduces risk of data loss from ~12% (rushing) to <0.1%
- Dependent services (auth, billing) unaffected until final cutover

**Impact of not extending**
- Forced cutover risks partial data loss on 3 tables (~140K records)
- Rollback would take 6-8 hours of downtime

Request: approval by March 27 so we can adjust the sprint plan.

Ostap
```
