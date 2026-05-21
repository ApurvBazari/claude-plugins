# html-adr — internal conventions

Single-file static HTML renderer for design specs. Node + unified/remark/rehype.

## Pipeline

`spec.md → remark-parse → remark-frontmatter → remark-gfm → extract-adr → recognize-sections → build-graph → remark-rehype → rehype-slug → rehype-autolink-headings → rehype-highlight → render-templates → inline-assets → rehype-stringify → spec.html`

## Custom plugins (under `scripts/plugins/`)

| Plugin | Role |
|---|---|
| extract-adr | mdast → ADRFields with confidence + provenance, attached as `tree.data.adr` |
| recognize-sections | mdast H2 walk → `tree.data.sections = [{ type, node }]` |
| build-graph | sections + cross-refs → `tree.data.graph = { nodes, edges }` |
| render-templates | hast transformation: wrap each section's hast subtree in its widget template |
| inline-assets | hast pass: replace external `<link>`/`<script>` refs with inlined content from `html-adr/assets/` |

## Vendored assets

Pinned in `html-adr/assets/`. Refreshed via `scripts/update-vendored-assets.sh` with SHA256 verification.

## Tests

Run `npm test`. Update golden files with `npm run test:update-golden`.
