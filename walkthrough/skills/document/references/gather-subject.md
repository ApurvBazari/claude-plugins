# Gathering a Subject

`document` reads a subject's source files into the `subject-model`. The subject is named by the
command argument (a path, a plugin directory, or "marketplace"). README + manifest are **canonical** —
never invent content not grounded in the source.

The **request** is what the user asked to have drawn. It comes from the words after the subject that
are not an output path (your skill's Step 1 tells the two apart), or, when the skill was started by a
sentence instead of the slash form, from that sentence.

## Routing

| Argument | Adapter | Canonical inputs |
|---|---|---|
| a plugin dir (contains `.claude-plugin/plugin.json`) | `adapters/plugin.md` | `plugin.json`, `README.md`, `skills/*/SKILL.md`, `agents/*.md`, `scripts/*.sh`, `CHANGELOG.md` |
| `marketplace` / repo root with a `marketplace.json` | `adapters/marketplace.md` | `.claude-plugin/marketplace.json`, root `README.md` |
| a codebase whose architecture or system map is asked for; or a repository root with a build or deploy manifest that is neither of the two above | `adapters/system.md` | machine-read files first (manifests, deploy files, entry points, wiring), read by the `system-analyzer` and `system-verifier` agents under `system-reading.md`; prose last |
| any other path/description | generic | the named files; map prose → `sections`, code → `examples`, structure → `nodes/edges` |

**Precedence.** The rows are not tried from top to bottom. Decide in this order:

1. A request for the subject's architecture or system map routes to `adapters/system.md` whatever the
   subject is, a plugin directory or the marketplace included. That file lists the wordings ("When
   this adapter runs").
2. With no such request, a plugin directory routes to `adapters/plugin.md` and the marketplace to
   `adapters/marketplace.md`.
3. Only then does the repository-root rule apply: a subject that is neither of those, and is a
   repository root with a build or deploy manifest, routes to `adapters/system.md`. It needs no request.
4. Anything else takes the generic route.

## Rules
- Read the README first; it is the authoritative narrative. Manifest fills structured fields
  (name, version, keywords, install). **The system adapter is the one exception:** there, the reading
  rules come first, before any file of the subject; machine-read files beat prose; and a thing only
  the README mentions is at most inferred (`adapters/system.md`).
- Cite `path:line` in `details[].where` only when verified by a real file read; otherwise cite
  `path` only or omit (same rule as `create`). On the system adapter that read is the verifier's: an
  anchor it confirmed counts as verified, and you never re-read the file to confirm an anchor.
- Omit empty model fields — never stub (`authoring-guide.md` § 2).
- Do not run any subject code; read-only.
