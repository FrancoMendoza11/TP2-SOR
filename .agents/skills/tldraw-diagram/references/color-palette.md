# Color palette

Use tldraw color tokens rather than custom hex values. Pick color by meaning, then use placement, size, labels, and line style for any extra distinction.

| Token | Semantic use | Practical note |
|---|---|---|
| `black` | Text, primary structure, neutral nodes | Default for labels and unaccented shapes. |
| `grey` | Secondary structure, boundaries, low-priority context | Good for frames and support relationships. |
| `blue` | Main path, primary action, active system | Use for the dominant flow. |
| `light-blue` | Supporting action or secondary system | Keep the main flow more prominent. |
| `green` | Success, allowed operation, completed output | Pair with a concrete success label. |
| `light-green` | Positive but secondary state | Use when green is already used for a primary result. |
| `red` | Failure, denial, error, blocker | Name the failure as well as coloring it. |
| `light-red` | Warning or lower-severity failure | Don't use it for a confirmed critical stop. |
| `orange` | Caution, intermediate state, pending work | Distinguish a warning from an actual failure. |
| `yellow` | Evidence, examples, callouts, notes | In tldraw it appears pale cream with an orange border. Don't use it to distinguish orange by hue alone. |
| `violet` | Abstract, AI, ML, or conceptual category | Reserve it for a consistent meaning. |
| `light-violet` | Secondary abstract or AI-related element | Use with violet as its primary variant. |

## Shape style

- Use `fill: 'solid'` for professional diagrams. It produces a light fill with a colored outline.
- Use `fill: 'semi'` for secondary emphasis and `fill: 'none'` for boundaries that should not cover other shapes.
- Use `fill: 'fill'` only for small markers that need saturated color.
- Use `dash: 'solid'` for known relationships, `dashed` for hypothetical/future links, and `dotted` for weak associations.
- Keep text color readable against the fill. Use `labelColor` where the shape type supports it.
