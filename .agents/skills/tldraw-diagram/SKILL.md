---
name: tldraw-diagram
description: Create tldraw `.tldr` JSON files and tldraw SDK snippets that argue visually. Use when the user wants to visualize workflows, architectures, or concepts with tldraw.
---

# tldraw Diagram Creator

Generate `.tldr` JSON files (importable into tldraw.com / tldraw.dev) or tldraw SDK code (`editor.createShapes(...)`) that **argue visually**, not just display information.

**Setup:** See `README.md` for installation notes. Rendering requires the tldraw web app or SDK. See the **Render & Validate** section below.

## Customization

Colors and semantic styles live in `references/color-palette.md`. Read it before generating a diagram. tldraw ships a fixed semantic palette (`black`, `blue`, `green`, `red`, `orange`, `violet`, `light-blue`, `light-green`, `light-red`, `light-violet`, `yellow`, `grey`). You can't invent hex colors, so the palette file maps each semantic purpose to a tldraw color token.

---

## Core philosophy

**Diagrams should ARGUE, not DISPLAY.**

A diagram isn't formatted text. It's a visual argument that shows relationships, causality, and flow that words alone can't express. The shape should BE the meaning.

**The Isomorphism Test**: If you removed all text, would the structure alone communicate the concept? If not, redesign.

**The Education Test**: Could someone learn something concrete from this diagram, or does it just label boxes? A good diagram teaches. It shows actual formats, real event names, concrete examples.

---

## Depth assessment (do this first)

Before designing, determine what level of detail this diagram needs:

### Simple/conceptual diagrams

Use abstract shapes when:
- Explaining a mental model or philosophy
- The audience doesn't need technical specifics
- The concept IS the abstraction

### Comprehensive/technical diagrams

Use concrete examples when:
- Diagramming a real system, protocol, or architecture
- The diagram will be used to teach or explain
- The audience needs to understand what things actually look like

**For technical diagrams, include evidence artifacts**: real event names, sample JSON, actual API method names. tldraw's `note` shape (sticky note) and `text` shape are ideal for these.

---

## Two output modes

tldraw supports two workflows. Choose based on user intent.

### Mode A: `.tldr` file (default)

A JSON document that can be imported via **File → Open** on tldraw.com / tldraw.dev, or loaded into the SDK with `loadSnapshot()`.
- Best for: one-off diagrams, sharing, archiving, Obsidian / Notion attachments.
- Output: a single `.tldr` file.
- See `references/json-schema.md` for the full record structure.

### Mode B: SDK code snippet

TypeScript/JavaScript that calls `editor.createShapes([...])` inside a tldraw SDK app.
- Best for: users embedding tldraw in a React app, generating diagrams at runtime, or building custom tools.
- Output: a code block with `createShapes` / `createBindings` calls.
- See `references/shape-templates.md` for shape prop templates.

If the user didn't specify, ask: *"`.tldr` file to open in tldraw, or SDK code for a React app?"* Default to `.tldr` if they just said "make a diagram."

---

## tldraw shape vocabulary

tldraw has a smaller, more opinionated shape set than generic drawing tools. Use this mapping to choose the right shape for each concept:

| Concept | Shape type | `geo` variant (if geo) |
|---------|-----------|------------------------|
| Process, action, step | `geo` | `rectangle` |
| Start, input, origin | `geo` | `ellipse` or `oval` |
| End, output, result | `geo` | `ellipse` or `oval` |
| Decision, branch | `geo` | `diamond` |
| External system | `geo` | `cloud` |
| Data / storage | `geo` | `cylinder` (if needed) or `rectangle` |
| Comment, callout, evidence | `note` (sticky note) | — |
| Label, annotation | `text` (free-floating) | — |
| Container / group | `frame` | — |
| Connection | `arrow` | — |
| Freeform path | `line` or `draw` | — |
| Code snippet, JSON sample | `note` with monospace font (`mono`) | — |

**tldraw geo variants**: `rectangle`, `ellipse`, `triangle`, `diamond`, `pentagon`, `hexagon`, `octagon`, `star`, `rhombus`, `rhombus-2`, `oval`, `trapezoid`, `arrow-right`, `arrow-left`, `arrow-up`, `arrow-down`, `x-box`, `check-box`, `heart`, `cloud`.

---

## Visual pattern library

Map each concept to a pattern that mirrors its behavior. No uniform card grids.

### Fan-out (one-to-many)

Central `geo` with `arrow`s radiating to multiple targets. Use for: sources, root causes, hubs.

### Convergence (many-to-one)

Multiple `geo`s with arrows merging into one. Use for: aggregation, synthesis, funnels.

### Timeline

A horizontal/vertical `line` shape with small `geo` ellipses (~20px) as markers and `text` shapes as free-floating labels. No boxes around labels.

### Tree / hierarchy

`line` shapes as trunk + branches, `text` shapes as labels. Avoid boxing every node.

### Cycle

3–5 `geo`s arranged in a loop with arrows returning to the start. Use for: feedback loops, iterations.

### Assembly line

`geo` (input) → `geo` (process, wider) → `geo` (output), all connected with arrows. Use for: transformations.

### Grouped sections

Wrap related shapes in a `frame` with a descriptive `name`. Frames give you labeled regions without drawing borders manually.

### Evidence block

A `note` shape (sticky note) containing a code snippet or JSON sample, placed next to the element it explains. Use `font: 'mono'` for code.

---

## Container discipline

tldraw makes it easy to box everything. Resist the urge.

- Default to free-floating `text` shapes for labels, annotations, section titles.
- Use `geo` containers only when the shape carries meaning (decision diamond, process rectangle) or when arrows need to bind to it.
- Use `frame` to group related shapes. It's cleaner than manually drawing a big rectangle behind them.
- Use `note` (sticky) for evidence artifacts (code, JSON, quotes). Its colored background reads as "this is a concrete example."

**Target**: fewer than 30% of text elements inside containers.

---

## Color as meaning

Every color choice pulls from `references/color-palette.md`. tldraw's palette is semantic. Each token has a defined purpose:

- `black` / `grey`: neutral, structural
- `blue`: primary action, main flow
- `green`: success, output, positive
- `red` / `light-red`: error, blocker, warning
- `orange`: caution, intermediate state
- `violet` / `light-violet`: AI, ML, abstract
- `yellow`: evidence, notes, callouts (natural for `note` shape)
- `light-blue` / `light-green`: secondary/supporting variants

**Do not invent hex colors.** tldraw shapes use these named tokens only. If you need a color outside the palette, use `grey` and rely on size/position for emphasis.

---

## Style defaults

| Prop | Default | When to change |
|------|---------|----------------|
| `size` | `m` | `s` for dense labels, `l`/`xl` for headings |
| `font` | `draw` | `sans` for modern, `serif` for formal, `mono` for code |
| `dash` | `draw` | `solid` for clean/technical, `dashed` for hypothetical/future, `dotted` for weak connection |
| `fill` | `solid` | `semi` for subtle emphasis, `none` for outline-only, `pattern` for texture |
| `color` | `black` | Pull from palette based on semantic purpose |

Default to `font: 'draw'` and `dash: 'draw'` only if the user wants the classic tldraw hand-drawn aesthetic. For technical/professional diagrams use `font: 'sans'`, `dash: 'solid'`, and **`fill: 'solid'`**. Shapes without fills look like wireframes and are hard to read. Follow the principle: lighter fill + darker stroke for contrast.

**Arrow kind**: Only `'elbow'` and `'arc'` exist. There is **no** `'line'` kind (it throws a `ValidationError` that aborts the entire render). Default to `kind: 'elbow'` (right-angle connections) for flowcharts. For straight diagonal connections use `kind: 'arc'` with `bend: 0`.

---

## Layout principles

### Hierarchy through scale

tldraw shapes have `w` and `h` props. Suggested sizes:
- **Hero**: 300×150
- **Primary**: 200×100
- **Secondary**: 140×70
- **Small / marker**: 40×40

### Whitespace

The most important element gets the most empty space around it (≥200px).

### Flow direction

Use left→right or top→bottom for sequences. Use radial layout for hub-and-spoke. Don't mix directions.

### Alignment & centering

For vertical flowcharts, pick a center x-coordinate and align all main-flow shapes so their horizontal center sits on it: `x = center_x - w/2`. Offset side branches left or right. This creates a clean visual spine.

### Connections required

Position alone doesn't show relationships. If A relates to B, draw an `arrow`. For `.tldr` files, arrows can bind to shapes via a `binding` record. See `references/json-schema.md`. Use `normalizedAnchor: {x: 0.5, y: 0.5}` and `isPrecise: false` so tldraw auto-routes to the nearest edge midpoint.

---

## Multi-zoom architecture (comprehensive diagrams)

Comprehensive diagrams operate at three zoom levels simultaneously, like a map showing country borders and street names:

1. **Summary flow**: a compact overview strip at the top (e.g. a `line` shape with small ellipse markers and free-floating `text` labels) showing the whole pipeline at a glance.
2. **Section boundaries**: labeled regions grouping related shapes (phases, layers, swimlanes). Use a `frame`, or a large outline-only `geo` rectangle (`fill: none`, `color: grey`, lowest `index`) when arrows must pass through the region freely.
3. **Detail inside sections**: evidence artifacts (`note` shapes with `font: mono`), concrete examples, real names from specs.

Aim for all three levels in technical/teaching diagrams. The summary gives context, the sections organize, and the details teach.

---

## Hard-won gotchas (verified against the local renderer)

- **Arrow `kind`**: only `"arc"` and `"elbow"` are valid. `"line"` throws a `ValidationError` that aborts the whole render. Straight diagonal = `arc` + `bend: 0`.
- **Frame children are frame-relative**: a shape with `parentId: "shape:<frame-id>"` positions its `x`/`y` relative to the frame's top-left corner, not the page. Convert coordinates when parenting shapes into frames, or keep everything page-level and use an outline-only `geo` rectangle as the section boundary instead. This avoids clipping and coordinate conversion when arrows cross the border.
- **Arrow labels need room**: a label on a bound arrow visually swallows the line when the bound shapes are closer than ~150–200px apart. Give labeled arrows ≥200px of distance, or drop the arrow label and place a free-floating `text` beside the arrow instead.
- **`index` is a fractional index, not a counter**: valid keys are `a1`…`a9`, then `aA`…`aZ`, then `aa`…`az` (base62 after the leading `a`). A plain counter produces `a10`, `a20`, …, and a fractional part must never end in `0`. tldraw.com rejects such a key with `At shape(type = geo).index: Expected an index key, got "a10"`, and one bad record aborts the whole import. The local renderer never checks this, so the PNG looks perfect. With more than 61 shapes under one parent, go two digits (`b10`, `b11`, …).
- **`index` is also per-parent**: keys must be unique within the same `parentId`. The page and each frame are separate namespaces. Keep one counter per parent.
- **`fontSizeAdjustment` on `note` is a scale factor, not a pixel size**: use `1`. tldraw normally computes it in `onBeforeCreate`, but loading a finished file skips that step, so a stored `0` renders the label at zero size. The sticky note appears blank while its text sits untouched in the JSON.
- **`yellow` renders as pale cream with an orange stroke**. It looks close to `orange`. Don't rely on yellow-vs-orange to encode two different meanings in the same diagram.
- **No waypoints on arrows**: tldraw arrows have only start/end (plus `elbowMidPoint`/`bend`). Long routed connections around content can't be hand-waypointed like in other tools. Route via elbow arrows bound to specific edges (`normalizedAnchor` on the side you want, `isPrecise: true`), or accept a simpler path.
- **Author in the current tldraw.com v4 format** as documented in `references/json-schema.md`. The render harness auto-converts for its local engine (arrow `richText`→`text`, note `textFirstEditedBy` stripped, binding `snap` stripped). Never hand-convert to older formats.
- **Never use `autoSize: true` on hand-authored `text` shapes**: neither the renderer nor tldraw's import recomputes `w`/`h`, so text wraps at whatever `w` you gave it and gets clipped vertically to roughly one line. Always set `autoSize: false` with a generous explicit `w` (rule of thumb: char count × fontSize × 0.62, plus ~30% headroom; sizes are s=18, m=24, l=36, xl=44 px before `scale`). With `autoSize: false` the height is computed correctly from the wrapped content.
- **`fill: "fill"` is valid and gives saturated (non-pastel) fill**. Use it for small marker dots (traffic lights, timeline points), which look washed-out with `solid`. Keep `solid` for large shapes where pastel + colored stroke is the intended look.
- **Elbow outside-routing hugs the shapes**: with side-to-side precise anchors (e.g. right edge → right edge), the vertical pass runs only ~70–80px beyond the outermost bound edge. Clear that corridor of other shapes, or narrow them. For near-collinear elbow connections, place the precise anchor exactly on the start line (compute the fraction) or you get a small ugly jog.

---

## Design process

### Step 0: Assess depth

Simple/conceptual, or comprehensive/technical? Research actual specs for the latter.

### Step 1: Understand deeply

For each concept: what does it do? What connects to what? What would someone need to see?

### Step 2: Map to patterns

Map each major concept to a different visual pattern (fan-out, timeline, cycle, etc.). No uniform grids.

### Step 3: Sketch the flow

Mentally trace how the eye moves. There should be a clear visual story.

### Step 4: Generate output

- **Mode A (`.tldr`)**: Build the JSON from `references/json-schema.md` + `references/shape-templates.md`. For large diagrams, build one section at a time.
- **Mode B (SDK)**: Write `editor.createShapes([...])` calls using the templates.

### Step 5: Render & validate

See **Render & Validate** below.

---

## Large diagram strategy (`.tldr` mode)

For comprehensive diagrams, build the records array one section at a time. A full file easily exceeds token limits in one pass.

1. Create the base file with `tldrawFileFormatVersion`, `schema`, and the required `document` + `page` records.
2. Add shapes section by section. Use readable string IDs like `shape:trigger_rect`, `shape:arrow_fan_left`.
3. Namespace IDs by section prefix to avoid collisions.
4. Update `bindings` records as you add arrows that connect shapes across sections.
5. After all sections are in place, read through and verify every `fromId`/`toId` in bindings references a real shape.

---

## Render & validate (mandatory)

You cannot judge a diagram from JSON alone. After generating or editing a `.tldr`, render it to PNG, view the image, and fix what you see in a loop until it's right.

### Step 1: Validate the file

```bash
cd references && uv run python validate_tldr.py <path-to-file.tldr>
```

Run this before rendering. It checks what the renderer cannot: index keys, per-parent uniqueness, `fontSizeAdjustment` on notes, bindings pointing at real shapes, and arrow `kind`. These are faults that can make tldraw.com refuse a file silently. Exit code 1 means errors. Hints don't change it.

### Step 2: Render & view

```bash
cd references && uv run python render_tldraw.py <path-to-file.tldr>
```

This writes a PNG next to the `.tldr` file. Then use the Read tool on the PNG to view it.

The renderer launches headless Chromium, loads `render_template.html` (which imports tldraw from esm.sh), calls `editor.createShapes` + `editor.createBindings` with the records from your file, and exports to PNG with tldraw's `editor.toImage()` API. It needs network access on first run to fetch tldraw from esm.sh.

### The loop

1. **Render & view**: Run the script, then Read the PNG.
2. **Audit against your original vision**: Does the visual structure match the plan? Does the eye flow where you intended? Do hero elements dominate?
3. **Check for visual defects**:
   - Text clipped or overflowing a geo's bounds
   - Arrows missing their target shapes (binding IDs wrong, or `parentId` mismatch)
   - Shapes overlapping unintentionally
   - Frames not grouping what you expected
   - Color semantics unclear (errors don't look urgent, AI doesn't look distinct)
4. **Fix**: Edit the JSON. Common fixes:
   - Increase `w`/`h` on a `geo` when text is clipped
   - Adjust `x`/`y` to fix spacing
   - Recheck `fromId`/`toId` in bindings. They must reference real shape IDs.
   - Remap `parentId: "page:page"` if you renamed the page.
5. **Re-render & re-view**: Typically 2–4 iterations.

### Alternative: user opens it in the tldraw web app

If the headless renderer can't reach esm.sh (offline, restricted network), say: *"Open [tldraw.com](https://tldraw.com) → File → Open → pick the `.tldr` file."*

### Validate against the target

A clean PNG does not mean the file opens. The renderer runs tldraw v3 and builds the document through `editor.createShapes`, a path that never validates index keys and computes note font scaling itself. tldraw.com instead imports the file and validates every record. Both faults documented in the gotchas above rendered flawlessly and produced an empty document on tldraw.com.

`validate_tldr.py` covers the faults decidable without a browser. When you need certainty, or a fault it doesn't know, use the target's own live schema:

1. Open tldraw.com in a browser and let it finish loading. The app exposes `window.editor`.
2. Run each record through the real migration and validation:

```js
const e = window.editor, schema = e.store.schema;
const file = /* the parsed .tldr */;
const bad = [];
for (const rec of file.records) {
  const m = schema.migratePersistedRecord(rec, file.schema, 'up');
  if (m.type === 'error') { bad.push({ id: rec.id, stage: 'migrate', reason: m.reason }); continue; }
  try { schema.validateRecord(e.store, m.value, 'createRecord', null); }
  catch (err) { bad.push({ id: rec.id, stage: 'validate', msg: String(err.message) }); }
}
bad
```

The validator names the record and prop in plain text, where the import itself just fails quietly. To see the result, run `e.loadSnapshot({document: {schema: file.schema, store: Object.fromEntries(file.records.map(r => [r.id, r]))}})` on a scratch file.

**Two traps when doing this.** Don't build your own schema with `createTLSchema()` from a CDN copy of the library. A version mismatch reports `migrationFailed` for perfectly valid files. Don't judge a rig by one result. Run it against a file the target itself exported. If that one fails too, the rig is broken, not the file.

### Version compatibility

The local renderer uses tldraw v3 (via esm.sh), while tldraw.com runs v4+. The renderer's `__renderTldr` function automatically converts v4 props (arrow `richText` → `text`, strips `textFirstEditedBy` from notes, strips `snap` from bindings) so files authored for tldraw.com also render locally. Always author files using the current tldraw.com format described in `references/json-schema.md`. The renderer handles backward compatibility automatically.

### Shape prop validation gotchas

If the renderer errors with `ValidationError: At shape(type = X).props.Y: Unexpected property`, you used a prop that doesn't exist on that shape. To inspect real defaults for any shape, run this one-liner against the rendered harness:

```bash
cd references && uv run python -c "
from playwright.sync_api import sync_playwright
import pathlib, json
with sync_playwright() as p:
    b = p.chromium.launch(headless=True); page = b.new_context().new_page()
    page.goto('file://' + str(pathlib.Path('render_template.html').resolve()))
    page.wait_for_function('window.__editorReady === true')
    print(json.dumps(page.evaluate(\"() => window.__editor.getShapeUtil('arrow').getDefaultProps()\"), indent=2))
    b.close()
"
```

Replace `'arrow'` with the shape type you need defaults for.

### First-time setup

Run this once per machine, before authoring anything. Playwright being importable does not mean its browser is downloaded, and you don't want to discover that after building 40 shapes:

```bash
cd references
uv sync
uv run playwright install chromium
```

---

## Quality checklist

### Depth & evidence

1. Research done for technical content?
2. Evidence artifacts (real code/JSON in `note` shapes)?
3. Multi-zoom: overview + sections + details?

### Conceptual

4. Isomorphism: structure mirrors concept?
5. Each major concept uses a different pattern?
6. No uniform card grids?

### Container discipline

7. Free-floating `text` used for labels (not every text in a geo)?
8. `frame` used for grouping (not manual background rectangles)?
9. `note` used for evidence artifacts?

### tldraw-specific

10. All colors from `references/color-palette.md` (no custom hex)?
11. `font`, `dash`, `fill` consistent with the diagram's tone?
12. Arrow bindings connect to real shape IDs?
13. Frame `name` props set for grouped sections?

### Structural

14. Every relationship has an arrow?
15. Clear flow direction (left→right, top→bottom, or radial)?
16. Hero elements larger and more isolated?

### Technical

17. `validate_tldr.py` run and clean (exit 0) before judging the PNG?
18. Index keys are `a1`…`a9`, `aA`…`aZ`, `aa`…`az`, never ending in `0`?
19. Every `note` has `fontSizeAdjustment: 1`, not `0`?
20. `.tldr` file has `tldrawFileFormatVersion`, valid `schema`, and `records` array?
21. Exactly one `document` record and at least one `page` record?
22. Shape `parentId` points to a valid page or frame?
23. Every binding references existing shape IDs?
