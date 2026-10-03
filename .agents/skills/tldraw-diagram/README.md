# tldraw diagram skill

This workspace skill creates either an editable `.tldr` document or tldraw SDK code. Keep the Mermaid or text specification as the human-readable source when a diagram starts from one. Treat the `.tldr` file as the editable canvas copy.

## Local setup

The validator uses only Python's standard library. Rendering needs `uv`, Playwright, Chromium, and network access to load the tldraw SDK from esm.sh.

```bash
cd .agents/skills/tldraw-diagram/references
uv sync
uv run playwright install chromium
```

If the browser download fails, use the target app instead: open [tldraw.com](https://tldraw.com), choose **File → Open**, and select the `.tldr` file.

## Validate and render

Run from this skill's `references/` directory:

```bash
uv run python validate_tldr.py /path/to/diagram.tldr
uv run python render_tldraw.py /path/to/diagram.tldr
```

The renderer writes `diagram.png` beside the input file unless `--output` names another path. View the PNG before sharing the `.tldr` file. A clean render does not replace opening the file in tldraw.com when target-app compatibility matters.

## References

- `references/color-palette.md`: semantic color choices.
- `references/json-schema.md`: `.tldr` record layout and compatibility notes.
- `references/shape-templates.md`: SDK shape and binding examples.

The file format and shape props can change between tldraw releases. For the active target version, trust a `.tldr` file exported by that target and its own importer.
