#!/usr/bin/env python3
"""Check common structural errors in a tldraw .tldr file."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

BASE62 = re.compile(r"^[0-9A-Za-z]+$")
PREFIX = re.compile(r"^[a-z]")


def valid_index_key(value: Any) -> bool:
    """Check the fractional-index key shape used by tldraw.

    The prefix letter determines the integer-part width: `a` has one character,
    `b` has two, and so on. A fractional suffix may not end in zero. This is why
    `a10` is invalid while `b10` has a complete two-character integer part.
    """
    if not isinstance(value, str) or not PREFIX.match(value):
        return False
    if len(value) < 2 or not BASE62.match(value[1:]):
        return False
    integer_width = ord(value[0]) - ord("a") + 1
    if len(value) < 1 + integer_width:
        return False
    fractional_part = value[1 + integer_width :]
    return not fractional_part.endswith("0")


def validate(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["top-level JSON value must be an object"]

    if not isinstance(data.get("tldrawFileFormatVersion"), int) or data.get(
        "tldrawFileFormatVersion", 0
    ) < 1:
        errors.append("tldrawFileFormatVersion must be a positive integer")

    schema = data.get("schema")
    if not isinstance(schema, dict):
        errors.append("schema must be an object copied from a current tldraw export")
    elif schema.get("schemaVersion") == 2:
        sequences = schema.get("sequences")
        if not isinstance(sequences, dict) or not sequences:
            errors.append("schemaVersion 2 requires a sequences object")
        elif any(not isinstance(version, int) or version < 1 for version in sequences.values()):
            errors.append("schema sequences must map record types to positive integer versions")
    elif schema.get("schemaVersion") == 1:
        if not isinstance(schema.get("storeVersion"), int) or not isinstance(
            schema.get("recordVersions"), dict
        ):
            errors.append("schemaVersion 1 requires storeVersion and recordVersions")
    else:
        errors.append("schemaVersion must be 1 or 2")

    records = data.get("records")
    if not isinstance(records, list):
        return errors + ["records must be an array"]

    by_id: dict[str, dict[str, Any]] = {}
    duplicate_ids: set[str] = set()
    for position, record in enumerate(records):
        label = f"records[{position}]"
        if not isinstance(record, dict):
            errors.append(f"{label} must be an object")
            continue
        record_id = record.get("id")
        if not isinstance(record_id, str) or not record_id:
            errors.append(f"{label}.id must be a non-empty string")
        elif record_id in by_id:
            duplicate_ids.add(record_id)
        else:
            by_id[record_id] = record
        if not isinstance(record.get("typeName"), str):
            errors.append(f"{label}.typeName must be a string")

    for record_id in sorted(duplicate_ids):
        errors.append(f"duplicate record id: {record_id}")

    documents = [r for r in records if isinstance(r, dict) and r.get("typeName") == "document"]
    pages = [r for r in records if isinstance(r, dict) and r.get("typeName") == "page"]
    shapes = [r for r in records if isinstance(r, dict) and r.get("typeName") == "shape"]
    bindings = [r for r in records if isinstance(r, dict) and r.get("typeName") == "binding"]

    if len(documents) != 1:
        errors.append(f"expected exactly one document record; found {len(documents)}")
    if not pages:
        errors.append("expected at least one page record")

    parent_ids = {r.get("id") for r in pages if isinstance(r.get("id"), str)}
    frame_ids = {
        r.get("id")
        for r in shapes
        if r.get("type") == "frame" and isinstance(r.get("id"), str)
    }
    parent_ids.update(frame_ids)

    indexes_by_parent: dict[str, set[str]] = {}
    for record in [*pages, *shapes]:
        record_id = record.get("id", "<missing id>")
        parent_id = record.get("parentId")
        if record.get("typeName") == "shape":
            if not isinstance(parent_id, str) or parent_id not in parent_ids:
                errors.append(f"{record_id}: parentId must point to an existing page or frame")
        elif record.get("typeName") == "page":
            parent_id = documents[0].get("id") if documents else "document:document"

        index = record.get("index")
        if not valid_index_key(index):
            errors.append(f"{record_id}: invalid fractional index {index!r}")
            continue
        sibling_key = str(parent_id or "document:document")
        siblings = indexes_by_parent.setdefault(sibling_key, set())
        if index in siblings:
            errors.append(f"{record_id}: duplicate index {index!r} under parent {sibling_key}")
        siblings.add(index)

        if record.get("typeName") != "shape":
            continue
        props = record.get("props")
        if not isinstance(props, dict):
            errors.append(f"{record_id}: props must be an object")
            continue
        shape_type = record.get("type")
        if shape_type == "arrow":
            if props.get("kind") not in {"arc", "elbow"}:
                errors.append(f"{record_id}: arrow props.kind must be 'arc' or 'elbow'")
        if shape_type == "note" and props.get("fontSizeAdjustment") != 1:
            errors.append(f"{record_id}: note props.fontSizeAdjustment must be 1")
        if shape_type == "text" and props.get("autoSize") is True:
            errors.append(f"{record_id}: hand-authored text shapes must set autoSize to false")

    shape_ids = {r.get("id") for r in shapes}
    for binding in bindings:
        binding_id = binding.get("id", "<missing id>")
        from_id, to_id = binding.get("fromId"), binding.get("toId")
        if from_id not in shape_ids:
            errors.append(f"{binding_id}: fromId {from_id!r} does not point to a shape")
        if to_id not in shape_ids:
            errors.append(f"{binding_id}: toId {to_id!r} does not point to a shape")
        if binding.get("type") == "arrow":
            props = binding.get("props")
            if not isinstance(props, dict) or props.get("terminal") not in {"start", "end"}:
                errors.append(f"{binding_id}: arrow binding terminal must be 'start' or 'end'")

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="path to a .tldr JSON file")
    args = parser.parse_args()

    try:
        data = json.loads(args.file.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"ERROR: cannot read {args.file}: {exc}", file=sys.stderr)
        return 1
    except json.JSONDecodeError as exc:
        print(f"ERROR: invalid JSON at line {exc.lineno}, column {exc.colno}: {exc.msg}", file=sys.stderr)
        return 1

    errors = validate(data)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1

    print(f"OK: {args.file} passed structural checks")
    print("NOTE: open it in the target tldraw app to verify its live schema and appearance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
