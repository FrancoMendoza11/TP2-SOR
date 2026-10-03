# Shape templates

These templates are for SDK code. Shape props vary by tldraw release, so omit optional props when the editor default is appropriate and validate against the installed SDK.

## Geo node

```ts
import { createShapeId, type Editor } from 'tldraw'

function addProcess(editor: Editor) {
  const id = createShapeId()
  editor.createShapes([
    {
      id,
      type: 'geo',
      x: 240,
      y: 160,
      props: {
        geo: 'rectangle',
        w: 200,
        h: 100,
        color: 'blue',
        fill: 'solid',
        dash: 'solid',
        size: 'm',
        font: 'sans',
      },
    },
  ])
  return id
}
```

## Unbound arrow

Use `arc` for a direct connection and `elbow` for a right-angle flowchart connection. Set the endpoints in the arrow's local coordinates.

```ts
const arrowId = createShapeId()
editor.createShapes([
  {
    id: arrowId,
    type: 'arrow',
    x: 440,
    y: 210,
    props: {
      start: { x: 0, y: 0 },
      end: { x: 180, y: 0 },
      kind: 'elbow',
      color: 'black',
      dash: 'solid',
      size: 'm',
    },
  },
])
```

## Arrow bound to two shapes

Bindings preserve connections when a user moves either node. Create the arrow and its bindings together:

```ts
const arrowId = createShapeId()
editor.createShapes([
  {
    id: arrowId,
    type: 'arrow',
    x: 0,
    y: 0,
    props: {
      start: { x: 0, y: 0 },
      end: { x: 200, y: 0 },
      kind: 'elbow',
      color: 'black',
      dash: 'solid',
      size: 'm',
    },
  },
])

editor.createBindings([
  {
    fromId: arrowId,
    toId: sourceId,
    type: 'arrow',
    props: {
      terminal: 'start',
      normalizedAnchor: { x: 0.5, y: 0.5 },
      isExact: false,
      isPrecise: false,
    },
  },
  {
    fromId: arrowId,
    toId: targetId,
    type: 'arrow',
    props: {
      terminal: 'end',
      normalizedAnchor: { x: 0.5, y: 0.5 },
      isExact: false,
      isPrecise: false,
    },
  },
])
```

## Frames and notes

Use the editor's shape defaults as a starting point. Frames need a meaningful `name`; notes work well for evidence such as logs or code. For SDK usage, create a shape with its ID and position, then update its props using the current version's prop types. For `.tldr` records, consult `json-schema.md` and preserve a current target export as the schema source.

Useful shape IDs should describe meaning, not order: `shape:audit_event_note` is easier to check than `shape:17`.
