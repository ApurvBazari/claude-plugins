# Inline Grill Fallback

Used by `forge:grill-spec` when `mattpocock-skills:grill-me` isn't installed. This is the floor — a minimal version of the same decision-tree walk. The full version is richer; install `mattpocock-skills` for it.

## Usage

This file is loaded by `grill-spec/SKILL.md § Step 3` when the external skill isn't available. The grill-spec skill walks the categories below, asking one focused question per category, applying answers back to `forge-state.json.context`.

## Conversational frame

Lead the inline grill with this exact framing:

> I'll walk through your spec one category at a time and ask one question per category. If a category doesn't apply (e.g., no auth in your project), I'll skip it silently. Answer briefly — this is meant to be fast.

## Category 1 — Scope sanity

Read `context.featureDecomposition.sprints[0].features` (the sprint-1 list). Ask:

> Looking at your Sprint 1 features ([N] items): [list 3-5 by name]. **If you had to ship in 2 weeks, which 1 feature would you cut first?** (This tells me whether the MVP is genuinely minimal or already over-scoped.)

Apply the answer:
- If they name a feature → mark it as `priority: "stretch"` in `featureDecomposition`.
- If they say "I wouldn't cut any" → log this; spec is tight.
- If they pick something that's not actually in sprint 1 → surface the inconsistency, force a resolution.

## Category 2 — Stack alignment

Read `context.stack` and `context.appDescription`. Ask one of (pick the most pointed):

- (Web app stack with no DB) → "Your description mentions [feature X] which sounds like it persists state. Is the no-DB choice intentional?"
- (Backend stack with no API) → "You picked [framework] but no API style. How will clients talk to this?"
- (CLI stack with deploy) → "CLI tools usually don't need a deploy target. Was that an intentional pick?"
- (None of these mismatches apply) → "Was [stack.framework] picked because the team knows it, or because it fits the problem? If the latter, what was the runner-up?"

Apply the answer to `context.stack.rationale` (string, free-text).

## Category 3 — Feature conflicts

Scan `context.featureDecomposition.sprints` for known conflict patterns:

| Pattern | Conflict |
|---|---|
| Feature mentions "login" but `auth.strategy === null` | Auth required but not configured |
| Feature mentions "real-time" or "live" but no websocket / SSE pattern | Architecture gap |
| Feature mentions "search" with >100k records target but no DB index plan | Perf gap |
| Feature mentions "upload" but no `storageStrategy` set | Storage gap |
| Feature mentions "email" but no provider/auth | Email infra gap |

If any pattern triggers, ask:

> **Conflict**: feature `[name]` implies [requirement], but your spec has [contradiction]. How do you want to resolve this?
>
> 1. [Auto-fix option] — e.g., add JWT auth as a default
> 2. Drop the feature
> 3. Park for Phase 1.5 deep research

Apply the resolution. If they pick "Park", append to `parkedQuestions[]` and signal grill-spec Step 4 to route back to Phase 1.5.

## Category 4 — Missing dependencies

Scan for canonical missing-dependency patterns:

| Has feature | Likely needs |
|---|---|
| User accounts | Email verification, password reset, account deletion (GDPR) |
| Payments | Refund flow, dispute handling, audit log |
| File upload | Size limits, type allowlist, virus scanning (if elevated security) |
| Multi-tenant | Tenant isolation tests, billing per tenant |
| Public API | Rate limiting, API key rotation, deprecation strategy |

If any pattern triggers (i.e., the project has feature X but lacks dependency Y in the feature list), ask:

> Your spec includes [X] but doesn't mention [Y]. Is that intentional (e.g., out of scope for v1) or an oversight?

Apply the answer:
- "Intentional" → log to `context.outOfScope[]` (string array of explicit non-features).
- "Oversight" → add as a sprint-2 feature in `featureDecomposition` (don't push it into sprint 1 — that would inflate the MVP).

## Category 5 — Security alignment

Read `context.securitySensitivity` and `context.deployTarget`. Ask one of:

- (`securitySensitivity: "elevated"` or `"high"`) → "Elevated/high sensitivity usually means SAST + dependency scanning + secrets management in CI. Is your team set up for that, or do we need to flag it as a sprint-1 setup task?"
- (Public deploy + no rate limiting in features) → "Anything user-facing on a public domain typically needs rate limiting from day one. Want me to add it to Sprint 1?"
- (Otherwise) → skip silently.

Apply the answer to `context.securityPlan` (free-text rationale + list of sprint-1 tasks added).

## Closing summary

After all applicable categories run, hand control back to grill-spec Step 4 (conflict resolution) with the updated context. Don't write to `forge-state.json` yourself — grill-spec owns the checkpoint.

## What this fallback intentionally does NOT do

The full `mattpocock-skills:grill-me` skill is more capable in three ways the inline fallback skips:

1. **Recursive decision-tree expansion** — full version drills into a branch indefinitely. Inline asks one question per category and moves on.
2. **Cross-category dependency analysis** — full version reasons about how an answer in category 2 changes the question space for category 4. Inline treats categories as independent.
3. **Per-question recommended answer** — full version provides the user with a recommended answer alongside each question. Inline lets the user answer cold.

If the user finds the inline fallback insufficient, the surfaced note in Step 2 already points them to install the upstream skill. Don't try to replicate the full pattern here — the floor is the floor.
