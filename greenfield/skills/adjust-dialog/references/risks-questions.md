# Risks Probes — Adjust Dialog Category 4

What could go wrong, and what is the failure mode? Risks probes surface the downsides, edge cases, and failure scenarios the developer should be aware of before committing to an adjusted value. The intent is not to block the change — it's to ensure the developer is making an eyes-open decision.

## Probe selection

Use more probes (2-3) when:
- The adjusted value is a security-sensitive, data-sensitive, or performance-critical choice
- The `adjustmentIntent` has an "optimistic" tone without mention of failure modes

Use fewer probes (1) when:
- The developer explicitly named risks in `adjustmentIntent`
- The adjustment is a low-stakes correction (naming convention, config flag, secondary tooling)

Chain probes when: the response to the primary risk probe reveals an unexplored failure mode — follow with a mitigation probe to check whether the developer has a plan.

---

### Probe R1: Primary failure mode

> What's the most likely way this adjusted value could fail or cause problems in production?

**Trigger condition**: near-universal. Use for any architectural or tool choice adjustment.

**Follow-up hint**: listen for specificity. "It might be slow" is less useful than "if row-level RLS is on and a query joins 3 tables without index, it'll table-scan." Specificity suggests the developer has thought this through.

---

### Probe R2: Mitigation plan

> If that failure mode happens — what's the mitigation or rollback plan?

**Trigger condition**: use after Probe R1 if the developer names a credible failure mode.

**Follow-up hint**: the absence of a mitigation plan isn't a blocker, but it should be recorded. Future developers (or the same developer in 3 months) will want to know.

---

### Probe R3: Security surface

> Does this adjustment change the security surface of the system — access control, data exposure, authentication flow, or trust boundary?

**Trigger condition**: use when the adjusted value touches auth strategy, database access patterns, API design, data storage, or external integrations.

**Follow-up hint**: security surface changes are easy to underestimate. Even "we're just adding a new field" can change what's exposed in API responses.

---

### Probe R4: Data risk

> Does this adjustment put any user data, sensitive config, or production data at risk of loss, exposure, or corruption?

**Trigger condition**: use when the adjusted value involves database choices, migration strategy, storage decisions, or encryption.

**Follow-up hint**: data risk answers should include whether backups, rollback migrations, or data validation are in place — or need to be.

---

### Probe R5: Performance risk at scale

> At what load level does this adjusted value start to degrade? Is that load level realistic for this project?

**Trigger condition**: use when the adjusted value involves querying patterns, caching strategy, concurrency, or any decision that is load-sensitive.

**Follow-up hint**: the developer doesn't need to have a benchmarked answer. But they should be able to reason about the general shape of the degradation curve.

---

### Probe R6: Vendor lock-in risk

> How locked-in does this adjustment make you to a specific vendor, cloud provider, or third-party service?

**Trigger condition**: use when the adjusted value is a cloud-provider-specific service, a paid third-party API, or a proprietary SDK.

**Follow-up hint**: lock-in is not always bad — managed services save time. But the developer should know the exit cost if the vendor relationship changes.

---

### Probe R7: Operational complexity risk

> Does this adjusted value add operational complexity (new infra to manage, new monitoring surface, new on-call scenarios)?

**Trigger condition**: use when the adjusted value adds a new service, broker, queue, or external dependency.

**Follow-up hint**: operational complexity is often invisible at design time and painful at 2am. This probe surfaces whether the developer has factored in the ops burden.

---

### Probe R8: Compounding risk

> Could this change, combined with other choices already locked in this spec, create a risk that neither choice creates alone?

**Trigger condition**: use when `listedPhases` contains multiple previously reviewed phases and the adjusted value touches a cross-cutting concern (auth, data, networking, deployment).

**Follow-up hint**: compounding risks are the hardest to spot. This probe is most useful when the developer is adjusting something late in the context-gathering phase, after many other choices are locked.

---

### Probe R9: Known pitfall

> Is this a choice you've made before and had problems with? If so, what's different this time?

**Trigger condition**: use when the `adjustmentIntent` implies revisiting a choice that was originally made a certain way ("last time we used X and it didn't work out").

**Follow-up hint**: past experience is valuable context. If the developer has burned themselves before, they probably have a calibrated view of the risk.
