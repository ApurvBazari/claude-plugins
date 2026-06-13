# Verification Procedure — Gate-1 + the adversarial VERIFY pass

This file defines how the engine turns raw specialist findings into a verified claim ledger. It runs two things in sequence: **Gate-1** (validate + normalize + namespace every finding) and **VERIFY** (one adversarial `research-verifier` pass over the union of claims). The engine — not the verifier — owns flipping `verified` and building `droppedClaims[]`.

## Gate-1: collect, validate, normalize, namespace

After the specialist fan-out (SKILL Step 3) returns, for each finding set:

1. **Collect** every specialist's returned object (some may be null / timed out — see Edge cases).
2. **Validate vs `research-findings.json`** — read the schema as the contract; opportunistically `python3 -c "import jsonschema; …"` for a hard check.
   - **Built-in dimension malformed** → **FAIL-LOUD**: abort the run before synthesis with the validation error (mirrors `config-generator`'s hard-fail). A built-in must conform.
   - **Custom specialist malformed** → **skip + warn**: drop that dimension, record the warning, continue.
3. **Mint namespaced ids.** Each finding's claims carry bare `^C[0-9]+$` ids. Rewrite each to `dimension:Cn` (e.g. `architecture:C1`, `security:C3`). This is what makes `verifiedClaims`/`droppedClaims` cross-references globally unambiguous — two specialists' `C1`s never collide.
4. **Build the union** — the flat list of all namespaced claims across all assessed dimensions. A `not-assessed` finding contributes zero claims.

```
findings[architecture] = {status:"assessed", claims:[{id:"C1",…},{id:"C2",…}]}
findings[security]     = {status:"assessed", claims:[{id:"C1",…}]}
                                  │  Gate-1 namespacing
                                  ▼
union = [ architecture:C1, architecture:C2, security:C1 ]
```

## VERIFY: one adversarial pass over the union

1. **Empty union** (no claims survived Gate-1 — e.g. every dimension `not-assessed`) → skip verify; `verifiedClaims = []`, `droppedClaims = []`.
2. **Dispatch `research-verifier` once** with the full namespaced union + `dispatchedAsAgent: true`, per `superpowers:dispatching-parallel-agents` (a single agent call here — the fan-out parallelism was the specialist stage).
3. The verifier returns **per-claim votes**: `[{ id:"dimension:Cn", refuted:bool, reason }]` — one vote per claim, refute-by-default and dimension-tuned (see `research-verifier.md`).

## The engine owns the flip

Aggregate the votes — the engine, not the verifier, writes the ledger:

| Vote | Engine action |
|---|---|
| `refuted: false` | Claim **survives** → its id appended to `verifiedClaims[]`. |
| `refuted: true` | Claim **dropped** → `{ id, reason }` appended to `droppedClaims[]` (the verifier's `reason` is recorded verbatim for transparency). |
| Vote missing for a claim in the union (verifier did not return a vote for it) | Claim **kept** → appended to `verifiedClaims[]` with the gap noted in the run log. A missing vote must not silently delete a claim. |
| Verifier reports an **error** in `reason` (`refuted:false` + an error message) | Claim **kept** → appended to `verifiedClaims[]`. **Errors are kept, never dropped** — a verifier failure must not delete evidence. |

```
verifiedClaims[] = [ id for each claim whose vote is refuted:false OR whose vote is missing/errored ]
droppedClaims[]  = [ {id, reason} for each claim whose vote is refuted:true ]
```

Both arrays carry the `dimension:Cn` ids minted at Gate-1, so they resolve unambiguously back to a claim inside `findings[dimension].claims[]`.

## Edge cases

| Case | Handling |
|---|---|
| Specialist returned null / timed out | Treat that dimension as `status:"not-assessed"` (no claims contributed); never fabricate. The run continues with partial findings. |
| Built-in finding malformed | FAIL-LOUD at Gate-1 (abort before synthesis). |
| Custom finding malformed | Skip + warn at Gate-1; continue. |
| Verifier itself errors on a claim | Claim kept (`verifiedClaims`), error noted — never silently dropped. |
| Verifier drops (refutes) every claim | Valid result: `verifiedClaims=[]`, `droppedClaims` lists them all with reasons. Synthesis still produces a dossier (with an empty verified set). |

The output of this stage is the pair `(verifiedClaims[], droppedClaims[])` plus the validated per-dimension `findings{}` — all three feed synthesis (`synthesis-and-dossier.md`).
