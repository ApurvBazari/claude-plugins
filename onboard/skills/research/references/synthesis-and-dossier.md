# Synthesis & Dossier — assemble the object, Gate-2, and render the four artifacts

This is the engine's final stage. It assembles the canonical `research-dossier` object from the validated findings + the verifier ledger, validates it (Gate-2) before writing anything, asks the per-run artifact location, and writes the object plus (when location ≠ `none`) the four markdown artifacts. The engine is the **sole writer** — there is no synthesizer agent (the spec's writer-boundary deviation).

## Step 1: Assemble the `research-dossier` object

Build an object with the EXACT fields from `onboard/schemas/research-dossier.json`:

```jsonc
{
  "engineUsed": "subagent",            // ALWAYS "subagent" in this plan (Workflow backend deferred)
  "depth": "<minimal|standard|comprehensive>",   // the preset that ran
  "roster": {
    "builtins":         [ /* enabled built-in dimensions actually dispatched */ ],
    "disabledBuiltins": [ /* echoed from config — config-derived, ⊆ the enum */ ],
    "customSpecialists":[ /* names of custom specialists actually dispatched */ ]
  },
  "findings": {
    "architecture": { /* the validated research-findings.json object for this dimension */ },
    "<dimension>":  { /* …one entry per ASSESSED dimension; not-assessed dims may be recorded with empty claims */ }
  },
  "verifiedClaims": [ "architecture:C1", /* …survivor ids from VERIFY */ ],
  "droppedClaims":  [ { "id": "security:C3", "reason": "refuted: <verbatim verifier reason>" } ],
  "wizardInferences": {
    /* per wizard-inference-map.md — each field {value, evidence[], confidence}; autonomyLevel NEVER inferred */
  },
  "artifacts": {
    "location": "<committed|local|none>",   // from the per-run prompt (Step 4)
    "written":  [ /* paths actually written — filled AFTER the writes */ ],
    "html":     null                        // ALWAYS null in this plan (HTML render deferred)
  }
}
```

- `findings` keys are dimension names; each value is the dimension's validated `research-findings.json` object (so `findings.architecture.claims[*].id` are the bare ids; the namespaced ids live only in `verifiedClaims`/`droppedClaims`).
- `verifiedClaims` / `droppedClaims` come straight from `verification-procedure.md`.
- `wizardInferences` is derived per `wizard-inference-map.md`.

## Step 2: Gate-2 — validate the assembled object BEFORE any write

Validate the assembled dossier against `onboard/schemas/research-dossier.json` (read the schema as the contract; opportunistically `python3 -c "import jsonschema; …"`).

- **Fails validation** → **FAIL-LOUD** with the validation error; refuse to write a malformed object. (`engineUsed`/`depth`/`location` enums, the `roster.builtins` required field, and the `droppedClaims[].{id,reason}` shape are the usual offenders.)
- **Passes** → proceed to Step 3.

Gate-2 is a hard pre-write gate: nothing reaches disk until the object is schema-valid.

## Step 3: Ask the per-run artifact location

Prompt the user (single-select `AskUserQuestion`) for where the human-readable docs go — **no default**:

| Choice | `artifacts.location` | Effect |
|---|---|---|
| **Committed** | `"committed"` | Write the object to `.claude/onboard-research.json` AND the 4 docs (+ ADR seeds) to `docs/onboard/`. |
| **Local only** | `"local"` | Write the object to `.claude/onboard-research.json` only; suppress all `docs/` writes. |
| **None** | `"none"` | Write the object to `.claude/onboard-research.json` only; suppress all `docs/` writes. |

> `local` and `none` are identical for the writes in THIS plan (both suppress `docs/`) — the distinction is recorded in `artifacts.location` for downstream/telemetry use. The object is ALWAYS written regardless of choice.

## Step 4: Write — the engine is the sole writer

In order:

1. **ALWAYS** write the assembled object to `.claude/onboard-research.json` (pretty-printed). This happens for every location choice, including `none`.
2. **If `location` is `committed`** (only): write the four render-docs + seed ADRs under `docs/onboard/`:
   - `docs/onboard/research-dossier.md`  ← **overwrite** (pure render of the object)
   - `docs/onboard/architecture.md`      ← **overwrite** (pure render)
   - `docs/onboard/risk-register.md`     ← **overwrite** (pure render)
   - `docs/onboard/glossary.md`          ← **overwrite** (pure render)
   - `docs/onboard/adr/NNNN-<slug>.md`   ← **seed ONLY IF ABSENT** — never clobber a team-ratified ADR. Use the next free 4-digit `NNNN`; skip any number that already has a file.
3. Record every path actually written into `artifacts.written[]`, set `artifacts.html = null`, and **re-write** `.claude/onboard-research.json` so the object on disk includes the final `written[]` (the object is its own manifest).

**Write rules (load-bearing):**
- The **object** (`.claude/onboard-research.json`) is ALWAYS written; the **4 docs** only when `location === "committed"`.
- The four render-docs are **pure renders → overwrite** on re-run (they regenerate deterministically from the object).
- ADRs are **seed-if-absent → never clobber** `adr/NNNN-*.md`. A hand-edited ADR survives every re-run.

## The four artifact templates

Each is a deterministic render of the object. `<!-- onboard v0.1.0 | Generated: YYYY-MM-DD -->` style maintenance headers are optional here (these are research outputs, not generated tooling), but DO stamp the generation date.

### `research-dossier.md` (the index)

```markdown
# Research Dossier — <project name>

> Generated by onboard:research · depth: <depth> · engine: subagent · <date>

## Roster
- Built-ins run: <roster.builtins joined>
- Disabled: <roster.disabledBuiltins joined, or "none">
- Custom specialists: <roster.customSpecialists joined, or "none">

## Verified claims (<count>)
For each id in verifiedClaims, resolve it back to findings[<dimension>].claims[<Cn>] and list:
- **<dimension>** — <statement>  _(confidence <n>)_  · evidence: <evidence joined>

## Dropped claims (<count>)
For each {id, reason} in droppedClaims:
- ~~<dimension:Cn>~~ — <reason>

## Per-dimension findings
### <dimension> — <status>
<one bullet per claim: statement · evidence · confidence>
(repeat per assessed dimension)
```

### `architecture.md`

```markdown
# Architecture Map — <project name>

> Render of the `architecture` dimension · <date>

## Layers & boundaries
<render the architecture dimension's claims as a structured map: layers, call direction, module boundaries>

## Verified architectural facts
<the verified architecture claims with evidence>

## Open / dropped
<any architecture claims the verifier dropped, with the reason>
```

### `risk-register.md`

```markdown
# Risk Register — <project name>

> Render of security + risk-tagged claims · <date>
> (Verify-backlog seeding into docs/feature-list.json is deferred to Plan 4.)

| ID | Dimension | Risk | Evidence | Confidence | Status |
|----|-----------|------|----------|-----------|--------|
| <dimension:Cn> | <dimension> | <statement> | <evidence> | <confidence> | verified / dropped |

Source every row from a security-dimension claim or any claim whose `category` is `"risk"`.
```

### `glossary.md`

```markdown
# Glossary — <project name>

> Render of the `domain` dimension's ubiquitous language · <date>

| Term | Meaning | Where it lives |
|------|---------|----------------|
| <domain term> | <statement> | <evidence path(s)> |

Source every row from a `domain`-dimension claim.
```

### `adr/NNNN-<slug>.md` (seed-if-absent)

```markdown
# NNNN. <decision title derived from a high-confidence architecture/security claim>

- Status: proposed
- Date: <date>
- Source: onboard:research (<dimension:Cn>)

## Context
<the claim statement + its evidence — the observed decision/constraint in the code>

## Decision
<what the codebase appears to have decided; phrased for the team to ratify or revise>

## Consequences
<implications drawn from the claim>
```

> Seed one ADR per high-confidence (`confidence ≥ 0.8`) architectural or security decision worth ratifying — but only when `docs/onboard/adr/NNNN-<slug>.md` for that slug does not already exist. If it exists, skip it silently (never clobber).
