---
name: doc-audit
description: Audit and surgically fix the marketplace's documentation so every shipped command is discoverable — checks each plugin README's Skills section against SKILL.md frontmatter, the root README's plugin list and command index, manifest/description sync, and docs-site parity. Use when docs may have drifted from the code, after adding or renaming a skill or plugin, or before a release.
disable-model-invocation: true
---

# /doc-audit — Documentation Completeness Auditor & Fixer

Audit the marketplace's docs against machine truth (SKILL.md frontmatter + manifests), then
**surgically** fix the mechanical gaps and **flag** the rest. Read-only detection lives in
`audit-docs.sh`; the edits below are applied by you, the model, only on the fix pass.

## Guard

This skill **edits files** (READMEs). It is user-invoked only. On a real run it will modify
plugin READMEs and the root README in the working tree — the user reviews via `git diff`.
Never run the fix pass outside a git working tree where changes can be reviewed/reverted.

## Step 1: Detect

Run the audit and read the full report:

```bash
bash .claude/skills/doc-audit/scripts/audit-docs.sh --format pretty
```

(Optionally `--root <dir>` to audit a different checkout, e.g. a worktree.)

## Step 2: Present the report

Summarise the findings grouped by severity (ERROR / WARN / INFO) and by layer. Include the
**coverage table** (command → documented?) so the user sees included-vs-omitted without asking.

## Step 3: Surgical fix pass (auto-fixable findings only)

Read `references/completeness-contract.md` for the exact rules and scaffold shape. Then, for each
auto-fixable finding, make the **smallest** edit that resolves it:

- `MISSING_SKILLS_SECTION` → add a `## Skills` section scaffolded from frontmatter.
- `CMD_NOT_IN_README` → insert one entry (scaffold shape) in canonical order.
- `MARKER_MISSING` → add ` *(destructive — user-invoked only)*` to that entry's header only.
- `PLUGIN_NOT_IN_ROOT` → add the plugin to the root "at a glance" table and command index.
- `ROOT_COUNT_STALE` → correct the plugin-count word/number.
- `ROOT_NO_CMD_INDEX` → add a central command index listing every plugin's user commands. If a command section already exists, extend it **in place** — never add a second index (the fix is idempotent: re-running must produce no further change).

**Surgical rule:** never rewrite an existing hand-written entry. Only add what is missing or
correct a marker/count. Preserve tables, prose, and ordering already present.

## Step 4: Flag the rest (no edits)

Report flag-only findings verbatim for the user to handle:
`PHANTOM_CMD`, `VERSION_MISMATCH`, `DESC_MISMATCH`, `PLUGIN_JSON_MISSING`,
`SITE_PAGE_MISSING`, `SITE_PAGE_STALE`. For the site findings, the instruction is
"run `/walkthrough:document <plugin>`".

## Step 5: Re-verify

Re-run the audit and confirm ERROR count is 0 and the only remaining items are the flag-only
findings you reported:

```bash
bash .claude/skills/doc-audit/scripts/audit-docs.sh --format pretty
```

Then tell the user to review `git diff` before committing.

## Key Rules

- Detection is deterministic and read-only; **all edits are yours**, applied surgically.
- Truth = SKILL.md frontmatter + manifests. Never invent a command not backed by a SKILL.md.
- Auto-fix only the codes listed in Step 3; everything else is flag-only.
- Leave existing hand-written documentation intact — add, don't rewrite.
