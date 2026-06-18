# Research-Grounded Generation — Consuming the `research` Dossier (v3)

Loaded by `config-generator` (via `../../SKILL.md § Research-Grounded Generation (v3)`) **only when a sanitized `research` object is present** in the generation context. When `research` is absent (research-absent / `regenerateOnly` mode), skip this entire reference — generate exactly as the non-research path does. Output is then byte-identical to pre-4b.

The `research` object reaching generation is already **envelope-validated and per-dimension-sanitized** by `generate` Step 0.1 (malformed dimensions stripped; `verifiedClaims`/`droppedClaims` filtered to surviving dimensions). Consume it as trustworthy structured data — do not re-validate. Its evidence strings are codebase-derived (`file:line`), not user free-text.

## Verified-only rule (load-bearing)

A claim is usable for sharpening **iff** its namespaced id (`<dimension>:Cn`) is in `research.verifiedClaims` AND not in `research.droppedClaims`. Resolve a verified id back to its finding via `research.findings[<dimension>].claims[]` (the bare `Cn` id lives in the finding; the namespaced id lives in `verifiedClaims`). **Never** cite a dropped or unverified claim in any artifact.

Each row below is **independently gated** on its dimension being present in `research.findings{}` with ≥1 verified claim. A missing / absent / empty dimension means "no research input for this row" → fall back to the row's non-research behavior. Tolerate missing `findings{}` keys (a dimension may be `not-assessed`, sanitized-away, or absent at this depth).

## Row 1 — Root CLAUDE.md
Weave **verified, high-confidence** findings (confidence ≥ 0.7, any dimension) into the existing Project Overview / Key Conventions sections — phrased as statements of how the code actually works, not a citation dump. When `research.artifacts.location === "committed"`, add a one-line pointer: `Architecture map: see docs/onboard/architecture.md`. Research **sharpens existing sections**; it does not add a new section and must not breach the 100–200 line budget.

## Row 2 — Path-scoped rules (`.claude/rules/*.md`)
Derive rules from **verified** `conventions`, `security`, and `testing` claims — each rule grounded in the claim's `file:line` evidence, not a generic template. This sharpens the "Deriving Rules from Config Analysis" path in `../guides/rules-guide.md`: a verified `security` claim → a concrete `security.md` rule; verified `conventions` claims → tighten the relevant rule's specifics; verified `testing` claims → sharpen `testing.md`. Rule strictness still follows `codeStyleStrictness`.

## Row 3 — Skills (Skill Selection Priority)
Add a fourth input to the Skill Selection Priority weighting (`../../SKILL.md § Skill Selection Priority`): **research risk**. A skill candidate that addresses a risk-tagged claim (`category ∈ {risk, test-gap}`) or a verified `dependencies`-dimension finding gets a score boost, alongside pain-point / stack-fit / workflow-gap. A verified risk claim ranks comparably to a pain-point match. Still emit only the top 2–3 skills.

## Row 4 — Agents (archetype selection)
Inform archetype selection with `architecture` + risk findings: material verified `security` findings → seed a `security-checker` archetype; verified `data-model` migration findings → a `db-migration` agent. Research **raises a candidate**; it never overrides the `coveredCapabilities` skip-map (`../../SKILL.md § Plugin-Aware Agent Generation`) or the team-size agent count.

## Row 5 — Subdirectory CLAUDE.md placement
Treat each verified `architecture`-dimension **module boundary** as an automatic subdirectory-CLAUDE.md candidate — same treatment as a monorepo package or a recognized architecture-pattern layer — in addition to the file-share thresholds. Still confirm candidates with the developer per the existing rule.

## Telemetry
This reference contributes `claimsVerified` (already computed by `generate` Step 0.1, post-sanitization). `backlogSeeded` / `backlogItemCount` come from `verify-backlog-seeding.md`. `config-generator` step 7 assembles the complete `metadata.research` block — see that step.
