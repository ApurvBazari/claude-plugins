# Defaults Derivation — Reference

How wizard defaults work: format spec, precedence rules, UI contract, anti-patterns.

---

## 1. Why Defaults Exist

**Round 2.5 Decision 1** locked: "Defaults-driven skip — every Q has a smart default; Enter accepts, type to override. Synthesis HTMLs still produced. Adjust loop still offered."

**Round 2.5 Decision 2** locked: "Stack-derived from earlier answers; greenfield-opinionated fallback when no stack signal exists."

The deliberation thesis of greenfield is that developers who think through their architectural decisions before scaffolding ship better projects. Defaults don't undermine this — they accelerate it. A developer who presses Enter 30 times is still producing a coherent architectural spec; they're just delegating the low-stakes decisions to greenfield's opinionated defaults while spending deliberation energy on the questions that matter for their project.

Bad defaults cost one keystroke (the override). Good defaults save many (the research and debate). The goal is to make Enter a correct answer for the majority case, not a lazy one.

---

## 2. Format Spec

Every question in `question-bank.md` ends with a `**Default**:` block, added after all existing blocks (`**Updates**`, `**Downstream effects**`, `**Note**`, `**Recommend**`, etc.).

### Single universal default (no stack signal needed)

```markdown
- **Default**: <value> (always — greenfield opinion: <one-line rationale>)
```

Use this when the same default is correct regardless of stack, topology, or scale target. Examples: Q5.1 (always "Create a PR"), Q4.3 (always "Balanced").

### Stack-derived default with fallback

```markdown
- **Default**: `<visible-default-value>`
  - If `stack.stack.<field>` matches `<condition>` → `<derived-value>`
  - If `architecturalFraming.<field>` is `<value>` → `<derived-value>`
  - Else → `<fallback>` (greenfield opinion: <one-line rationale>)
```

The first line is the visible default shown to the user in `[default: X]`. The indented rules are the derivation precedence — read top-to-bottom, first match wins. The `Else` line is the unconditional fallback used when no signal fires.

### Open-ended / no-meaningful-default

```markdown
- **Default**: (skip with Enter — <one-line reason why no default is appropriate>)
```

Use when the question is genuinely open-ended (Q1.1, Q1.2, Q2.2) or when a prefill would be misleading (AV.Q2 — rework notes). The wizard still shows the field but does not prefill it; Enter skips.

---

## 3. Precedence Rules

Defaults are evaluated in this order. First matching rule wins; fall through to the next if the condition is not met.

```
1. Explicit stack signal (stack.stack.language, stack.stack.framework)
   └── Most specific first: framework overrides language
2. Architectural framing signal (architecturalFraming.topology, .deploymentShape, .scaleTarget)
   └── Most specific first: multi-field conditions before single-field
3. Cross-phase derived signal (a prior Q's answer that's already in context)
   └── e.g., dataArchitecture.orm → P3.Q5 default tool
4. Greenfield-opinionated fallback
   └── Always present; the safety net when no signal fires
```

### Signal reading rules

- Read signals from `context.phases.*` (structured fields written by wizard answers).
- `stack.stack.*` is populated after Q2.2 and stack research completes.
- `architecturalFraming.*` is populated after Step 2.5 completes.
- `dataArchitecture.*` and `apiIntegration.*` are populated after Steps 3 and 4 complete.
- Questions in Steps 1–2.5 can only use signals from their own answers (no forward-looking signals).
- Questions in Steps 3–11 can use all prior phase signals.

---

## 4. When to Use Stack-Derived vs Hardcoded

Use stack-derived when:
- The correct answer is objectively different for different stacks (e.g., ORM choice per language)
- Picking the wrong default would produce a broken or inconsistent project (e.g., Prisma for TypeScript, SQLAlchemy for Python)
- The stack signal is already in context at the point the question is asked

Use hardcoded greenfield opinion when:
- The correct answer is the same for 80%+ of projects regardless of stack
- No stack signal exists or is relevant (e.g., Q4.3 autonomy level)
- The question is philosophical rather than technical (e.g., Q4.2 testing philosophy)
- The stack signal would be speculative or unreliable at that point in the wizard

Decision tree:

```
Is there a reliable context signal available at this step?
├── Yes → Does the signal change the correct answer?
│   ├── Yes → Use stack-derived rule
│   └── No → Use hardcoded with a brief rationale note
└── No → Use hardcoded greenfield opinion
```

---

## 5. UI Rendering Contract

Every question's prompt ends with `[default: <value>]` injected by the wizard immediately before displaying the question to the developer. Example:

```
What's your service topology?

  1. Monolith (single deployable unit)
  2. Modular monolith (internal modules, single deploy)
  3. Microservices (independent services, independent deploys)
  4. Serverless (function-per-endpoint, no persistent server)

[default: Monolith]
```

**Accepting a default**: if the developer presses Enter (or replies with an empty string), the wizard:
1. Records the default value in `context.phases.*` at the appropriate field.
2. Logs `context.defaultsAccepted[questionId] = true`.
3. Moves to the next question.

**Overriding a default**: if the developer types any non-empty response, the wizard:
1. Parses the response as a normal answer (number for choice questions, free text for open-ended).
2. Records the typed value in `context.phases.*` at the appropriate field.
3. Logs `context.defaultsAccepted[questionId] = false`.
4. Moves to the next question.

**Open-ended skip**: for questions with `(skip with Enter)` defaults, Enter produces `null` or `""` in the context field (not the string "skip"). The wizard does not log a `defaultsAccepted` entry for these — they are genuinely optional.

### Deriving the visible default value

The visible default shown in `[default: X]` is derived at runtime by evaluating the precedence rules against current context. This means:

- The visible default for Q P3.Q4 (ORM) changes depending on what was answered in Q2.2 (stack language).
- The visible default for AF.Q1 (topology) is always "Monolith" on first render; it may change if the developer adjusts via the Adjust loop after synthesis.

The wizard must re-derive defaults dynamically on each question render, not cache them at session start.

---

## 6. Telemetry — defaultsAccepted

The wizard tracks default acceptance in `context.defaultsAccepted`:

```json
{
  "defaultsAccepted": {
    "AF.Q1": true,
    "AF.Q2": true,
    "AF.Q3": false,
    "AF.Q4": true,
    "P3.Q1": true,
    ...
  }
}
```

This is written to `greenfield-state.json` as part of the normal context checkpoint. It is:
- Used by synthesis-review to annotate which values were defaults vs explicit decisions (accepted defaults get a lighter annotation; explicit choices get full display).
- Available to future tooling for calibrating defaults over time (which defaults get overridden most often signals miscalibrated opinions).
- NOT used to gate anything — accepting a default is always valid.

The key is the Q-ID (e.g., `"AF.Q1"`, `"P3.Q4"`, `"Q3.F1"`). The value is `true` (accepted default) or `false` (explicitly overridden). Questions with `(skip with Enter)` defaults are omitted from the map.

---

## 7. Anti-Patterns

### Aspirational defaults
Don't default to what you wish were chosen. Default to what's most likely correct for the dev's actual stack and scale.

Bad: defaulting to "Microservices" because it's architecturally sophisticated.
Good: defaulting to "Monolith" because 90% of solo + startup projects don't need service decomposition.

### Aspirational scale
Don't inflate the default scale target based on the developer's enthusiasm in Q1.1. If the app description is a "weekend project", the scale default should reflect that.

### Stack-signal overreach
Don't derive defaults from signals that aren't yet in context at the point the question is asked. Q2.3 (scaffold approach) cannot use `dataArchitecture.orm` — that hasn't been asked yet.

### Silent fallback
Don't silently produce a different default than what the rules specify. The visible `[default: X]` must match what Enter will actually record. If the derivation is complex, evaluate it server-side and render the result — never show a static fallback while silently recording a different value.

### Default as recommendation replacement
The `**Default**:` block and the `**Recommend**:` block serve different purposes:
- `**Recommend**:` tells Claude what to suggest to the developer (guidance text displayed inline).
- `**Default**:` tells the wizard what to record if the developer presses Enter.

These often align but are not the same. The Recommend block guides the developer's thinking; the Default block records the mechanical fallback. Both must be present on questions that have both.

### Omitting the fallback
Every stack-derived default must have an unconditional `Else →` fallback. Never leave a derivation rule that could produce no value — the wizard must always have something to record for Enter.
