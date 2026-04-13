# Ecosystem Strategy — Full AI-Driven Dev Environment

Strategy for combining this repo's plugins with official marketplace plugins to create a complete AI-driven development workflow.

---

## The Complete Workflow Map

```
Phase           Your Plugin              Official Companion
─────────────── ──────────────────────── ──────────────────────────────
Setup           onboard / forge          + hookify (ongoing rule mgmt)
Develop         (GAP)                    feature-dev
Refine          (GAP)                    code-simplifier
Maintain        (GAP)                    claude-md-management
Guard           (GAP)                    security-guidance
Ship            (GAP)                    commit-commands + code-review
                                         + pr-review-toolkit (deep)
Monitor         notify                   + Native Claude Code OTEL
Meta            (if authoring plugins)   plugin-dev + skill-creator
```

---

## Actionable Items

### Documentation: Recommended Stack Guide

- [x] **Create workflow guide in README** — Full developer workflow mapped to plugins, folded into root README.
- [x] **Add "Companion Plugins" section to root README** — Added as "Works Well With" table in README.
- [x] **Add "Works well with" section to each plugin README** — Added to onboard, forge, and notify READMEs.

### Documentation: Best Practices

- [x] **Create best practices content** — Folded into README workflow guide section.
- [x] **Add workflow diagram to docs** — Added ASCII flow diagram to README.

### Gap Analysis: What Your Plugins Don't Cover

#### Development Loop (biggest gap)

- [ ] **Decide: build or recommend?** — The development phase (between setup and ship) has no plugin in this repo. Official `feature-dev` provides a structured 7-phase workflow (Discovery → Exploration → Clarification → Architecture → Implementation → Review → Handoff). Options:
  - **Recommend** feature-dev as a companion in docs (zero effort, leverages official quality) — DONE: added to README workflow guide

#### Ongoing CLAUDE.md Maintenance

- [x] **Recommend claude-md-management as companion to onboard** — Documented in onboard/README.md "Works Well With" section: onboard bootstraps, claude-md-management maintains.

#### Incremental Hook Management

- [x] **Recommend hookify as companion to onboard** — Documented in onboard/README.md "Works Well With" section: onboard writes hooks to settings.json, hookify uses .local.md rule files.

#### Passive Security

- [x] **Recommend security-guidance as optional add-on** — Added to onboard, forge, and root README companion tables.

### Cross-Plugin Integration Opportunities

- [x] **DevKit retired** — Ecosystem plugins (commit-commands, pr-review-toolkit, feature-dev, superpowers) now cover DevKit's functionality. Ship phase handled by companion plugins.
- [x] **forge → notify** — Added notify to plugin-discovery catalog as universal plugin. Documented in forge/README.md "Works Well With".

### Plugin Authoring Meta (for you as the repo maintainer)

- [x] **Install and evaluate `plugin-dev`** — Already installed. Validator agent run against all 3 plugins (2026-04-13). Found 1 critical (stale namespace), 3 major (manifest sync), 10 minor issues — all fixed.
- [x] **Install and evaluate `skill-creator`** — Already installed. Available for iterative skill benchmarking when needed.
- [x] **Run plugin-dev validator on all three plugins** — Completed 2026-04-13. All findings addressed in `docs/ecosystem-strategy-companion-plugins` branch.
