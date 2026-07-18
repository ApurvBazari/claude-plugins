# Generate — research contract (Step 0.1): presence matrix + Layered validation

Detail extracted from the `generate` skill's Step 0.1. The generate skill cites this file for the full `research` presence matrix and the Layered validation + sanitize mechanics. The two hard-reject strings — the D2 reject and the malformed-research reject — stay **inline in the skill**, verbatim, because callers parse them for routing.

## Presence (D2)

After v3 schema validation, `generate` enforces the research contract before Step 1. This is where the previously-inert `research` object becomes a required, validated, sanitized input.

| `research` | `callerExtras.regenerateOnly` | Action |
|---|---|---|
| absent | truthy | research-absent mode — snapshot re-emit; no consumption, no seeding (today's behavior) |
| absent | falsy / unset | **HARD REJECT** — the D2 error (verbatim inline in the generate skill); do NOT proceed, write nothing |
| present | (either) | validate + sanitize (below); if `regenerateOnly`, do NOT consume the sanitized object (snapshot replay), but a present-and-invalid envelope still hard-rejects |

## Layered validation + sanitize (when `research` is present)

1. **Envelope gate** — validate the object against `../../../schemas/research-dossier.json` (read the schema as the contract; opportunistically `python3 -c "import jsonschema, json, sys; jsonschema.validate(json.load(open(sys.argv[1])), json.load(open(sys.argv[2])))"`). On failure → **HARD REJECT** with the malformed-research error (verbatim inline in the generate skill), naming the offending field; write NO artifacts.
2. **Per-dimension contents check** — for each key in `research.findings{}`, validate its value against `../../../schemas/research-findings.json`. A malformed value → **strip that dimension** from a sanitized COPY of `research` and record a warning. Never abort. (The dossier schema types `findings` as a generic object, so a malformed per-dimension finding passes the envelope gate — this check is where it is caught. Plan-2 carry-forward.)
3. **Referential cleanup** — drop any `verifiedClaims` entry and any `droppedClaims[].id` whose `<dimension>` prefix was stripped in step 2, so the verified/dropped sets stay consistent with the surviving `findings{}`.
4. **Carry forward** — pass the **sanitized** `research` object + accumulated warnings to Step 3 (the dispatch). NEVER mutate `.claude/onboard-research.json` on disk — sanitization yields a consumption view only.

**Sparse-but-valid is NOT an error.** A schema-valid dossier with empty `findings{}`, no `verifiedClaims`, or empty `wizardInferences` (e.g. minimal depth) is valid — consumption no-ops per row and the verify-backlog source set may be empty (→ no feature-list). Reject is only for a malformed envelope; degrade is only for a malformed individual dimension.

**Telemetry `generate` owns** (passed to the dispatch, not written here): the full set — `consumed` (true when `research` present and NOT `regenerateOnly`; false otherwise), `engineUsed` (`research.engineUsed`), `depth` (`research.depth`), `specialistsRun` (the sanitized dossier's assessed `findings{}` keys), `claimsVerified` (count of `research.verifiedClaims` AFTER sanitization), `claimsDropped` (count of `research.droppedClaims` AFTER sanitization), `artifactLocation` (`research.artifacts.location`), `artifactsWritten` (`research.artifacts.written`), `htmlRendered` (`research.artifacts.html`). `generate` never writes files (dispatch contract) — `config-generator` completes (`backlogSeeded`/`backlogItemCount`) and writes the `metadata.research` block.
