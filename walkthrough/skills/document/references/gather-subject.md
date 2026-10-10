# Gathering a Subject

`document` reads a subject's source files into the `subject-model`. The subject is named by the
command argument (a path, a plugin directory, or "marketplace"). README + manifest are **canonical** —
never invent content not grounded in the source.

## Routing

| Argument | Adapter | Canonical inputs |
|---|---|---|
| a plugin dir (contains `.claude-plugin/plugin.json`) | `adapters/plugin.md` | `plugin.json`, `README.md`, `skills/*/SKILL.md`, `agents/*.md`, `scripts/*.sh`, `CHANGELOG.md` |
| `marketplace` / repo root with a `marketplace.json` | `adapters/marketplace.md` | `.claude-plugin/marketplace.json`, root `README.md` |
| a codebase whose architecture or system map is asked for; or a repository root with a build or deploy manifest that is neither of the two above | `adapters/system.md` | machine-read files first (manifests, deploy files, entry points, wiring), read by the `system-analyzer` and `system-verifier` agents under `system-reading.md`; prose last |
| any other path/description | generic | the named files; map prose → `sections`, code → `examples`, structure → `nodes/edges` |

## Rules
- Read the README first; it is the authoritative narrative. Manifest fills structured fields
  (name, version, keywords, install). **The system adapter is the one exception:** there, machine-read
  files beat prose, and a thing only the README mentions is at most inferred (`adapters/system.md`).
- Cite `path:line` in `details[].where` only when verified by a real file read; otherwise cite
  `path` only or omit (same rule as `create`).
- Omit empty model fields — never stub (`authoring-guide.md` § 2).
- Do not run any subject code; read-only.
