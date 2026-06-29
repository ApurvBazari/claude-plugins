# Changelog

## 1.4.1 — 2026-06-29

- fix: `lens:render-review` is now model-invocable — dropped `disable-model-invocation: true` (kept `user-invocable: false`, matching `walkthrough:render`). The skill is dispatched by an orchestrator's subagent (e.g. matali's `walkthrough-renderer`) via the Skill tool; `disable-model-invocation` hid it from *all* model/subagent invocation, so the orchestrator path silently degraded to a generic render instead of the lens-grade document. The skill stays hidden from the user `/` menu.

## 1.4.0 — 2026-06-26

- feat: pure render entrypoint — new internal `lens:render-review` skill takes a `review-findings` object (plus optional `priorFindings`, a `diffRef`, and intent) and renders the interactive HTML review document via `walkthrough:render`, writing ONLY the output path. No lens state, no recompute, no task list — an orchestrator (matali) that owns persistence calls it after `lens:engine`.
- feat: `lens:engine` compute-only return now optionally carries a top-level `adherence: { specItems, planSteps }` (the `spec-adherence`/`plan-adherence` side-output) so an orchestrator can render the full met/partial/missing matrix without re-deriving it. Field-additive; omit-empty.
- note: backward-compatible — `adherence` absent ⇒ behavior byte-identical to 1.3.0. The `review-findings` schema gains an optional `adherence` block (field-additive superset); `render-review` is a new skill, not a change to `engine`/`review`.

## 1.3.0 — 2026-06-21

- feat: programmatic finder injection — `lens:engine` accepts an additive `injectedFinders` arg (`Array<{ agent, dimension, label?, readonly: true }>`) so a programmatic caller (matali) can dispatch a read-only finder at call time. Injected finders run at ANALYZE alongside the `.claude/lens/settings.md` project tier and are handled identically — read-only enforced at the boundary, normalized, deduped, adversarially verified, and counted toward the §8 fan-out cap. The `agent` resolves via the Agent-tool registry and may be plugin-qualified, so a caller ships the finder in its own plugin (no project-local copy).
- feat: the `verifier` now gives the `simplify` dimension a judgment default with a real-signal gate (keep only if the cited violation signal is real at the locus; refute when absent or the change is clearly warranted) — previously undefined.
- note: backward-compatible — `injectedFinders` absent or empty ⇒ behavior **byte-identical** to 1.2.0. The `review-findings` schema is untouched (`injectedFinders` is an engine input, not a schema field).

## 1.2.0 — 2026-06-21
- feat: programmatic intent injection — `lens:engine` accepts an additive `injectedIntent` arg (`Array<{ role: "spec" | "plan", name: string, content: string }>`) so a programmatic caller (matali) can hand spec/plan intent directly. INTENT §2 gains **rule 0** (highest priority): when `injectedIntent` is non-empty, the intent record is built **verbatim** from it — `content` is the full spec/plan markdown, `name` is the provenance tag (`sourceSpec`/`sourcePlan`), `role` selects the spec-adherence vs plan-adherence fan-out — and rules 1–4 (the `docs/superpowers/` correlation, latest-only fallback, and transcript reconstruction) are **skipped**. Injected intent is explicit and full-fidelity, so it does **not** set `degraded`.
- note: backward-compatible — `injectedIntent` absent or empty ⇒ behavior **byte-identical** to 1.1.0 (diff-correlated selection unchanged). The ANALYZE fan-out shape and the §8 adherence cap (≤8 adherence / ≤11 finders, prioritize→cap→`degraded`→name-skipped) are unchanged; the cap now applies source-agnostically to the injected set. The `review-findings` schema is **untouched** — `injectedIntent` is an engine input, not a schema field.
- harden: intent-doc content handed to the `spec-adherence`/`plan-adherence` agents is wrapped in `<untrusted-user-input>` data fences for **all** sources (injected `content` + file-read + transcript), closing a prompt-injection surface (PR #86 security audit, Medium). Framing-not-filtering: `\r`-stripped, **not** length-capped (preserves the verbatim contract), and the finder agents stay read-only.
- chore(test): quote-safe the `python3 -c` version checks in the lens belt (paths passed via argv, not interpolated into the Python literal) — PR #86 security audit, Low.

## 1.1.0 — 2026-06-19
- feat: in-session review task list — `/lens:review` surfaces its progress as a harness task list (one task per stage: `scope`/`intent`/`analyze`/`verify`/`reconcile`/`render`/`report`, plus `setup` on first run), the way `/onboard:start` shows its phases. The `review` skill owns the list and hands the engine `taskIds` for the four engine-owned stages; handed none (orchestrator/compute-only callers), the engine stays task-silent — its data-only contract is unchanged.
- fix: disambiguate empty-diff from clean review — the engine now returns an `emptyScope` discriminator (optional, field-additive) so a clean review that genuinely found nothing renders a ship / no-findings artifact instead of looking identical to "nothing to review". The standalone path keys its empty branch on `result.emptyScope`, not on an empty `findings[]`; the markdown fallback defines "render failure" concretely and renders empty `findings[]` gracefully (no empty severity sections).
- note: in-session visibility only — no durable run-progress and no cross-session resume (a review is single-shot). No walkthrough change; the `emptyScope` schema addition is field-additive (vicario's validator ignores it — only the dimension enum is co-owned).
- feat: multi-spec / multi-plan intent — the INTENT stage builds the intent record from *all* specs/plans Added or Modified in the branch diff (diff-correlated), not just the latest. ANALYZE fans out one `spec-adherence` per spec and one `plan-adherence` per plan, each tagging `sourceSpec`/`sourcePlan`; the engine merges across the fan-out.
- feat: grouped adherence — the render-model emits `adherence.groups[]` (one group per source spec/plan) when more than one spec/plan was reviewed; the markdown fallback renders one sub-section per spec/plan. Single-spec and headless renders are unchanged (flat `specItems[]`/`planSteps[]`).
- note: `review-findings` contract unchanged — `sourceSpec`/`sourcePlan` are finder side-outputs, not schema fields. Grouped HTML adherence requires `walkthrough` ≥ 1.1.0; the markdown fallback groups at any version.

## 1.0.0 — 2026-06-09
- feat: intent-grounded review — `/lens:review [target]` reviews the current session's diff against its spec and plan, in-session, catching a clean build of the wrong spec that diff-only review can't.
- feat: data-only engine (`skills/engine`, internal) — scope → intent → analyze → verify → dedup → rank, emitting the vicario-aligned `review-findings` schema (a versioned field-additive superset of vicario's).
- feat: adversarial verification — each candidate finding is refuted by an independent skeptic agent against real source; only unrefuted findings survive, and a finding that errors mid-verify is kept as "unverified — flagged".
- feat: 3-tier finder registry (built-in · adapter · project-custom) with read-only enforced at the boundary, plus 5 read-only adapters (silent-failure, types, comment, test, correctness 2nd-opinion), runtime-detected and skipped silently if absent.
- feat: render via `walkthrough:render` into a self-contained interactive HTML review, with a markdown fallback when walkthrough is absent.
- feat: state-aware re-review — `.claude/lens/review-state.json` classifies findings as fixed / open / new and tracks the severity trend across runs.
- fix: revert `line` + `votes.*` to integer for vicario type parity; unified 9-value dimension-enum docs that vicario adopts (Option D); pin integer types with a contract test.
- fix: set `degraded` when a finder/adapter returns null or fails; correct the unwired multi-skeptic-voting note; validate finder output before fan-in.
- fix: engine description states when-to-invoke not its pipeline (SK-04); plugin/marketplace descriptions trimmed under the 120-char cap.
- feat: least-privilege `tools` allowlist + model-per-role on the six finder/verifier agents.
- fix: review-files remediation — within-run id semantics (not cross-run); drop dangling authoring-guide ref; severity trend on recommendedEscalation; state written only after a successful render; v1.1 won't-fix fenced as not-yet-wired; finding-status vs verifier-status disambiguated; CLAUDE.md states the two-skill surface.
- feat: structured iteration chip — fixed/open/new now surfaces as an `iteration` field + chip + `iterationDelta` in the rendered review (engine schema untouched).
- feat: full markdown-fallback parity — narrative spine + capped annotated diff-hunks section.
- feat: adapter normalization spec — forcing wrapper-prompt + per-adapter maps for the 5 adapters (`references/adapter-dispatch.md`).
- feat: compute-only orchestrator return mode — when driven by an orchestrator (vicario/matali P5 REVIEW), reconcile returns `{findings, delta, severityTrend}` and writes nothing; the orchestrator owns persistence + render. Standalone `/lens:review` runs all five steps unchanged.
- feat: `delta` + `severityTrend` schema fields (optional, field-additive — vicario's validator still passes); per-finding `iteration` stays render-only per the engine-schema-untouched rule.
- feat: `acknowledged` (won't-fix) suppression wired in orchestrator mode — the caller supplies the input path lens's render couldn't; standalone path remains unwired (no input path).
