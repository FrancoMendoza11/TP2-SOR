# `.tldr` JSON structure

A `.tldr` file is JSON with a file-format version, a serialized tldraw schema, and a flat array of records. The importer uses the schema to migrate the records. Schema sequence numbers and shape props are versioned, so do not invent them for a deliverable. Start from a `.tldr` exported by the target tldraw version when exact compatibility matters.

The top-level structure is:

```json
{
  "tldrawFileFormatVersion": 1,
  "schema": {
    "schemaVersion": 2,
    "sequences": "copy this object from a file exported by the target version"
  },
  "records": []
}
```

The string above is explanatory, not a valid `sequences` value. A valid version-2 schema uses an object of record-type sequence versions. Version-1 schemas use `storeVersion` and `recordVersions` instead. Keep the schema from an exported file intact unless the target SDK generated it.

## Common records

Each record has a unique `id` and `typeName`.

- A `document` record stores document-level settings.
- A `page` record stores a page name and its stacking `index`.
- A `shape` record stores a shape type, position, parent, stacking `index`, props, and metadata.
- A `binding` record links shapes. An arrow normally has a start binding and an end binding, each pointing from the arrow shape to a target shape.

Shape records use `typeName: "shape"` plus a `type` such as `geo`, `arrow`, `note`, `text`, or `frame`. The `parentId` is usually a page ID or frame ID. For children of frames, `x` and `y` are frame-relative.

These snippets show record fields only. They are not a complete importable document because valid props and schema versions come from the target tldraw release:

```json
{
  "id": "shape:step_load_config",
  "typeName": "shape",
  "type": "geo",
  "x": 240,
  "y": 160,
  "rotation": 0,
  "index": "a1",
  "parentId": "page:page",
  "isLocked": false,
  "opacity": 1,
  "props": {
    "w": 200,
    "h": 100,
    "geo": "rectangle",
    "color": "blue",
    "fill": "solid",
    "dash": "solid",
    "size": "m"
  },
  "meta": {}
}
```

```json
{
  "id": "binding:arrow_start",
  "typeName": "binding",
  "type": "arrow",
  "fromId": "shape:arrow_run",
  "toId": "shape:step_load_config",
  "props": {
    "terminal": "start",
    "normalizedAnchor": { "x": 0.5, "y": 0.5 },
    "isExact": false,
    "isPrecise": false
  }
}
```

Some versions may include other required properties. Use the current tldraw export and SDK documentation as the authority.

## IDs and stacking order

- Use IDs with the correct prefix, such as `document:document`, `page:page`, `shape:process_a`, and `binding:arrow_a_start`.
- Keep record IDs unique.
- `index` is a fractional-indexing key, not an integer counter. It is unique among siblings under the same parent. Use tldraw's index helpers in SDK code when possible.
- A key's leading letter determines the length of its integer component. For example, `a10` is invalid because the `0` becomes a trailing fractional digit; `b10` has a two-character integer component and is valid. Do not infer validity by checking the last character alone.

## Notes on app-created files

- A full `.tldr` includes one `document` record and at least one `page` record.
- Every shape parent must exist and be a page or a container that accepts child shapes.
- Bindings must reference existing shapes. For an arrow, the binding's `fromId` is the arrow and `toId` is the attached shape.
- Notes generated for the local renderer need `fontSizeAdjustment: 1`; a zero value can make the note's text invisible.
- Arrow `kind` must be `arc` or `elbow` in the renderer used by this skill.
- Current target import validation is stronger than local JSON checks. Open the file in tldraw.com when the user needs a deliverable guaranteed against the live target schema.

## References

- [tldraw file parser and serializer](https://github.com/tldraw/tldraw/blob/main/packages/tldraw/src/lib/utils/tldr/file.ts)
- [Shape indexing](https://tldraw.dev/sdk-features/shape-indexing)
- [Create an arrow and bindings](https://tldraw.dev/examples/create-arrow)
