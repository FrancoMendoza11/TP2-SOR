#!/usr/bin/env python3
"""Render a tldraw JSON file to PNG with a headless Chromium browser."""

from __future__ import annotations

import argparse
import base64
import json
import sys
import threading
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from playwright.sync_api import sync_playwright


HERE = Path(__file__).resolve().parent


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="path to a .tldr JSON file")
    parser.add_argument("--output", type=Path, help="PNG output path (default: beside the input)")
    parser.add_argument("--timeout", type=int, default=90000, help="browser timeout in milliseconds")
    args = parser.parse_args()

    source = args.file.expanduser().resolve()
    output = (args.output.expanduser().resolve() if args.output else source.with_suffix(".png"))
    if not source.is_file():
        print(f"ERROR: file not found: {source}", file=sys.stderr)
        return 1
    try:
        data = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: cannot parse {source}: {exc}", file=sys.stderr)
        return 1

    handler = partial(SimpleHTTPRequestHandler, directory=str(HERE))
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{server.server_port}/render_template.html"

    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(headless=True)
            page = browser.new_page(viewport={"width": 1800, "height": 1200}, device_scale_factor=1)
            page.set_default_timeout(args.timeout)
            page.on("pageerror", lambda exc: print(f"Browser error: {exc}", file=sys.stderr))
            page.add_init_script(f"window.__TLDR_DATA__ = {json.dumps(data, ensure_ascii=False)};")
            page.goto(url, wait_until="domcontentloaded", timeout=args.timeout)
            page.wait_for_function("window.__editorReady === true || window.__renderError", timeout=args.timeout)
            render_error = page.evaluate("window.__renderError || null")
            if render_error:
                print(f"ERROR: tldraw failed to load the diagram: {render_error}", file=sys.stderr)
                browser.close()
                return 1

            data_url = page.evaluate(
                """async () => {
                  const ids = [...window.__editor.getCurrentPageShapeIds()]
                  if (ids.length === 0) throw new Error('the selected page has no shapes')
                  const result = await window.__editor.toImage(ids, {
                    format: 'png', background: true, padding: 80, scale: 2
                  })
                  const blob = result.blob || result
                  return await new Promise((resolve, reject) => {
                    const reader = new FileReader()
                    reader.onload = () => resolve(reader.result)
                    reader.onerror = () => reject(reader.error)
                    reader.readAsDataURL(blob)
                  })
                }"""
            )
            browser.close()
    except Exception as exc:  # Playwright and browser errors need a concise CLI diagnostic.
        print(f"ERROR: render failed: {exc}", file=sys.stderr)
        return 1
    finally:
        server.shutdown()
        server.server_close()

    try:
        header, encoded = data_url.split(",", 1)
        if not header.startswith("data:image/png;base64"):
            raise ValueError("renderer returned a non-PNG image")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(base64.b64decode(encoded))
    except (AttributeError, ValueError, OSError) as exc:
        print(f"ERROR: cannot save PNG: {exc}", file=sys.stderr)
        return 1

    print(f"Rendered {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
