---
name: synthesis-review
description: Greenfield Phase X.5 — per-phase synthesis review with HTML rendering and Approve/Adjust/Skip walking. Renders a styled HTML record of decisions, cross-checks dependencies against earlier phases, and walks the developer through per-section approval. Internal building block invoked by greenfield start after each major phase; not user-invocable.
user-invocable: false
---

# Synthesis Review Skill — Per-Phase Confirmation Gate

You are running the synthesis-review skill, the reusable Phase X.5 confirmation gate that runs after each major wizard phase in the 15-phase greenfield 3.x flow. Round 1 wires this in only for Phase 1.8 (after the CI/CD step, cicdAndDelivery). Rounds 2–6 will wire it in for dataArchitecture, apiIntegration, authSecurity, workflow, vision/personas/domain, featureRoadmap, and schemaDraftReview.

## Step 0: Stale-check entry-guard

Before rendering or walking any synthesis, check whether the incoming phase has already been approved and has since been marked stale.

Read `context.phaseStatus[phaseId].status`. If the value is `"stale"`:

1. Surface the stale notice to the developer via `AskUserQuestion`:

> The **{phaseId}** synthesis was previously approved, but a dependency has changed since then.
>
> **Reason**: {context.phaseStatus[phaseId].staleReason}
>
> The captured values in this synthesis may no longer reflect the current spec.
>
> Would you like to re-walk this phase?

Options:
- **Re-walk (Recommended)** — clear `staleReason`, set `context.phaseStatus[phaseId].status = "in-progress"`, continue to Step 1 normally.
- **Skip for now** — preserve the existing synthesis as-is. Return control to the caller with `synthesisStatus: "stale-deferred"`. The phase remains marked `stale` so the next entry picks it up again. Do NOT proceed to Step 1.

If the status is anything other than `"stale"` (including `"not-yet-walked"`, `"in-progress"`, `"approved"`, `"approved-with-noted-divergences"`, or the field is absent), proceed to Step 1 normally.

See `references/stale-detection.md` for the full entry-guard protocol and status enum.

---

## Guard

This skill operates on the in-memory context object passed by the caller (typically `greenfield/skills/start/SKILL.md`). It expects three inputs:

- `phaseId` — e.g., `"cicdAndDelivery"`. Used to load the matching template and locate context.
- `context` — the v2 greenfield-state.json `context` object (with `phases.<phaseId>` populated by the upstream wizard step).
- `targetProjectRoot` — absolute path to the scaffolded project. Synthesis HTML and `dependencies.json` are written under `<targetProjectRoot>/docs/adr/`.

If any of these are missing, halt with an error pointing the caller at this section. Do NOT prompt the developer for them — this skill never runs standalone.

## Overview

The skill produces three outputs per phase:

1. `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.html` — the synthesis record. Living architecture document.
2. `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>-dependencies.json` — cross-phase dependency snapshot. Used by `visualize-graph.sh` and the freshness hook.
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

Write the result to `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.html` via atomic `.tmp` + rename. Create `docs/adr/` if missing.

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

Write to `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>-dependencies.json` via atomic `.tmp` + rename.

## Step 4: Walk the developer through the synthesis

Tell the developer the HTML is ready:

> I've written the **{phaseId}** synthesis to `docs/adr/{file}.html`. Opening it in your browser will help:
>
> `open docs/adr/{file}.html`
>
> Walk through each section. For each, you have three options: **Approve** (looks correct), **Adjust** (needs change), or **Skip** (not relevant — give a one-line reason).

Iterate through the sections in order. For each section, ask via `AskUserQuestion` with three choices: Approve, Adjust, Skip.

- **Approve** — record `{ section, decision: "approved" }` in `context.syntheses[phaseId].adjustments`. Move on.
- **Adjust** — invoke the two-stage Adjust dialog (Step 5 below). After Adjust returns, the adjusted answer is written back into `context.phases[phaseId]` and an entry `{ section, decision: "adjusted", before, after, via }` is recorded.
- **Skip** — ask one follow-up: "Why skip?" The reason becomes the `note` in `{ section, decision: "skipped", note }`.

After every section is walked, set `context.syntheses[phaseId] = { approvedAt: <ISO>, adjustments: [...] }`.

## Step 5: Adjust dialog (invoked from Step 4 on "Adjust") + field-level diff capture

Refer to `references/adjust-dialog-protocol.md` for the full protocol. Summary:

1. Before invoking adjust-dialog, snapshot the current value for every field in the section being adjusted. Store as `beforeSnapshot = { <fieldPath>: <currentValue>, ... }`.
2. Invoke `greenfield/skills/adjust-dialog/` via the Skill tool, passing `phaseId`, `sectionId`, the original value, the developer's stated intent, and all current `listedPhases`. The adjust-dialog skill runs a 5-category adversarial walk (Scope, Assumptions, Alternatives, Risks, Dependencies).
3. If the Skill tool errors (skill unavailable), fall back to the inline 3-question mini-dialog documented in `references/adjust-dialog-protocol.md § Fallback`.
4. Write the final adjusted answer back into `context.phases[phaseId]`. Record `via: "adjust-dialog" | "inline-fallback"`.
5. **Capture the field-level diff**: compare `beforeSnapshot` against the updated `context.phases[phaseId]` to build a list of changed field paths. For each changed field, write an entry into `context.adjustmentDiffs[phaseId][sectionId]`:

   ```jsonc
   {
     "before": "<original value (scalar or object)>",
     "after": "<updated value>",
     "field": "<dot-path within the phase, e.g. architecturalFraming.topology>"
   }
   ```

   If a section involves multiple fields (e.g., section 1 of architecturalFraming captures both `topology` and `deploymentShape`), emit one `adjustmentDiffs` entry per changed field path. Unchanged fields are not included.

6. Collect all changed dot-paths as `changedFields[]` — this list is passed to the propagation step in Step 7.

The `adjustmentDiffs` structure is used by Step 7 for stale propagation and is available to future skills (e.g., `/greenfield:check`) for auditing what changed and when.

## Step 6: First-run freshness hook installation (one-time)

On the FIRST invocation of synthesis-review in a given project (detect by absence of `<targetProjectRoot>/.git/hooks/pre-commit` containing the marker string `# greenfield:synthesis-freshness`):

1. Read the template at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/pre-commit-freshness-hook.sh.tmpl`.
2. Substitute the architectural-file patterns based on `context.phases.stack.stack` (e.g., `src/**/*.ts` for Next.js, `prisma/**/*.prisma` for Prisma schemas). Patterns go into the `{{ARCH_PATTERNS}}` placeholder as a bash-array body.
3. Install at `<targetProjectRoot>/.git/hooks/pre-commit` (append if the file exists; create with `#!/usr/bin/env bash` shebang if not).
4. `chmod +x` the file.

Tell the developer:

> Installed a pre-commit hook at `.git/hooks/pre-commit` that warns when code changes without updating `docs/adr/`. The warning is non-blocking — bypass with `git commit --no-verify` if needed.

Skip this Step on subsequent invocations.

## Step 7: Propagate stale flags, then checkpoint and return

After the developer completes the section walk (all sections Approve/Adjust/Skip), and `context.syntheses[phaseId] = { approvedAt: <ISO>, adjustments: [...] }` is set:

### 7a: Update phaseStatus for the current phase

Set `context.phaseStatus[phaseId]`:
```jsonc
{
  "status": "approved",
  "approvedAt": "<same ISO as context.syntheses[phaseId].approvedAt>",
  "lastModified": "<now>",
  "staleReason": null
}
```

### 7b: Propagate stale to dependent phases

If any section was Adjusted (i.e., `context.adjustmentDiffs[phaseId]` is non-empty), collect all changed field dot-paths from the adjustmentDiffs entries and run the stale-propagation algorithm documented in `references/stale-detection.md § Propagation algorithm`.

For each approved downstream phase Q whose dependency list (from `context.dependencies[Q]`) includes one or more of the changed paths:

1. Set `context.phaseStatus[Q].status = "stale"`
2. Set `context.phaseStatus[Q].staleReason = "<phaseId>.<changedField> changed"` (first matching changed field)
3. Set `context.phaseStatus[Q].lastModified = <now>`

**Rules**:
- Only propagate to phases with `status === "approved"` or `"approved-with-noted-divergences"`. Skip `not-yet-walked`, `in-progress`, `stale`, and `requires-rework`.
- Do NOT propagate to the phase that was just approved (P itself).
- Propagation is NOT recursive in this round — only direct dependents of P are marked.

If N > 0 phases were marked stale, tell the developer:

> Marked **N** phase(s) stale because {phaseId} was adjusted:
> - {Q1}: "{staleReason}"
> - {Q2}: ...
>
> When you next enter those phases, I'll offer a re-walk prompt.

If N === 0, no output for this step (silent).

### 7c: Checkpoint

Write `context.syntheses[phaseId]`, `context.phaseStatus`, and `context.adjustmentDiffs[phaseId]` to `greenfield-state.json` via the standard atomic `.tmp` + rename pattern (see `start/SKILL.md` § State persistence).

Return control to the caller. The caller decides the next phase.

## Key Rules

1. **Operate on context, never solo** — this skill is `user-invocable: false`. If invoked directly, halt with an error pointing at `start/SKILL.md`.
2. **Atomic writes only** — both the synthesis HTML and the `dependencies.json` must use `.tmp` + rename to avoid corruption on interrupt.
3. **Never auto-adjust** — Adjust always returns to the developer at least once. Never silently accept the answer returned by adjust-dialog without developer confirmation.
4. **Cross-check dependencies on every section** — do not skip the "Assumes [topic-name] said Y" annotation even if the value looks fine. Surfacing the dependency IS the no-surprises gate.
5. **Skip needs a reason** — Skip without a note is not allowed. The note becomes the audit record.
6. **Template missing = halt, not fabricate** — if the per-phase template doesn't exist for the requested `phaseId`, return `synthesisStatus: "no-template"` cleanly. Do not invent sections.
7. **Preserve developer veto** — if the developer rejects the adjusted answer in Step 5, return to the original captured value unchanged and record `{ decision: "adjusted-then-reverted" }`. When a section is `adjusted-then-reverted`, do NOT include that field in `changedFields[]` for propagation — the final value is unchanged.
8. **Freshness hook is install-once** — never overwrite an existing pre-commit hook. Append only, and only if the marker string is absent.
9. **Stale entry-guard is always first** — Step 0 fires before any rendering (Step 1) or dependency loading. Never render or walk a stale synthesis without offering the re-walk choice.
10. **Propagation is NOT recursive** — only direct dependents of the adjusted phase are marked stale. If marking Q stale would logically also stale R, that happens when the developer re-walks Q and triggers a new adjustment event.
11. **`staleReason` captures the first matching field only** — if multiple changed fields in P affect Q, `staleReason` captures the first one. The developer can see all changes in the `adjustmentDiffs` record on re-walk.
12. **`stale-deferred` is ephemeral** — it is only used as a return value to the caller; do NOT write it to `context.phaseStatus[phaseId].status`. The status stays `"stale"` so the next entry picks it up again.
