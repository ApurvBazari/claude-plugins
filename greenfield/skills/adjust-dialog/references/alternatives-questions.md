# Alternatives Probes — Adjust Dialog Category 3

What other choices exist, and why this one? Alternatives probes verify that the adjusted value is a considered selection, not the first option that came to mind. The goal is not to second-guess — it's to make the reasoning explicit so the decision record reflects a real trade-off.

## Probe selection

Use more probes (2-3) when:
- The adjusted value is a major tool or library choice where the ecosystem offers multiple credible options
- The `adjustmentIntent` doesn't mention any alternatives considered

Use fewer probes (1) when:
- The developer explicitly named alternatives in `adjustmentIntent`
- The adjustment corrects an obvious error (wrong value, typo, misread requirement) rather than a trade-off

Chain probes when: the response to the primary alternatives probe reveals that the developer did consider other options — follow with the differentiation probe to surface the actual reason for the choice.

---

### Probe AL1: Named alternatives

> What alternatives did you consider before settling on this adjusted value? Name at least one.

**Trigger condition**: use for any tool, library, framework, or strategy choice. Near-universal applicability.

**Follow-up hint**: inability to name any alternative is a yellow flag. It may mean the developer reached for the familiar option reflexively. That's often fine — but the record should reflect it.

---

### Probe AL2: Why not the runner-up

> You mentioned [alternative named by developer]. What made it less attractive than your adjusted choice?

**Trigger condition**: use after Probe AL1 if the developer names an alternative.

**Follow-up hint**: listen for concrete differentiators (performance, ecosystem, team familiarity, cost) vs vague preferences ("just didn't like it"). Concrete reasoning produces a useful decision record.

---

### Probe AL3: What the original value had going for it

> What was `{originalValue}` doing right? What would you lose by moving away from it?

**Trigger condition**: use when the adjusted value is a full replacement of the original (not a refinement or correction).

**Follow-up hint**: this is the devil's advocate question. The answer often reveals trade-offs the developer hasn't fully priced in. It's not a challenge to the choice — it's a completeness check.

---

### Probe AL4: Hybrid or middle path

> Is there a middle-path option you haven't named? Something between `{originalValue}` and the adjusted value?

**Trigger condition**: use when the adjustment is moving from one extreme to another (e.g., no auth → full OAuth; single-tenant → multi-tenant; REST → GraphQL).

**Follow-up hint**: often the best choice is a hybrid. This probe surfaces whether the developer considered the hybrid and ruled it out, or simply didn't think of it.

---

### Probe AL5: Standard vs custom

> Are you choosing an established standard/convention here, or something project-specific? If custom — why not the standard?

**Trigger condition**: use when the adjusted value diverges from the ecosystem's dominant convention or most popular tool.

**Follow-up hint**: custom choices are sometimes the right call, but they create maintenance cost. This probe makes that trade explicit.

---

### Probe AL6: Buy vs build

> Is this something you're adopting from an existing library/service, or building yourself? If building — what drives that over adopting?

**Trigger condition**: use when the adjusted value describes a custom implementation where a well-maintained third-party option exists.

**Follow-up hint**: "build" answers should include a reason (cost, control, licensing, missing feature) rather than just preference.

---

### Probe AL7: Previously evaluated options

> Has this been evaluated before in this project — for example in an earlier phase — and rejected? If so, what changed?

**Trigger condition**: use when `listedPhases` suggests earlier phases where this decision could have been made differently.

**Follow-up hint**: if an option was evaluated and rejected earlier, the developer should know why — and whether that reason still applies. If they don't know, the synthesis record from that phase is a useful reference.

---

### Probe AL8: Default vs intentional

> Is this choice the default for your stack, or an intentional deviation from the default?

**Trigger condition**: use for tool or config choices in well-defined ecosystems (e.g., Next.js default router vs App Router; Prisma default migrations vs custom).

**Follow-up hint**: deviating from defaults is sometimes right. But "we just picked what the framework gave us" is also a valid answer — it's honest about the basis of the choice.
