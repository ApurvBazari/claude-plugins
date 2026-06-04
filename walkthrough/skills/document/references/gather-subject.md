# Gathering a Subject

`document` reads a subject's source files into the `subject-model`. The subject is named by the
command argument (a path, a plugin directory, or "marketplace"). README + manifest are **canonical** —
never invent content not grounded in the source.

## Routing

| Argument | Adapter | Canonical inputs |
|---|---|---|
| a plugin dir (contains `.claude-plugin/plugin.json`) | `adapters/plugin.md` | `plugin.json`, `README.md`, `skills/*/SKILL.md`, `agents/*.md`, `scripts/*.sh`, `CHANGELOG.md` |
| `marketplace` / repo root | `adapters/marketplace.md` | `.claude-plugin/marketplace.json`, root `README.md` |
| any other path/description | generic | the named files; map prose → `sections`, code → `examples`, structure → `nodes/edges` |

## Rules
- Read the README first; it is the authoritative narrative. Manifest fills structured fields
  (name, version, keywords, install).
- Cite `path:line` in `details[].where` only when verified by a real file read; otherwise cite
  `path` only or omit (same rule as `create`).
- Omit empty model fields — never stub (`authoring-guide.md` § 2).
- Do not run any subject code; read-only.
