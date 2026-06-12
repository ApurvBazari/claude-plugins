# Finder contract — authoring a project-custom finder

A project can extend lens's review with its own finder agent (the **project tier** of the registry, in
`finder-registry.md`). A custom finder is an ordinary `.claude/agents/<name>.md` agent that plugs into the
engine's ANALYZE stage. To be registry-compatible it MUST satisfy four requirements.

## 1. Emit the `review-findings` finding shape

Each finding the agent emits must carry the **required** fields of a `review-findings` finding:

| Field | Value |
|---|---|
| `id` | a local id (`F1`, `F2`, … within your output — the engine reassigns within-run-stable ids) |
| `title` | one-line statement of the finding |
| `severity` | one of `critical` \| `high` \| `medium` \| `low` (**no `info`**) |
| `dimension` | one value from the closed enum (see §2) |
| `verified` | **always `false`** — the VERIFY stage owns the flip |

Useful **optional** fields: `file`, `line` (confirm by reading the file — never guess), `claim`, `detail`,
`suggestedFix`, `source` (your agent name), `label`, `tags[]`.

```json
{
  "findings": [
    {
      "id": "F1",
      "title": "Raw SQL string interpolated into the query",
      "severity": "high",
      "dimension": "security",
      "label": "sql-injection",
      "file": "src/db/users.ts",
      "line": 88,
      "claim": "User input is concatenated directly into the SQL text.",
      "verified": false,
      "source": "my-custom-finder"
    }
  ]
}
```

## 2. Pick a `dimension` from the closed enum + a free `label`

The `dimension` is the **closed 9-value enum** and may not be extended:

```
requirements  correctness  security  types  silent-failure  simplify  test  risk  comment
```

Your finer category (your finder's native taxonomy) goes in **`label`** (a free string) and/or `tags[]` —
never in `dimension`. Choose the closest dimension and put specificity in `label`.

## 3. Be read-only (findings-only)

The agent must **never** edit, write, stage, or commit. Grant it read-only tools only
(`Read`, `Grep`, `Glob`, and `Bash` for read-only inspection/repro). The engine **also** enforces
read-only at the dispatch boundary, but the agent must be authored findings-only — there is no write path
through a finder.

## 4. Register in `.claude/lens/settings.md`

Add an entry to the project finder registry so the engine dispatches it:

```yaml
finders:
  - agent: my-custom-finder     # matches .claude/agents/my-custom-finder.md
    dimension: security         # closed enum
    label: injection-audit      # your sub-category
    readonly: true              # required
```

## Adversarial verification

A custom finder's output is treated **exactly like a built-in finding**: it is deduped against all other
tiers by `(file, line, title)` and sent to the `verifier` for an adversarial refute pass. Bug/security/
correctness/test claims **default to refuted** when the skeptic can't confirm them — so emit findings you
can back with real source (cite a confirmed `file`/`line` and a concrete `claim`), or they won't survive
VERIFY.
