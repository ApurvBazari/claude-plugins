# Generate — untrusted user-input framing (recursive walk)

Detail extracted from the `generate` skill's Step 1 Validation. The generate skill keeps the one-sentence agent directive **inline** (it is shown verbatim to `config-generator`) and cites this file for the recursive-walk mechanics and the caller-side cap/strip division of labor.

## Recursive framing walk

When building the prompt for `Agent(config-generator)` in Step 3, recursively walk every string value under `wizardAnswers.*` and the full `context.*` tree (which includes `context.stack.*`, `context.securityPlan`, `context.phases.*`, `context.syntheses.*`, the top-level `context.risks[]` array (Round 4 — covers `risks[].text` and `risks[].reconciliation.rationale`), and anything later rounds add). For each free-text leaf — heuristic: contains whitespace OR length > 120 characters, AND does **not** match URL (`^https?://`), file path (`^/` or `^[A-Za-z]:\\`), version (`^v?\d+\.\d+`), or pure kebab-case (`^[a-z0-9]+(-[a-z0-9]+)*$`) — wrap it in an `<untrusted-user-input field="<dotted-path>">...</untrusted-user-input>` XML-style fence (e.g., `field="wizardAnswers.painPoints.timeSinks"` or `field="risks[0].text"`). The directive that accompanies the framing is kept inline in the skill and included verbatim in the agent prompt.

## Caller-side cap/strip division of labor

Callers (onboard:start and the other internal callers — onboard:update / onboard:evolve) are expected to have length-capped (16 KiB) + `\r`-stripped these fields before dispatch via the same recursive walk — see `../../start/references/onboard-context-builder.md` § Untrusted-input sanitiser for the authoritative procedure. Do not duplicate the cap/strip work here; just apply the recursive framing consistently across all in-scope string leaves.
