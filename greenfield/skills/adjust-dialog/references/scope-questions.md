# Scope Probes — Adjust Dialog Category 1

What is and isn't covered by this decision? Scope probes map the blast radius before a change lands — they surface adjacent fields and phases that will be affected, and flush out implicit assumptions about what "this section" controls.

## Probe selection

Use more probes (2-3) when:
- The adjusted value is a structural or foundational decision (framework, runtime, database engine, topology)
- The `adjustmentIntent` suggests a broad motivation ("we need to support more users")

Use fewer probes (1) when:
- The adjusted value is a narrow config choice (a flag, a numeric threshold, a secondary tool)
- The developer's stated intent already clearly articulates the scope of change

Chain probes when: the response to the first scope probe reveals an unexpected blast radius — follow with the "adjacent fields" probe to map it.

---

### Probe S1: Blast radius

> If we change `{sectionId}` from `{originalValue}` to your proposed value, what other fields or decisions in this phase must also change to stay consistent?

**Trigger condition**: use for any structural or architectural value change.

**Follow-up hint**: listen for whether the developer names concrete fields. If they say "nothing" for a high-impact change (e.g., switching database engine), that's a yellow flag worth probing.

---

### Probe S2: Phase boundary

> Does this change stay contained within `{phaseId}`, or does it require revisiting an earlier phase?

**Trigger condition**: use when `listedPhases` contains phases that are upstream of `phaseId`.

**Follow-up hint**: if the answer is "earlier phase", ask which one and flag for the caller to surface a route-back option.

---

### Probe S3: What this does NOT cover

> What is explicitly out of scope for this adjustment? In other words — what are you intentionally NOT changing at the same time?

**Trigger condition**: use when `adjustmentIntent` is broad or vague (e.g., "make it more scalable").

**Follow-up hint**: a clear out-of-scope boundary is a healthy sign. Absence of one often means the developer hasn't fully bounded the change.

---

### Probe S4: Scope creep check

> Is there anything you originally wanted to change about this section that you're deferring because it feels too big for now?

**Trigger condition**: use when the adjustment seems like a minimal tweak but the developer's intent suggests a larger underlying concern.

**Follow-up hint**: this surfaces hidden scope that the developer may be rationing. Sometimes the real problem is larger than the presented adjustment.

---

### Probe S5: Downstream phase awareness

> Which of the phases in `{listedPhases}` will need to be re-reviewed if this adjustment sticks?

**Trigger condition**: use when `listedPhases` contains 3 or more phases that could inherit this decision.

**Follow-up hint**: listen for concrete phase names. A developer who can name the downstream phases understands the dependency graph; one who can't may be missing dependencies.

---

### Probe S6: Reversibility

> If this adjusted value turns out to be wrong three sprints from now, how easy is it to change back or forward to something else?

**Trigger condition**: use for vendor choices, persistent data decisions (database engine, schema strategy), or anything that creates long-lived artifacts.

**Follow-up hint**: reversibility isn't always required, but the developer should be able to articulate why this is or isn't a high-switching-cost decision.

---

### Probe S7: MVP vs full vision

> Is this change aimed at the current MVP scope, or is it anticipating a later milestone?

**Trigger condition**: use when the adjusted value appears more complex or over-engineered than the current phase warrants.

**Follow-up hint**: there's no wrong answer here, but "anticipating later" should trigger a risk conversation about added complexity now.

---

### Probe S8: Completeness

> Are there other sections in `{phaseId}` that this adjustment makes stale or inconsistent?

**Trigger condition**: use after a high-impact structural change in any phase. Always useful as a closing scope probe.

**Follow-up hint**: if the developer can't name any related sections, briefly recap the phase's section list to jog their memory.
