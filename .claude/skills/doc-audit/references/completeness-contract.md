# doc-audit completeness contract

**Truth sources:** each `SKILL.md` frontmatter (`name`, `description`, `user-invocable`,
`disable-model-invocation`) + file existence; `plugin.json` and `marketplace.json`.

| Skill class | Rule | Severity |
|---|---|---|
| `user-invocable` (default) | MUST appear in plugin README `## Skills` **and** the root command index | ERROR (`CMD_NOT_IN_README`) |
| `disable-model-invocation: true` | MUST carry a "(destructive / user-invoked only)" marker | WARN (`MARKER_MISSING`) |
| `user-invocable: false` (internal) | MAY be omitted from the user index; if documented, mark internal | INFO |
| Documented but no matching `SKILL.md` (phantom) | Flagged, never auto-deleted | WARN (`PHANTOM_CMD`, flag-only) |
| Plugin registered but absent from root README | — | ERROR (`PLUGIN_NOT_IN_ROOT`) |

## Auto-fixable vs flag-only

**Auto-fix (surgical — add only what's missing, never rewrite existing prose):**
`MISSING_SKILLS_SECTION` (scaffold from frontmatter), `CMD_NOT_IN_README` (insert entry in
canonical order), `MARKER_MISSING` (add marker to the entry's header), `PLUGIN_NOT_IN_ROOT`
(add row), `ROOT_COUNT_STALE` (correct the number word), `ROOT_NO_CMD_INDEX` (build the index).

**Flag-only (needs human / another tool):** `PHANTOM_CMD` (deleting prose is a human call),
`VERSION_MISMATCH` / `DESC_MISMATCH` / `PLUGIN_JSON_MISSING` (ambiguous which side is right),
`SITE_PAGE_MISSING` / `SITE_PAGE_STALE` (HTML is rendered by `/walkthrough:document`).

## Scaffold shape for a missing command entry

```
### `/<plugin>:<name>`<marker-if-destructive>

<description from SKILL.md frontmatter>
```

where `<marker-if-destructive>` is ` *(destructive — user-invoked only)*` when
`disable-model-invocation: true`, else empty. Place entries under `## Skills` in the order
the skills are listed by the audit. Leave existing hand-written entries untouched.
