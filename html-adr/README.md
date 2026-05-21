# html-adr

Render a markdown design spec into a single self-contained interactive HTML page. The output has an extracted ADR header (status, decision, drivers, considered options, consequences), an auto-built overview graph, per-section widgets, and item-level side-panel drill-in.

## Install

The plugin is registered in the workspace marketplace. From this repo:

```
/plugin add html-adr
```

First invocation runs `npm install` inside `html-adr/` (one-time, ~30s).

## Usage

```
/html-adr:render docs/superpowers/specs/2026-05-20-foo-design.md
```

Renders next to the source as `2026-05-20-foo-design.html`. Add `--open` to open in your default browser.

## Requirements

- Node >= 20
- Git (optional — used for author + date provenance)
