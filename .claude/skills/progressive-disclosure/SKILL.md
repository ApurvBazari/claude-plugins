---
name: progressive-disclosure
description: Apply progressive-disclosure discipline to a SKILL.md — measure size, identify inert content (prompt templates, schemas, long enumerations, long bash blocks), propose extractions, and rewrite the SKILL.md with reference stubs. Use when editing or creating a SKILL.md, or when an existing SKILL.md exceeds 100 lines.
user-invocable: true
---
# Progressive Disclosure — SKILL.md Slimming

Apply a reusable rubric for deciding what stays inline in a `SKILL.md` versus what gets pushed into `references/` (inert content) or `scripts/` (long bash). Goal: smaller always-loaded context per skill invocation, without losing fidelity.
## Guard

Target file path MUST match `**/skills/<name>/SKILL.md`. If the target is a `CLAUDE.md`, `README.md`, agent file, or hook script, abort with:

> Progressive-disclosure rubric is calibrated for SKILL.md only. Target `<path>` is not a SKILL.md; aborting.

The other file types have different audiences and different criteria.
## Step 1: Measure the file
Run:

```bash
TARGET="<path-to-SKILL.md>"
total_lines=$(wc -l < "$TARGET")
heading_count=$(grep -c '^##\? ' "$TARGET")
long_blocks=$(awk '/^```/{n++; if(n%2){start=NR}else{if(NR-start>20)print "  block ending line "NR" ("NR-start" lines)"}}' "$TARGET")
echo "File: $TARGET"
echo "Total lines: $total_lines"
echo "Headings: $heading_count"
echo "Code blocks > 20 lines:"
echo "$long_blocks"
```

If `total_lines <= 100`, tell the user the file is already under the soft threshold and ask whether to proceed anyway. Below the threshold, the rubric usually finds nothing worth extracting.

## Step 2: Identify extraction candidates

Walk every `## Step` section of the SKILL.md and apply the rubric:

| Pattern in SKILL.md | Threshold | Destination | Stub form |
|---|---|---|---|
| Verbatim prompt template (question text + option labels + per-option behavior) | > 10 lines | `references/prompts/<topic>.md` | `Use the prompt template at \`references/prompts/<topic>.md\` — verbatim, do not paraphrase.` |
| JSON / YAML schema example | > 15 lines | `references/schemas/<name>.md` | `See schema at \`references/schemas/<name>.md\`. Match output to this schema.` |
| Decision tables | > 10 rows | `references/tables/<topic>.md` | `Lookup table at \`references/tables/<topic>.md\` — apply per the headers there.` |
| Long enumeration of options or rules | > 10 items with multi-line explanations | `references/<topic>.md` | `Apply the rules documented in \`references/<topic>.md\`.` |
| Bash block | > 20 lines | `scripts/<name>.sh` (NOT references/) | `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh" <args>` |

NEVER extract:
- Step titles + 1-3 line step descriptions
- Numbered control flow (`Step 1:`, `Step 2:` …)
- `AskUserQuestion` call shapes ≤ 10 lines
- Short imperative instructions
- Decision tables ≤ 10 rows
- Bash blocks ≤ 20 lines
- Anything tagged as the control-flow contract

Produce a list: `{block-name, source-line-range, destination-path, reason}` per candidate.

## Step 3: Propose extractions via AskUserQuestion

Build the AskUserQuestion candidate list from Step 2's output. Honor the AskUserQuestion guard in `.claude/rules/ask-user-question-guard.md`:

- If `len(candidates) == 0`: tell the user "No extraction candidates above threshold" and stop.
- If `len(candidates) == 1`: convert to single-select Yes/No (`Yes, extract <block-name>` / `No, keep inline`).
- If `len(candidates) >= 2`: use single AskUserQuestion with `multiSelect: true`, one option per candidate. User can approve some, reject others.

Each option label MUST include the source step name and destination path so the user can decide without reading the rubric again. Example: `Step 9 retention prompt → references/prompts/retention.md`.

## Step 4: Write extracted files

For each approved extraction:

1. `mkdir -p` the destination directory.
2. Write the extracted content verbatim to the destination file. For bash to `scripts/`, prepend `#!/usr/bin/env bash` and the appropriate `set` line per `.claude/rules/shell-scripts.md` (utility scripts: `-euo pipefail`; scripts with an always-exit-0 contract: `-uo pipefail`). Make executable (`chmod +x`).
3. Replace the original block in the SKILL.md with the matching stub form from Step 2's rubric table. The stub MUST include either "verbatim" (reference is authoritative; do not paraphrase) or "summary" (reference is descriptive; paraphrase OK). Without this qualifier, a downstream reader cannot tell what is safe to adapt.
4. For bash extracted to `scripts/`, the SKILL.md invocation MUST use `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` per `.claude/rules/plugin-script-paths.md`. Bare relative forms are silently broken.

## Step 5: Verify and report

Re-measure the target and surface the delta:

```bash
new_lines=$(wc -l < "$TARGET")
delta=$((total_lines - new_lines))
pct=$(( delta * 100 / total_lines ))
echo "Before: $total_lines lines"
echo "After:  $new_lines lines ($delta removed, -$pct%)"
echo "Extracted to:"
for f in <list-of-new-files>; do
  echo "  $f ($(wc -l < "$f") lines)"
done
```

Show the diff summary, not the full diff. If the delta is < 5% of the original, surface a note: the file may not be a strong candidate for further extraction.

## Key Rules

- Never modify CLAUDE.md, README.md, agent files, or hook scripts — the rubric is calibrated for SKILL.md only.
- Control flow stays inline always — even if a `Step` is 50 lines, control flow is exempt.
- Bash > 20 lines goes to `scripts/` NEVER `references/`. Use `${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh` invocation form.
- Stub form must include "verbatim" or "summary" qualifier so readers know what's authoritative.
- Honor the AskUserQuestion guard: 0 candidates → skip; 1 candidate → single-select Yes/No; ≥2 → multiSelect.
- This skill must obey its own rubric — its own SKILL.md is ≤ 100 lines. If a future edit pushes it over, apply the rubric to itself.
