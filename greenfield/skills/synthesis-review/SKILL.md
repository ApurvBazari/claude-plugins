---
name: synthesis-review
description: Greenfield Phase X.5 — per-phase synthesis review with HTML rendering and Approve/Adjust/Skip walking. Renders a styled HTML record of decisions, cross-checks dependencies against earlier phases, and walks the developer through per-section approval. Internal building block invoked by greenfield start after each major phase; not user-invocable.
user-invocable: false
---

# Synthesis Review Skill — Per-Phase Confirmation Gate

You are running the synthesis-review skill, the reusable Phase X.5 confirmation gate that runs after each major wizard phase in the 20-phase greenfield 3.x flow. Round 1 wires this in for Phase 1.8 (cicdAndDelivery). Round 2 wires it in for architecturalFraming, dataArchitecture, apiIntegration, architecturalValidation. Round 3 wires it in for auth, privacy, security, runtimeOperations. Round 4 adds personas (Step 2.2) and domainModel (Step 2.7). Round 5 adds featureRoadmap (Step 16) and schemaDraftReview (Step 19). Round 6 will add workflow.

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

The skill produces four outputs per phase:

1. `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.html` — the synthesis record. Living architecture document (HTML executive summary).
2. `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.md` — markdown companion to the HTML. Written in parallel; independently authored from the same template pair.
3. `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>-dependencies.json` — cross-phase dependency snapshot. Used by `visualize-graph.sh` and the freshness hook.
4. Mutations to `context.syntheses[phaseId]` — `{ approvedAt, adjustments[] }` recording the developer's per-section decisions.

The HTML + markdown rendering and decision walk happen across seven Steps below.

## Per-phase template index

The table below lists the wizard steps this skill renders synthesis for, in the order they appear in `context-gathering/SKILL.md`. The Step 1 template loader expects each entry's template trio (HTML + MD + dependencies.json.example) to exist at `references/templates/` under the kebab-case name.

| Phase ID | Wizard Step | Templates | Notes |
|---|---|---|---|
| personas | Step 2.2 | `personas.html` + `personas.md` + `personas-dependencies.json.example` | 6 sections; Section 6 ("Decisions Driven Downstream") back-fills after downstream phases complete |
| architecturalFraming | Step 2.5 | `architectural-framing.html` + `.md` + `architectural-framing-dependencies.json.example` | Round 2.5 — topology, deploymentShape, scaleTarget, boundaryNotes |
| domainModel | Step 2.7 | `domain-model.html` + `domain-model.md` + `domain-model-dependencies.json.example` | 10 sections; sections 4 (Value Objects), 5 (Domain Events), 8 (Anti-Corruption) mode-gated (skip when domainFormat=ddd-lite OR depth=light); Section 10 back-fills |
| dataArchitecture | Step 3 | `data-architecture.html` + `.md` + `data-architecture-dependencies.json.example` | Round 2 |
| apiIntegration | Step 4 | `api-integration.html` + `.md` + `api-integration-dependencies.json.example` | Round 2 |
| auth | Step 5 | `auth.html` + `.md` + `auth-dependencies.json.example` | Round 3 |
| privacy | Step 6 | `privacy.html` + `.md` + `privacy-dependencies.json.example` | Round 3 |
| security | Step 7 | `security.html` + `.md` + `security-dependencies.json.example` | Round 3 |
| runtimeOperations | Step 8 | `runtime-operations.html` + `.md` + `runtime-operations-dependencies.json.example` | Round 3 |
| cicdAndDelivery | Step 11 | `cicd-and-delivery.html` + `.md` + `cicd-and-delivery-dependencies.json.example` | Round 1 |
| architecturalValidation | Step 15 | `architectural-validation.html` + `.md` + `architectural-validation-dependencies.json.example` | Round 2.5 — final cross-phase sign-off |
| featureRoadmap | Step 16 | `feature-roadmap.html` + `feature-roadmap.md` + `feature-roadmap-dependencies.json.example` | Round 5 — 6 sections; horizon + MVP boundary, epic tree, feature table, sprint-1 callout, sizing histogram, cross-cutting features |
| schemaDraftReview | Step 19 | `schema-draft-review.html` + `schema-draft-review.md` + `schema-draft-review-dependencies.json.example` | Round 5 — 3-panel layout (DB / API / Event drafts) plus cross-check warnings; renders auto-synthesized drafts and captures Approve/Adjust/Reject decisions |

If a future round adds a new phase template, append a row here and ensure the corresponding section composition notes land in `references/section-prompts.md`.

### Round 6 templates (R6 — 9 new phases + CI Draft Review)

| Phase | Template path | Step |
|---|---|---|
| search | `templates/search.{html,md}` | 7 |
| caching | `templates/caching.{html,md}` | 9 |
| realtime | `templates/realtime.{html,md}` | 10 |
| fileUploads | `templates/file-uploads.{html,md}` | 13 |
| payments | `templates/payments.{html,md}` | 15 |
| frontendArchitecture | `templates/frontend-architecture.{html,md}` | 22 |
| designSystem | `templates/design-system.{html,md}` | 23 |
| uxAccessibilityPerf | `templates/ux-accessibility-perf.{html,md}` | 24 |
| i18nL10n | `templates/i18n-l10n.{html,md}` | 25 |
| cicdAndDelivery (CI Draft Review) | `templates/ci-draft-review.{html,md}` | 20 |

### CI Draft Review (Step 20) — 3-panel auto-render flow

The CI Draft Review fires after `render-ci-drafts.sh` populates `phases.cicdAndDelivery.draftYaml`. Unlike other synthesis reviews (which render after Q-bank capture only), this review's three panels show:

- Panel 1 — Inputs: stage list, runners, deploy target, framework, stack.
- Panel 2 — Decisions log: each `adjustHistory[]` entry + cross-check warnings (`draftWarnings[]`) with `addressed` flags.
- Panel 3 — Rendered YAML: the actual rendered YAML output from the per-provider renderer.

**LLM-fallback gate:** when `draftFallback == true`, Approve is disabled until every warning in `draftWarnings[]` has `addressed = true` (CHECK-R6-8 enforces this hard).

## sourceRef rendering (Round 4)

When a synthesis HTML section displays an answer that has a `sourceRef` in its dependencies.json sidecar, render the source as a small visual link/badge next to the value. This makes upstream-loop provenance visible — readers can trace why a per-persona auth role decision exists by clicking through to the originating persona in `personas.html`.

### sourceRef shape

```jsonc
{
  "path": "auth.access[3].roles[0]",
  "value": "FieldAuditor",
  "sourceRef": { "phase": "personas", "id": "P1" },
  "rationale": "Per-persona authz mapping captured during Step 5 auth loop"
}
```

### HTML rendering

Append `<span class="source-ref">` next to the value. The anchor links to the originating phase's HTML in the project's `docs/adr/` directory.

```html
<tr>
  <td>FieldAuditor</td>
  <td>{{this.permissions}}</td>
  <td class="source-ref">[from <a href="{{this.sourceRef.phase}}.html#{{this.sourceRef.id}}">{{this.sourceRef.id}}</a>]</td>
</tr>
```

Mustache rendering pattern — wrap the source-ref column in `{{#if this.sourceRef}}...{{/if}}` so loops that produce static (non-looped) values render no badge.

### Markdown rendering

Append ` (from {{sourceRef.phase}}/{{sourceRef.id}})` in parentheses after the value, on the same line:

```markdown
- FieldAuditor (from personas/P1)
- Auditor (from personas/P2)
```

Same `{{#if this.sourceRef}}` guard applies — non-looped values render no parenthetical.

### When sourceRef is required

The state machine (`context-gathering/SKILL.md` § Auto-loop mechanic, step 4 — and § Render hooks for the downstream contract) writes a `sourceRef` entry for every looped fire — both `loopMode: always` AND `loopMode: hybrid-only` when the latter fires per-item under `mode.coupling = auto-loop`. Static fires (no `loopOver` OR hybrid-mode collapse) MUST NOT have a `sourceRef`; the rendering guard above skips the badge.

### sourceRef integrity check

During Approve walk, surface a warning if any answer has a `sourceRef` pointing to a phase that doesn't exist in `context.phases.*` (e.g., `sourceRef.phase = "personas"` but `personas` was skipped). The warning lists the offending value(s) and offers: "Continue and render badge as `[from personas/P1 — phase skipped]`" or "Strip sourceRef and re-render as static".

## Back-fill mechanic (Round 4)

Two synthesis HTMLs have a "Decisions Driven Downstream" section that is initially empty when the phase first renders:

- `personas.html` Section 6
- `domain-model.html` Section 10

These sections cannot be populated when the phase first runs synthesis-review — there are no downstream decisions yet. They back-fill **after** each downstream phase completes and runs its own synthesis-review.

### Trigger

After any downstream phase Approval (the synthesis-review skill returns `status: "approved"` for that phase), invoke `back-fill-downstream-section.sh` (script authored in T22). The script handles both personas Section 6 and domain-model Section 10 in one pass.

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/back-fill-downstream-section.sh" "$PROJECT_ROOT" "$APPROVED_PHASE_ID"
```

### What the back-fill writer does

1. Reads every downstream phase's `docs/adr/<phase>.dependencies.json` sidecar.
2. Filters entries by `sourceRef.phase`:
   - For personas back-fill: filter `sourceRef.phase == "personas"`.
   - For domain-model back-fill: filter `sourceRef.phase == "domainModel"`.
3. Aggregates entries grouped by downstream phase ID. Renders as:

   ```markdown
   ### Aggregated downstream decisions referencing this phase

   **auth** — 4 decisions referencing personas:
   - auth.access[0] → "FieldAuditor reads own audits" (sourceRef: P1)
   - auth.access[1] → "Reviewer reads all audits in own team" (sourceRef: P2)
   ...

   **privacy** — 2 decisions referencing personas:
   - privacy.dataAccess[0] → "FieldAuditor: own-only data scope" (sourceRef: P1)
   ...
   ```
4. Re-renders the phase's HTML and MD via the existing template, with the new Section 6 / Section 10 content slotted in. **Preserves all other sections' Approved state** — the back-fill does NOT trigger re-Approve walk for the originating phase. Approval state is sticky across back-fills.
5. Updates the phase's `.dependencies.json` to record the back-fill timestamp: `{ "lastBackFilledAt": "<iso8601>", "downstreamPhases": ["auth", "privacy", ...] }`.

### Idempotency

The back-fill writer is idempotent — running it multiple times with the same input set produces identical output. Each downstream phase Approval triggers a re-run; the writer detects no-change cases and exits without rewriting if nothing changed.

### Stale detection on back-filled sections

If a downstream phase that originally contributed to the back-fill is later Adjusted (its sourceRef-bearing values change or it's unwound via `/greenfield:pickup → Adjust mode`), the personas/domain-model HTML's `<p class="back-fill-note">` paragraph surfaces:

> *Back-filled at &lt;iso8601&gt;. Downstream phase `auth` was Adjusted after this back-fill — re-run synthesis-review on personas to refresh.*

The detection runs at Step 0 stale-check entry-guard for personas + domainModel: compare `dependencies.json.lastBackFilledAt` against every downstream phase's `approvedAt` timestamp. If any downstream phase's `approvedAt > lastBackFilledAt`, surface the stale note.

### Empty back-fill rendering

If a downstream phase has been Approved but contributes zero `sourceRef.phase == "personas"` (resp. "domainModel") entries, the back-fill writer records the phase ID in `dependencies.json.downstreamPhases[]` for traceability but does NOT add a row to the section. The section's empty-state message updates to:

> *N downstream phases have completed. None reference this phase yet. Sections back-fill as auto-looped phases capture per-persona/per-entity decisions.*

## Step 1: Load the per-phase template

Locate the per-phase template pair at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/templates/`:
- `<phaseId-kebab>-<short-name>.html` — HTML executive summary template
- `<phaseId-kebab>-<short-name>.md` — markdown companion template

For Round 1: `cicd-and-delivery.html` and `cicd-and-delivery.md`.

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

Write the HTML result to `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.html` via atomic `.tmp` + rename. Create `docs/adr/` if missing.

Then render the markdown companion: walk the `<phaseId-kebab>-<short-name>.md` template in the same pass, substituting the same placeholders (same `{{phase.field}}` syntax, same stale_block, same cross-check values). Write the result to `<targetProjectRoot>/docs/adr/<phaseId-kebab>-<short-name>.md` via atomic `.tmp` + rename.

Both the `.html` and `.md` files must be written before proceeding to Step 3. If a `.md` template does not exist (e.g., a future round-N phase), write only the HTML and log a warning `synthesisMarkdownStatus: "no-md-template"` in the return object — do not block.

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

Tell the developer the synthesis is ready:

> I've written the **{phaseId}** synthesis to:
> - `docs/adr/{file}.html` — HTML executive summary (open in browser for the styled view)
> - `docs/adr/{file}.md` — markdown companion (version-controlled details record)
>
> `open docs/adr/{file}.html`
>
> Walk through each section. For each, you have three options: **Approve** (looks correct), **Adjust** (needs change), or **Skip** (not relevant — give a one-line reason).
>
> Any adjustment you make will be reflected in both files.

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
4. Write the final adjusted answer back into `context.phases[phaseId]`. Record `via: "adjust-dialog" | "inline-fallback"`. After writing context, re-render the affected section in BOTH the `.html` and `.md` output files and overwrite them atomically (`.tmp` + rename). Both files must stay in sync after every adjustment.
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

On the FIRST invocation of synthesis-review in a given project, install two hook fragments. Detect first-run by checking whether `<targetProjectRoot>/.git/hooks/pre-commit` contains BOTH marker strings.

### 6a: Synthesis freshness hook

Marker: `# greenfield:synthesis-freshness`

If absent:

1. Read the template at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/pre-commit-freshness-hook.sh.tmpl`.
2. Substitute the architectural-file patterns based on `context.phases.stack.stack` (e.g., `src/**/*.ts` for Next.js, `prisma/**/*.prisma` for Prisma schemas). Patterns go into the `{{ARCH_PATTERNS}}` placeholder as a bash-array body.
3. Append to `<targetProjectRoot>/.git/hooks/pre-commit` (create with `#!/usr/bin/env bash` shebang if the file doesn't exist yet).
4. `chmod +x` the file.

### 6b: MD-HTML drift-check hook

Marker: `# greenfield:md-html-drift-check`

If absent:

1. Read the template at `${CLAUDE_PLUGIN_ROOT}/skills/synthesis-review/references/md-html-drift-check.sh.tmpl`.
2. Append to `<targetProjectRoot>/.git/hooks/pre-commit` (the file already exists after 6a). No substitution needed — this template has no placeholders.

### After both fragments are installed

Tell the developer:

> Installed two pre-commit hook fragments at `.git/hooks/pre-commit`:
> - **synthesis-freshness** — warns when code changes without updating `docs/adr/` synthesis records.
> - **md-html-drift-check** — warns when only one of a `.html`/`.md` synthesis pair is staged in the same commit.
>
> Both warnings are non-blocking — bypass with `git commit --no-verify` if needed.

Skip this entire Step on subsequent invocations (both markers present).

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
