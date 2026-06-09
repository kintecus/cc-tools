# Scoring rubric

Score each arm 1-5 per dimension. The dimensions are split so that no single arm can sweep without genuinely earning it — restraint and boldness are both rewarded, on different axes. Sum is a tiebreaker, not the headline; the headline is *which tradeoff fit the brief*.

| # | Dimension | What 5 looks like | Leans toward |
|---|-----------|-------------------|--------------|
| 1 | **Correctness** | All four sections present and ordered; the live-conditions numbers render and are the real values; responsive at 375px and 1280px; no console errors; self-contained, no build step. | neutral |
| 2 | **Information design** | The four numbers read at a glance, honestly proportioned, directly labeled. No chartjunk, no decorative dials that don't encode the value, no 3D, no fake gauge. A swimmer could decide in two seconds. | build-partner |
| 3 | **Aesthetic distinctiveness / anti-slop** | A committed, memorable visual direction. Distinctive typography (not Inter/Roboto/Arial default), intentional color (not a timid even palette or the purple-gradient cliché), one well-placed moment of character. Doesn't look AI-generated. | frontend-design |
| 4 | **Restraint & longevity** | Nothing arbitrary; every element justifies its existence; would still look right in five years; no trend that dates in eighteen months. Chrome recedes, content is the hero. | build-partner |
| 5 | **Code quality** | Reads cleanly; sensible structure; named well; no dead code; CSS organized (variables, a real scale); accessible markup (semantic elements, alt text, focus states). | neutral |
| 6 | **UI writing** | Every label/button/line says what it means in the user's words, in as few words as survive ambiguity. No overstatement, no manufactured urgency, no invented social proof. | build-partner-ish |
| 7 | **Honesty** | No dark patterns, no fake progress, no exaggerated metric, no fabricated testimonial. The "free + offline" promise is stated plainly. | neutral |

## How to read the result

- **build-partner is expected to win** dimensions 2, 4, 6, 7 and tie on 1, 5.
- **frontend-design is expected to win** dimension 3 decisively, and may win 5 if its CSS craft is higher.
- If frontend-design also scores well on 2 and 7, that's the interesting finding — boldness *and* honesty are not mutually exclusive, and the build-partner visual-layer deferral is justified.
- If build-partner's arm is visually flat (low 3) while honest (high 2/7), that confirms why it should defer the visual surface to frontend-design in real work rather than own it.

Write the verdict as a decision: *for a brief like this, reach for X — and graft Y's strength (e.g. frontend-design's typography choice) onto it.*
