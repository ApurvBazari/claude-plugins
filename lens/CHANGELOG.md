# Changelog

## 1.0.0 — 2026-06-09
- feat: intent-grounded review — `/lens:review [target]` reviews the current session's diff against its spec and plan, in-session, catching a clean build of the wrong spec that diff-only review can't.
- feat: data-only engine (`skills/engine`, internal) — scope → intent → analyze → verify → dedup → rank, emitting the vicario-aligned `review-findings` schema (a versioned field-additive superset of vicario's).
- feat: adversarial verification — each candidate finding is refuted by an independent skeptic agent against real source; only unrefuted findings survive, and a finding that errors mid-verify is kept as "unverified — flagged".
- feat: 3-tier finder registry (built-in · adapter · project-custom) with read-only enforced at the boundary, plus 5 read-only adapters (silent-failure, types, comment, test, correctness 2nd-opinion), runtime-detected and skipped silently if absent.
- feat: render via `walkthrough:render` into a self-contained interactive HTML review, with a markdown fallback when walkthrough is absent.
- feat: state-aware re-review — `.claude/lens/review-state.json` classifies findings as fixed / open / new and tracks the verdict trend across runs.
- fix: revert `line` + `votes.*` to integer for vicario type parity; unified 9-value dimension-enum docs that vicario adopts (Option D); pin integer types with a contract test.
- fix: set `degraded` when a finder/adapter returns null or fails; correct the unwired multi-skeptic-voting note; validate finder output before fan-in.
- fix: engine description states when-to-invoke not its pipeline (SK-04); plugin/marketplace descriptions trimmed under the 120-char cap.
- feat: least-privilege `tools` allowlist + model-per-role on the six finder/verifier agents.
- fix: review-files remediation — within-run id semantics (not cross-run); drop dangling authoring-guide ref; severity trend on recommendedEscalation; state written only after a successful render; v1.1 won't-fix fenced as not-yet-wired; finding-status vs verifier-status disambiguated; CLAUDE.md states the two-skill surface.
- feat: structured iteration chip — fixed/open/new now surfaces as an `iteration` field + chip + `iterationDelta` in the rendered review (engine schema untouched).
- feat: full markdown-fallback parity — narrative spine + capped annotated diff-hunks section.
- feat: adapter normalization spec — forcing wrapper-prompt + per-adapter maps for the 5 adapters (`references/adapter-dispatch.md`).
