# Component kit — bespoke HTML blocks for clippings-digest pages

The `templates/digest-page.html` skeleton already carries the **always-applicable**
structure (masthead, standfirst, topic sections, `.dog` cards, sources, endnote).
This file documents the **bespoke** components — the editorial vocabulary that only
fits when the *content of a batch* genuinely supports it.

## The gate: when to reach for these

A clippings digest is a survey of unrelated articles. It has no single thesis, so
**by default you use none of the components below.** Add one only when the test
passes:

| Component | Use ONLY when… |
|---|---|
| `blockquote` pull quote | Always OK — once per page, to elevate the single best clipping's core idea. |
| `.callout` | A correction, caveat, or "read this first" note genuinely applies (e.g. a clipping contradicts another, or a batch is unusually skewed). |
| `figure` + SVG chart | A clipping (or the batch) carries **real quantitative data** worth plotting — counts, trends, comparisons. Never fabricate numbers to fill a chart. |
| `.players` comparison grid | **2–4 clippings are directly comparable** on the same axes (e.g. three articles each reviewing a different tool). |
| `.timeline` | Several clippings form a **genuine chronology** (a sequence of events, a roadmap, a "how X evolved" arc). |
| `.bottomline` | The batch supports a **single synthesised takeaway** — rare for a survey digest; common for a single-topic article. |

All CSS classes below are already defined in `digest-page.html`'s `<style>` block.
Do not add a separate stylesheet.

---

## Pull quote

```html
<blockquote class="reveal d1">It isn't a stable utility you're buying. It's a land-grab-phase price.</blockquote>
```

Short, declarative, ideally lifted or distilled from the strongest clipping. One per page.

---

## Callout

```html
<div class="callout reveal d3">
  <span class="label">⚠ Setting the record straight</span>
  <p>One tight paragraph. Bold the key correction with <strong>strong</strong>.</p>
</div>
```

Label is uppercase, ~2–4 words. Body is a single `<p>`.

---

## Bottom line (dark inverse panel)

```html
<div class="bottomline reveal d1">
  <div class="h2-kicker">The bottom line</div>
  <h2>One-line synthesised question or claim</h2>
  <p>Lead paragraph. Use <mark>mark</mark> for the load-bearing phrase and <strong>strong</strong> for names.</p>
  <p>Optional second paragraph.</p>
</div>
```

Reserve for a genuine single takeaway. `mark` and `strong` restyle automatically inside this panel.

---

## Player comparison cards

Wrap 2–4 `.player` cards in `.players` (a CSS grid). Each card sets two custom
properties inline: `--pc` (accent / top-border / dot colour) and `--vc` (verdict
box background). Use the brand vars `--oai` / `--ant` / `--ggl`, or `--accent`,
or any hex.

```html
<div class="players">
  <div class="player reveal d1" style="--pc:var(--accent);--vc:#e3ebfd">
    <div class="pname"><span class="pdot"></span>Subject name</div>
    <div class="ptag">one-line tagline · context</div>
    <div class="prow"><div class="pk">Label</div><div class="pv">Value, <strong>bold the verdict word</strong>.</div></div>
    <div class="prow"><div class="pk">Label</div><div class="pv">Value.</div></div>
    <div class="verdict"><strong>Takeaway:</strong> one or two sentences. <em>(Confidence note.)</em></div>
  </div>
  <!-- 1–3 more .player cards -->
</div>
```

`.pk` is a fixed 96px label column; `.pv` is the flexible value. Keep the same
set of `.pk` labels across all cards in a group so they read as a table.

---

## SVG charts

Charts are hand-coded inline SVG inside a `figure`. The viewBox is a plain pixel
grid — pick round numbers and map data onto it. **Never invent data**; if a
clipping has no real numbers, do not chart it.

### Shared figure shell

```html
<figure class="reveal d3">
  <div class="fig-kicker">Exhibit A · short kicker</div>
  <div class="fig-title">Plain-language chart title</div>
  <div class="legend">
    <span><span class="swatch" style="background:var(--accent)"></span>Series label</span>
  </div>
  <svg class="chart-svg" viewBox="0 0 620 270" role="img" aria-label="Describe the chart for screen readers.">
    <!-- chart body — see patterns below -->
  </svg>
  <figcaption>One-sentence interpretation, not a restatement of the title.</figcaption>
</figure>
```

`role="img"` + a real `aria-label` are mandatory.

### Bar chart coordinate pattern

Define a linear map from value to y. Example: a 0–80(%) axis on a viewBox where
`y=224` is 0 and `y=40` is 80 ⇒ `2.3 px per unit`. A bar of value `v`:
`height = v * 2.3`, `y = 224 - height`. Put the scale in a comment so it is checkable.

```html
<g>
  <line class="grid-line" x1="56" y1="40" x2="600" y2="40"/>
  <line class="grid-line dash" x1="56" y1="132" x2="600" y2="132"/>
  <line class="grid-line" x1="56" y1="224" x2="600" y2="224"/>
  <text class="ax-label" x="50" y="44" text-anchor="end">80</text>
  <text class="ax-label" x="50" y="228" text-anchor="end">0</text>
</g>
<!-- scale: 224 = 0, 40 = 80  => 2.3px per unit -->
<g class="bar-grp">
  <rect x="110" y="148.1" width="46" height="75.9" rx="3" fill="var(--accent)" style="animation-delay:.1s"/>
</g>
<text class="val-label" x="133" y="142" text-anchor="middle" fill="var(--accent)">33</text>
```

`.bar-grp rect` animates a grow-from-baseline; stagger with `animation-delay`.

### Line chart coordinate pattern

```html
<polyline class="trend-line" fill="none" stroke="var(--accent)" stroke-width="3.5"
  stroke-linecap="round" stroke-linejoin="round"
  points="92,195 360,140 560,30"/>
<circle cx="92" cy="195" r="5.5" fill="var(--paper)" stroke="var(--accent)" stroke-width="3"/>
<text class="val-label" x="92" y="183" text-anchor="middle" fill="var(--accent)">100</text>
```

`.trend-line` animates a left-to-right draw. If the polyline is much longer than
~620px of path, raise the `stroke-dasharray`/`stroke-dashoffset` in the
`.trend-line` rule proportionally, or the draw animation will clip.

### SVG text helper classes

`.ax-label` — small faint monospace (axis ticks). `.val-label` — bold monospace
(data values). `.grid-line` / `.grid-line.dash` — solid / dashed gridlines.

---

## Timeline

```html
<div class="timeline">
  <div class="tl-row reveal d1">
    <div class="tl-when">Now<small>mid-2026</small></div>
    <div class="tl-what">
      <span class="verdict v-good">Status badge</span>
      <p>One paragraph.</p>
    </div>
  </div>
  <!-- more .tl-row -->
</div>
```

`.tl-when` is a fixed 120px column (the `<small>` is an optional sub-label).
Badge variants: `.v-good` (green), `.v-watch` (amber). Stacks vertically under 600px.

---

## Animation classes

Add `reveal d1`…`d4` to structural blocks for a staggered fade-in. `d1`–`d4` are
increasing delays; reuse `d1` once the visible run resets (e.g. first card of a
new section). All animations are disabled under `prefers-reduced-motion: reduce`.
