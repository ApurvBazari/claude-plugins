---
name: render
description: Render a markdown design spec into a single self-contained interactive HTML page. Invoke with `/html-adr:render <path-to-spec.md>` and optional `--out <path>` / `--open` / `--no-overwrite` flags.
user-invocable: true
---

# /html-adr:render

Render a markdown design spec into an interactive HTML ADR.

## When to use

When the user asks to "render" or "visualize" a design spec, ADR, or markdown file under `docs/superpowers/specs/` or any markdown decision-record file. Triggers: "render this spec", "make an ADR HTML", "/html-adr:render".

## Pre-flight

1. Verify Node ≥ 20 is on PATH: run `node --version`. If `< 20` or missing, surface a clear error.
2. Verify the source file argument exists and ends in `.md`.
3. Check `${CLAUDE_PLUGIN_ROOT}/node_modules/` exists; if not, run `npm install --silent --prefix ${CLAUDE_PLUGIN_ROOT}` (one-time, ~30s) and stream output to the user.
4. Check `${CLAUDE_PLUGIN_ROOT}/assets/` has all expected vendored files (each ≥ 1KB).

## Run

```
node ${CLAUDE_PLUGIN_ROOT}/scripts/render-adr.mjs <source-md-path> [--out <out-path>] [--open] [--no-overwrite]
```

Default output path: source path with `.md` replaced by `.html` (sibling).

## Output

- On success: print `✓ rendered <source> → <output>` and the output absolute path.
- On failure: surface stderr verbatim. The script exits non-zero for invalid args, missing source, malformed frontmatter, or missing assets.

## Notes

- The rendered HTML is single-file and offline-portable. Open with any browser.
- Re-running overwrites by default; pass `--no-overwrite` to require explicit deletion first.
