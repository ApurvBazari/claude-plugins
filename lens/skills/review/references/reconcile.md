# Reconcile — state-aware re-review

Re-running `/lens:review` on the same target should show **progress**, not a fresh wall of findings. The
reconcile step matches this run's engine findings against the prior run stored in
`.claude/lens/review-state.json`, labels each **fixed / still-open / new**, computes the **verdict trend**,
and writes the updated state back. The state file is the **only** write lens makes besides the rendered
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

## Verdict trend
Compare this run's `verdict` (derived from `recommendedEscalation`, see `review-model-assembly.md`) to the
prior run's stored verdict:

- **improving** — verdict softened (e.g. `block` → `fix`, `fix` → `ship`).
- **same** — unchanged.
- **regressed** — verdict hardened (e.g. `ship` → `fix`).

Pair it with the counts, e.g. `2 fixed · 1 new · 3 still-open` — this is the iteration delta surfaced in
the rendered doc as the per-finding iteration label (carried in each finding's detail/points per review-model-assembly.md; the renderer has no dedicated chip for this label) and the report.

## `review-state.json` shape
Keyed by **target**; per target a `verdict` + a `findings` map keyed by **fingerprint**:

```json
{
  "<target>": {
    "verdict": "fix",
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
A finding may carry `acknowledged: { reason }` (a "won't-fix" the human accepted). Acknowledged findings
**persist** in state and are **suppressed** on later runs (kept out of the rendered findings, but their
fingerprint is retained so they aren't re-surfaced as `new`):

```json
"<fingerprint>": {
  "status": "still-open",
  "acknowledged": { "reason": "Accepted: legacy path, refactor tracked in JIRA-123" }
}
```

## Write-back
After labeling, write the updated map back to `.claude/lens/review-state.json`: update `lastSeen` on
matched fingerprints, add new ones, mark unmatched priors `fixed`, carry forward `acknowledged` entries,
and store this run's `verdict`. This is the single state write — everything else lens does is read-only.
