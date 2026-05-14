# Assumptions Probes — Adjust Dialog Category 2

What is the developer assuming that might not hold? Assumptions probes surface the hidden premises underneath an adjustment — team skill, infrastructure readiness, timeline, and ecosystem maturity. A technically correct choice resting on a faulty assumption is still a wrong choice.

## Probe selection

Use more probes (2-3) when:
- The adjusted value involves a technology the team hasn't used before
- The developer's `adjustmentIntent` contains aspirational language ("we'll need", "eventually", "once we scale")

Use fewer probes (1) when:
- The adjustment is a direct correction to a factual error (e.g., "I picked the wrong region")
- The developer's intent is concretely grounded in existing team knowledge or infrastructure

Chain probes when: the response to the team-skill probe reveals a depth assumption — follow with the ecosystem maturity probe to check whether the ecosystem will support them.

---

### Probe A1: Team skill

> Does your team already have hands-on experience with the adjusted value, or is this aspirational?

**Trigger condition**: use whenever the adjusted value is a library, framework, language feature, or architectural pattern (not a config value).

**Follow-up hint**: "aspirational" isn't disqualifying — but it should surface a learning curve assumption that gets captured. Listen for hedging ("someone on the team has used it once") vs genuine fluency.

---

### Probe A2: Infrastructure readiness

> Does your current infrastructure (cloud account, CI environment, hosting tier) already support this choice, or does it require setup you haven't done yet?

**Trigger condition**: use when the adjusted value touches deployment, hosting, or cloud services.

**Follow-up hint**: unearned infrastructure confidence is a common root cause of "works locally, breaks in production" spirals.

---

### Probe A3: Load or scale assumption

> What load level or scale are you designing this for? Is that assumption consistent with the project's current phase?

**Trigger condition**: use when the `adjustmentIntent` mentions performance, scale, or "more users".

**Follow-up hint**: over-engineering for scale is a real cost. Under-engineering is also a real cost. The probe is not trying to force a choice — just to make the assumption explicit.

---

### Probe A4: Ecosystem maturity

> How mature is the ecosystem around this choice? Are you assuming stable, production-ready tooling?

**Trigger condition**: use when the adjusted value is a newer library, an emerging pattern, or something that was recently released.

**Follow-up hint**: listen for whether the developer has actually checked recent release history, open issues, or community support — or is working from reputation alone.

---

### Probe A5: Dependency assumption

> Are you assuming that `{originalValue}` can be replaced cleanly, with no migration work?

**Trigger condition**: use when the adjusted value replaces a technology (database, ORM, auth provider) that has already generated artifacts (schema, migrations, session tokens).

**Follow-up hint**: migration cost is frequently under-estimated when the decision feels "clean" in the spec but the actual swap involves data movement.

---

### Probe A6: Timeline assumption

> Is the timeline assumption behind this choice realistic for the current sprint budget?

**Trigger condition**: use when the adjusted value adds complexity (setup, config, integration work) that wasn't in the original estimate.

**Follow-up hint**: if the developer hasn't thought about timeline impact, this is the moment. Not all timeline assumptions are wrong, but they should be made consciously.

---

### Probe A7: Third-party reliability

> Are you assuming a third-party service or API is reliable and available for your use case? Have you verified pricing, rate limits, or SLA?

**Trigger condition**: use when the adjusted value includes an external service (payment processor, email provider, storage, CDN, AI API).

**Follow-up hint**: listen for whether the developer has checked the service's free-tier limits, rate limits, or geographic availability — or is treating it as a solved problem.

---

### Probe A8: Existing-code compatibility

> Does this change assume that existing code in the project remains compatible, or does it require touching already-written code?

**Trigger condition**: use mid-project (when `listedPhases` suggests the context-gathering phase is beyond the initial setup).

**Follow-up hint**: a "clean" spec change that requires touching 40 files is not actually clean. This probe surfaces that.
