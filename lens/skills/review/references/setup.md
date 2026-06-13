# First-run setup — persist settings + the project finder registry

Guarded by SKILL Step 1: run this **only** when `.claude/lens/settings.md` is absent. On every later run,
just read `settings.md` — never re-prompt.

## Guard usage
This uses `AskUserQuestion`. Per `.claude/rules/ask-user-question-guard.md`: both questions below have a
**static, ≥2-option** list (they aren't built from a dynamic detection), so the single-option collapse
case can't occur and no padding/None guard is needed. Ask them as plain single-select questions.

## The two questions
Ask both (one `AskUserQuestion` call, two questions):

### Q1 — gitignore the `.claude/lens/` dir?
Review artifacts can contain session content. Default to gitignoring, but let teams share custom finders.

| Option | Effect |
|---|---|
| **Yes (all) (Recommended)** | Add `.claude/lens/` to `.gitignore` — nothing under it is tracked. |
| **Artifacts only — track the registry** | Gitignore the artifacts + state, but **track `settings.md`** so the team shares the custom finder registry. |
| **No** | Track everything; add nothing to `.gitignore`. |

On **Yes (all)** → add `.claude/lens/` to `.gitignore`.
On **Artifacts only** → add narrower entries that ignore the artifacts + state but keep `settings.md` tracked, e.g.:

```gitignore
.claude/lens/*
!.claude/lens/settings.md
```

On **No** → add nothing.

### Q2 — default output path
Where rendered reviews are written. Offer the default plus a couple of common alternatives (e.g.
`docs/reviews/`); the tool's built-in "Other" lets the user type any path.

| Option | Path |
|---|---|
| **`.claude/lens/` (Recommended)** | the default, alongside settings + state |
| **`docs/reviews/`** | a tracked docs location |
| (Other) | any path the user types |

## Persist to `.claude/lens/settings.md`
Write both choices + an initially-empty project-custom finder registry. Shape — YAML frontmatter plus a
prose body (a fenced YAML block is equally acceptable):

```markdown
---
gitignore: all          # all | artifacts-only | none
outputPath: .claude/lens/
finders: []             # project-custom finders (see below)
---

# lens settings

Project configuration for the lens review companion. Generated on first `/lens:review`.
```

The `finders:` list holds the **project tier** of the finder registry — each entry an
`.claude/agents/<name>.md` agent the engine dispatches at ANALYZE. Initially empty; a project adds entries
later (per `lens/skills/engine/references/finder-contract.md`):

```yaml
finders:
  - agent: my-custom-finder     # matches .claude/agents/my-custom-finder.md
    dimension: security         # closed enum (see finder-contract.md)
    label: injection-audit      # the finder's sub-category
    readonly: true              # required — read-only is enforced at the boundary
```

After writing `settings.md` (and the `.gitignore` entry if applicable), return to SKILL Step 2.
