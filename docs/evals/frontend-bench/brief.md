# Bench brief: a launch landing page with a live metric

Build a single self-contained landing page for a fictional product. The brief deliberately mixes a **marketing surface** (where aesthetic distinctiveness matters) with an **embedded data element** (where information-design honesty matters), so both philosophies have something real to chew on.

## The product

**Tideline** — a tide-and-swell forecast app for open-water swimmers. Free, no account, works offline.

## Required sections (in order)

1. **Hero** — product name, a one-line value proposition, and a single primary call to action ("Get Tideline"). One supporting line max. No carousel.
2. **Live conditions strip** — a small honest data display showing the *current* conditions for one example location (Brighton): water temp (14°C), wave height (0.8m), high tide (in 3h 12m), wind (12 km/h SW). This is the information-design test: show four real numbers, comparably and without chartjunk. No fake gauges, no decorative dials that don't encode the value, no 3D.
3. **Three features** — offline maps, 7-day swell forecast, safety alerts. One sentence each.
4. **Footer** — one honest line, no fake social proof, no invented testimonials, no "trusted by 10,000 swimmers" unless you label it as illustrative.

## Constraints

- Single `index.html`, self-contained (inline or `<style>`/`<script>` — no build step, no external runtime deps; web fonts via `<link>` are fine).
- Responsive: must hold up at 375px and 1280px.
- No copy that overstates the product (it's free and offline — say so; don't manufacture urgency).
- The four live numbers must be readable at a glance and honestly proportioned — a swimmer deciding whether to get in the water is the user.

## What's intentionally left open

Typography, color, layout, motion, and overall aesthetic direction are **yours to decide** — that's the whole point of the comparison. Commit to a direction and execute it completely. State your aesthetic rationale in one or two sentences before the code.
