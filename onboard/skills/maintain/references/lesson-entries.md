# Lesson entries (D7, D20)

The exact bytes `maintain-write.sh lesson` writes for `onboard:maintain` Step 4.4 — the script writes them, not the model, because `.claude/` is a protected path (owner decision 2026-09-27). This page is what to expect in the files and what `tests/onboard/test_maintain_write.sh` pins. `<id>`, `<text>`, `<summary>` and `<ref>` come from the lesson verbatim; `evidence.pointer` is never written.

## One entry

```
<!-- lesson:<id> -->
- <text>
  _evidence: <summary> (<ref>)_
```

Entries in a file are separated by one blank line. Append after the file's last entry; never reorder or edit existing entries.

## Untargeted: `.claude/rules/lessons.md`

No `paths:` frontmatter, so Claude Code loads it in every session. Created as:

```
# Lessons

<!-- lesson:L-7f3a -->
- All pricing math runs through decimal.js; round to 2dp only at the output boundary.
  _evidence: gate-1 steer (matali run 20260926-1412)_
```

## Path-targeted: `.claude/rules/lessons-<slug>.md`

`maintain-detect.sh --lesson-file <glob>...` names the file and says whether it exists. A new file is created with every glob of the lesson's `target.paths`, in the lesson's order, as a YAML list:

```
---
paths:
  - "apps/crm/src/lib/**"
---

# Lessons

<!-- lesson:L-7f3a -->
- All pricing math runs through decimal.js; round to 2dp only at the output boundary.
  _evidence: gate-1 steer (matali run 20260926-1412)_
```

An existing file is reused as is: append the entry, leave its frontmatter alone.

## File-targeted: a marker section

In the target `CLAUDE.md` or `.claude/rules/` file. When the section is missing, append it at the end of the file after one blank line:

```

<!-- onboard:lessons:start -->
<!-- lesson:L-2b44 -->
- CRM server actions return BusinessError, never throw.
  _evidence: owner note (matali run 20260926-1412)_
<!-- onboard:lessons:end -->
```

When it exists, insert the new entry directly before `<!-- onboard:lessons:end -->`, after one blank line following the previous entry.
