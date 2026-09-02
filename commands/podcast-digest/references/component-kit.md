# Component kit — bespoke HTML blocks for podcast-digest pages

The `templates/digest-page.html` skeleton carries the **always-applicable** structure
(masthead, standfirst, per-category sections, `.dog` episode cards with takeaway
lists, sources, endnote). This file documents the **bespoke** components — the
editorial vocabulary that fits when the *content of the batch* supports it.

## The gate: when to reach for these

Unlike a clippings survey (unrelated articles, no single thesis), a batch of one
person's recent podcast listening **usually has a through-line** — a recurring theme,
a running argument, a chronology of events. So these components are **more often in
play** here than for clippings. Still gated, never decorative:

| Component | Use when… |
|---|---|
| `blockquote` pull quote | Almost always OK — once per page, to elevate the single best line. Attribute the speaker + show. |
| `bottomline` | The batch has a genuine synthesised takeaway (a real through-line). Common for a focused month; skip for a miscellaneous one. |
| `.players` grid | **2-4 subjects are directly comparable** on the same axes (rival models, competing tools, two sides of a debate) with real values from the transcripts. |
| `.timeline` | Several episodes form a **genuine chronology** (a sequence of releases/events, an arc). |
| `figure` + SVG chart | An episode (or the batch) carries **real quantitative data** worth plotting. Never fabricate numbers. |
| `.callout` | A caveat, correction, or "the thread under the story" note genuinely applies. |

All CSS classes are already defined in `digest-page.html`'s `<style>` block. Do not
add a separate stylesheet. Add `reveal d1`…`d4` to structural blocks for a staggered
fade-in (disabled under `prefers-reduced-motion`).

---

## Pull quote

```html
<blockquote class="reveal d1">Short, declarative line lifted or distilled from the strongest episode.
  <span class="attr">Speaker name &middot; Show name</span>
</blockquote>
```

One per page, placed high (right after the lead reads well). The `.attr` line is
optional but recommended for podcasts — attribution is the point.

---

## Bottom line (dark inverse panel)

```html
<div class="bottomline reveal d1">
  <div class="h2-kicker">The bottom line</div>
  <h2>One-line synthesised claim or question</h2>
  <p>Lead paragraph. Use <mark>mark</mark> for the load-bearing phrase, <strong>strong</strong> for names/shows.</p>
  <p>Optional second paragraph tying 2-3 episodes together.</p>
</div>
```

Reserve for a genuine single takeaway. `mark` and `strong` restyle automatically
inside this panel. Place near the end, before the sources.

---

## Player comparison cards

Wrap 2-4 `.player` cards in `.players` (a 2-col grid, collapses to 1 on mobile). Each
card sets `--pc` (accent / top-border / dot) and `--vc` (verdict box background)
inline. Use brand vars `--oai` / `--ant` / `--ggl`, `--accent`, or any hex. Keep the
same `.pk` labels across cards so they read as a table.

```html
<div class="players">
  <div class="player reveal d1" style="--pc:var(--oai);--vc:#dcf3ec">
    <div class="pname"><span class="pdot"></span>Subject name</div>
    <div class="ptag">one-line tagline · context</div>
    <div class="prow"><div class="pk">Price</div><div class="pv"><strong>value</strong></div></div>
    <div class="prow"><div class="pk">Benchmark</div><div class="pv">value</div></div>
    <div class="verdict"><strong>Takeaway:</strong> one or two sentences. <em>(Confidence note.)</em></div>
  </div>
  <!-- 1-3 more .player cards with the SAME .pk labels -->
</div>
```

Only build this from real values spoken in the transcripts. Flag preview-model
numbers as provisional in the verdict.

---

## Timeline

```html
<div class="timeline">
  <div class="tl-row reveal d1">
    <div class="tl-when">Early July<small>the flood</small></div>
    <div class="tl-what">
      <span class="verdict v-good">Status badge</span>
      <p>One paragraph. <strong>Bold</strong> the load-bearing figure.</p>
    </div>
  </div>
  <!-- more .tl-row -->
</div>
```

`.tl-when` is a fixed 120px column (the `<small>` is an optional sub-label). Badge
variants: `.v-good` (green), `.v-watch` (amber). Stacks vertically under 600px. Ideal
for a month of model releases or a sequence of events across episodes.

---

## SVG charts

Hand-coded inline SVG inside a `figure`. The viewBox is a plain pixel grid — pick
round numbers and map data onto it. `role="img"` + a real `aria-label` are mandatory.
**Never invent data**; if the batch has no real numbers, do not chart it.

```html
<figure class="reveal d3">
  <div class="fig-kicker">Exhibit A · short kicker</div>
  <div class="fig-title">Plain-language chart title</div>
  <div class="legend"><span><span class="swatch" style="background:var(--accent)"></span>Series label</span></div>
  <svg class="chart-svg" viewBox="0 0 620 270" role="img" aria-label="Describe the chart for screen readers.">
    <!-- bars/lines mapped from a documented scale, e.g.:
         scale: y=224 is 0, y=40 is 80  =>  2.3px per unit; bar height = v*2.3, y = 224 - height -->
    <g class="bar-grp"><rect x="110" y="148.1" width="46" height="75.9" rx="3" fill="var(--accent)"/></g>
  </svg>
  <figcaption>One-sentence interpretation, not a restatement of the title.</figcaption>
</figure>
```

Helper classes: `.ax-label` (faint mono ticks), `.val-label` (bold mono values),
`.grid-line[.dash]` (gridlines). `.bar-grp rect` grows from baseline; `.trend-line`
draws left-to-right (raise its `stroke-dasharray`/`offset` if the path exceeds ~620px).

---

## Callout

```html
<div class="callout reveal d1">
  <span class="label">⚠ The thread under the story</span>
  <p>One tight paragraph. Bold the key point with <strong>strong</strong>.</p>
</div>
```

Label is uppercase, ~2-4 words. Body is a single `<p>`. Good for the caveat that ties
the darker undercurrent of a batch together, or a "listen to this first" note.
