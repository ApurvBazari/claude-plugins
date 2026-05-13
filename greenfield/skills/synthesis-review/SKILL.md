---
name: synthesis-review
description: Greenfield Phase X.5 — per-phase synthesis review with HTML rendering and Approve/Adjust/Skip walking. Renders a styled HTML record of decisions, cross-checks dependencies against earlier phases, and walks the developer through per-section approval. Internal building block invoked by greenfield start after each major phase; not user-invocable.
user-invocable: false
---

# Synthesis Review Skill — Per-Phase Confirmation Gate

You are running the synthesis-review skill, the reusable Phase X.5 confirmation gate that runs after each major wizard phase in the 15-phase greenfield 3.x flow. Round 1 wires this in only for Phase 1.8 (after the CI/CD step, cicdAndDelivery). Rounds 2–6 will wire it in for dataArchitecture, apiIntegration, authSecurity, workflow, vision/personas/domain, featureRoadmap, and schemaDraftReview.

## Guard

This skill operates on the in-memory context object passed by the caller (typically `greenfield/skills/start/SKILL.md`). It expects three inputs:

- `phaseId` — e.g., `"cicdAndDelivery"`. Used to load the matching template and locate context.
- `context` — the v2 greenfield-state.json `context` object (with `phases.<phaseId>` populated by the upstream wizard step).
- `targetProjectRoot` — absolute path to the scaffolded project. Synthesis HTML and `dependencies.json` are written under `<targetProjectRoot>/docs/architecture/`.

If any of these are missing, halt with an error pointing the caller at this section. Do NOT prompt the developer for them — this skill never runs standalone.

## Overview

The skill produces three outputs per phase:

1. `<targetProjectRoot>/docs/architecture/<phaseId-lowercase>-<short-name>.html` — the synthesis record. Living architecture document.
2. `<targetProjectRoot>/docs/architecture/<phaseId-lowercase>-<short-name>-dependencies.json` — cross-phase dependency snapshot. Used by `visualize-graph.sh` and the freshness hook.
3. Mutations to `context.syntheses[phaseId]` — `{ approvedAt, adjustments[] }` recording the developer's per-section decisions.

The HTML rendering and decision walk happen across seven Steps below.

## Step 1: Load the per-phase template

Locate the per-phase template at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/templates/<phaseId-kebab>-<short-name>.html`. For Round 1: `cicd-and-delivery.html`.

If the template file does not exist, halt with an error:

> No synthesis template found for phase `<phaseId>` at `references/templates/`. This round may not have implemented synthesis for this phase yet. Do not fabricate sections — return control to the caller with `synthesisStatus: "no-template"`.

Also load the generic frame from `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/synthesis-template.html` and the composition strategies from `references/section-prompts.md`.

## Step 2: Render the synthesis HTML

Walk the per-phase template's sections. For each section:

1. Substitute placeholders with values from `context.phases[phaseId]`. Placeholder syntax is `{{phase.field.subfield}}`.
2. Look up `context.dependencies[phaseId]` — the list of paths this phase depends on (e.g., `["vision.willDeploy", "dataArchitecture.databaseHost"]`).
3. For each dependency, resolve the current value from `context.phases.<topicName>.<remaining-path>` and inject a cross-check note: "Assumes [dependency-path] = [value]." If the dependency was not yet captured at synthesis time, annotate "not yet captured" — do not block.
4. Run contradiction detection per `references/section-prompts.md § Contradiction detection`. Each rule fires only when both endpoints exist.
5. Render any developer-relevant notes (e.g., "you picked provider: gitlab-ci but Round 1 only emits GitHub Actions templates").

Splice the rendered body into the generic frame's `{{phase_body}}` placeholder. Fill in `{{phase_id}}`, `{{phase_name}}`, `{{captured_at}}` (current ISO timestamp), `{{phase_id_lower}}`, `{{phase_short_name}}`, and `{{git_sha}}` (short SHA of HEAD in `targetProjectRoot`).

Write the result to `<targetProjectRoot>/docs/architecture/<phaseId-lowercase>-<short-name>.html` via atomic `.tmp` + rename. Create `docs/architecture/` if missing.

Refer to `references/section-prompts.md` for the per-section composition strategy and the Round 1 CI/CD & Delivery section map.

## Step 3: Write the dependencies.json

Compose the dependencies record per the schema at `references/dependencies-schema.json`:

```json
{
  "schemaVersion": 1,
  "phase": "<phaseId>",
  "recordedAt": "<ISO timestamp>",
  "dependencies": [
    {
      "path": "vision.willDeploy",
      "value": "<snapshot of value at synthesis time>",
      "rationale": "<from context.dependencies metadata or section-prompts.md>"
    }
  ]
}
```

Write to `<targetProjectRoot>/docs/architecture/<phaseId-kebab>-<short-name>-dependencies.json` via atomic `.tmp` + rename.

## Step 4: Walk the developer through the synthesis

Tell the developer the HTML is ready:

> I've written the **{phaseId}** synthesis to `docs/architecture/{file}.html`. Opening it in your browser will help:
>
> `open docs/architecture/{file}.html`
>
> Walk through each section. For each, you have three options: **Approve** (looks correct), **Adjust** (needs change), or **Skip** (not relevant — give a one-line reason).

Iterate through the sections in order. For each section, ask via `AskUserQuestion` with three choices: Approve, Adjust, Skip.

- **Approve** — record `{ section, decision: "approved" }` in `context.syntheses[phaseId].adjustments`. Move on.
- **Adjust** — invoke the two-stage Adjust dialog (Step 5 below). After Adjust returns, the adjusted answer is written back into `context.phases[phaseId]` and an entry `{ section, decision: "adjusted", before, after, via }` is recorded.
- **Skip** — ask one follow-up: "Why skip?" The reason becomes the `note` in `{ section, decision: "skipped", note }`.

After every section is walked, set `context.syntheses[phaseId] = { approvedAt: <ISO>, adjustments: [...] }`.

## Step 5: Adjust dialog (invoked from Step 4 on "Adjust")

Refer to `references/adjust-dialog-protocol.md` for the full protocol. Summary:

1. Invoke `greenfield/skills/adjust-dialog/` via the Skill tool, passing `phaseId`, `sectionId`, the original value, the developer's stated intent, and all current `listedPhases`. The adjust-dialog skill runs a 5-category adversarial walk (Scope, Assumptions, Alternatives, Risks, Dependencies).
2. If the Skill tool errors (skill unavailable), fall back to the inline 3-question mini-dialog documented in `references/adjust-dialog-protocol.md § Fallback`.
3. Write the final adjusted answer back into `context.phases[phaseId]`. Record `via: "adjust-dialog" | "inline-fallback"`.

## Step 6: First-run freshness hook installation (one-time)

On the FIRST invocation of synthesis-review in a given project (detect by absence of `<targetProjectRoot>/.git/hooks/pre-commit` containing the marker string `# greenfield:synthesis-freshness`):

1. Read the template at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/pre-commit-freshness-hook.sh.tmpl`.
2. Substitute the architectural-file patterns based on `context.phases.stack.stack` (e.g., `src/**/*.ts` for Next.js, `prisma/**/*.prisma` for Prisma schemas). Patterns go into the `{{ARCH_PATTERNS}}` placeholder as a bash-array body.
3. Install at `<targetProjectRoot>/.git/hooks/pre-commit` (append if the file exists; create with `#!/usr/bin/env bash` shebang if not).
4. `chmod +x` the file.

Tell the developer:

> Installed a pre-commit hook at `.git/hooks/pre-commit` that warns when code changes without updating `docs/architecture/`. The warning is non-blocking — bypass with `git commit --no-verify` if needed.

Skip this Step on subsequent invocations.

## Step 7: Checkpoint and return

Write `context.syntheses[phaseId]` to `greenfield-state.json` via the standard atomic `.tmp` + rename pattern (see `start/SKILL.md` § State persistence).

Return control to the caller. The caller decides the next phase.

## Key Rules

1. **Operate on context, never solo** — this skill is `user-invocable: false`. If invoked directly, halt with an error pointing at `start/SKILL.md`.
2. **Atomic writes only** — both the synthesis HTML and the `dependencies.json` must use `.tmp` + rename to avoid corruption on interrupt.
3. **Never auto-adjust** — Adjust always returns to the developer at least once. Never silently accept the answer returned by adjust-dialog without developer confirmation.
4. **Cross-check dependencies on every section** — do not skip the "Assumes [topic-name] said Y" annotation even if the value looks fine. Surfacing the dependency IS the no-surprises gate.
5. **Skip needs a reason** — Skip without a note is not allowed. The note becomes the audit record.
6. **Template missing = halt, not fabricate** — if the per-phase template doesn't exist for the requested `phaseId`, return `synthesisStatus: "no-template"` cleanly. Do not invent sections.
7. **Preserve developer veto** — if the developer rejects the adjusted answer in Step 5, return to the original captured value unchanged and record `{ decision: "adjusted-then-reverted" }`.
8. **Freshness hook is install-once** — never overwrite an existing pre-commit hook. Append only, and only if the marker string is absent.
