# Reconcile — state-aware re-review

Re-running `/lens:review` on the same target should show **progress**, not a fresh wall of findings. The
reconcile step matches this run's engine findings against the prior run stored in
`.claude/lens/review-state.json`, labels each **fixed / still-open / new**, computes the **severity trend**,
and (after a successful render) writes the updated state back. The state file is the **only** write lens makes besides the rendered
artifact (read-only contract).

## Fingerprint — match by meaning, not by line
A finding's identity is a **fingerprint**, never its raw line number (a finding that merely **moved** must
not be mistaken for fixed). The fingerprint is:

```
fingerprint = dimension
            + normalized(claim)          # lowercased, whitespace-collapsed, ids + line-numbers stripped
            + nearest stable context     # enclosing symbol (fn/class/section id), OR a short content
                                         #   hash of the surrounding lines — NEVER the raw line number
```

- **normalized claim** — lowercase the claim, collapse runs of whitespace, and strip volatile tokens
  (ids like `F3`, bare line numbers, hashes) so the same issue fingerprints identically across runs.
- **stable context** — prefer the enclosing symbol (function/class name, or a section id); when none is
  available, use a short hash of a few surrounding source lines. Both survive line shifts; the raw line
  number does not, so it is excluded by construction.

## Labeling
Match each new finding to a prior finding by fingerprint:

| Situation | Label |
|---|---|
| new finding's fingerprint matches a prior one | **still-open** |
| prior finding has no match this run | **fixed** |
| new finding has no prior match | **new** |
| match is **low-confidence** (partial fingerprint, fuzzy context) | **possibly-resolved — verify** — never assert `fixed` on a weak match |

Never re-flag a finding as **new** just because its lines moved — that is exactly what the stable-context
fingerprint prevents.

## Severity trend
Compare this run's **`recommendedEscalation`** (the 4-value `minor|moderate|major|critical`) to the prior
run's stored escalation — NOT the 3-value `verdict`, which **collapses** `major`+`critical` into `block`
and would therefore report a `critical → major` softening as "same":

- **improving** — escalation softened (e.g. `critical` → `major`, `moderate` → `minor`).
- **same** — unchanged.
- **regressed** — escalation hardened (e.g. `minor` → `moderate`).

Store both `recommendedEscalation` and the derived `verdict` — the verdict still drives the hero chip.

Pair it with the counts, e.g. `2 fixed · 1 new · 3 still-open` — the **iteration delta**, surfaced as the
session-model `iterationDelta` (the findings-section subhead in HTML; the verdict-header delta in markdown)
and per finding via the `iteration` field → the iteration chip.

## `review-state.json` shape
Keyed by **target**; per target a `verdict` + a `findings` map keyed by **fingerprint**:

```json
{
  "<target>": {
    "verdict": "fix",
    "recommendedEscalation": "moderate",
    "lastRun": "2026-06-09T14:32:00Z",
    "findings": {
      "<fingerprint>": {
        "status": "still-open",
        "firstSeen": "2026-06-08T10:00:00Z",
        "lastSeen": "2026-06-09T14:32:00Z",
        "severity": "high",
        "dimension": "correctness",
        "claim": "<normalized claim>"
      }
    }
  }
}
```

- `status` — the fixed/open/new label from this run (a `fixed` entry is retained one run so the delta is
  visible, then may be pruned).
- `firstSeen` / `lastSeen` — when the fingerprint first appeared and was last seen.

### v1.1 — acknowledged (won't-fix)

> **v1.1 — not yet wired.** v1 has **no input path** to set `acknowledged`: the render is non-interactive,
> so nothing in v1 can mark a finding "won't-fix" (mirrors the deferred multi-skeptic voting in
> `../../engine/references/pipeline.md`). The suppress logic below is the forward design; in v1 no finding
> is ever acknowledged.

A finding may carry `acknowledged: { reason }` (a "won't-fix" the human accepted). Acknowledged findings
**persist** in state and are **suppressed** on later runs (kept out of the rendered findings, but their
fingerprint is retained so they aren't re-surfaced as `new`):

```json
"<fingerprint>": {
  "status": "still-open",
  "acknowledged": { "reason": "Accepted: legacy path, refactor tracked in JIRA-123" }
}
```

## Orchestrator mode (compute-only)
When lens is driven by an **orchestrator** (e.g. vicario/matali's P5 REVIEW) instead of a human running
`/lens:review`, reconcile runs in **compute-only** mode: it RETURNS the reconciled object and **writes
nothing** — the **orchestrator is the single writer** of review state (it persists its own findings +
iteration history). This is the same compute-vs-write split the standalone path already uses (§Write-back),
with the write omitted because the caller owns persistence.

- The orchestrator **supplies the prior state** to reconcile against, so lens needs no `review-state.json`
  of its own in this mode.
- lens **skips the render** entirely — the orchestrator renders at its own human gate.
- The returned object carries:
  - `delta` — `{ fixed, new, stillOpen }` counts (the iteration delta).
  - `severityTrend` — `improving | same | regressed` per §Severity trend.
  - per-finding `iteration` — `fixed | still-open | new | possibly-resolved` per §Labeling (carried on the
    reconciled findings / render-model, not the engine schema).

## Write-back (after render only)
Reconcile **computes** the updated map (update `lastSeen` on matched fingerprints, add new ones, mark
unmatched priors `fixed`, carry forward `acknowledged` entries, and store this run's
`recommendedEscalation` + `verdict`) but does **not** write it here. The write to
`.claude/lens/review-state.json` happens **only after the render succeeds** (SKILL Step 5), so a failed
render never advances the state. This is the single state write — everything else lens does is read-only.
