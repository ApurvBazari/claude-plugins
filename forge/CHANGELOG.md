# Changelog

## 1.1.0 — 2026-04-11

- Seed `qualityGates` + `phaseSkills` + `allowPluginReferences` in `callerExtras` sent to
  onboard — forge is now the authoritative source for Plugin Integration enforcement config
- Add autonomyLevel-aware derivation rules: mechanically downgrade every `preCommit[].mode`
  to `advisory` when `autonomyLevel === "always-ask"`, keep `blocking` for balanced/autonomous
- Group plugin-discovery recommendations by build phase (Research & brainstorming first,
  Core discipline, Per-feature work, Review, Engineering, Guardrails) — pedagogical grouping
  for the interactive checklist UI so developers see why each plugin matters in context
- Delete CLAUDE.md "Installed Plugins" append workaround from plugin-discovery Step 6 —
  onboard 2.2.0 now authors the Plugin Integration section directly via section markers,
  making the two-author voice problem + timing fragility go away
- Improve engineering plugin discoverability: `lifecycle-setup` install-offer copy now
  surfaces the `knowledge-work-plugins` marketplace name with the two-command install
  sequence (`claude marketplace add knowledge-work-plugins` + `claude plugin install engineering`)
- Add Plugin Integration Coverage report to `/forge:status` reading root CLAUDE.md section
  markers, `.claude/settings.json` hook entries, and `forge-meta.json.generated.toolingFlags`
- Wire previously-orphaned `scripts/detect-scaffold-cli.sh` into `scaffolding/SKILL.md` Step 1
  pre-validation — replaces the inline bash check that duplicated its logic
- Add `forge-meta.json` vs `forge-state.json` distinction note in `/forge:status` Step 2
  (persistent setup metadata vs ephemeral resume state)
- Persist full `callerExtras` object as `generated.toolingFlags` in `forge-meta.json` during
  `tooling-generation/SKILL.md` Step 4, enabling `/forge:status` to report Plugin Integration
  Coverage without re-deriving
- Update `forge/README.md` prerequisites section with the `knowledge-work-plugins` marketplace
  install command for the optional `engineering` plugin
- **Requires onboard >= 2.2.0** at plugin-load time

## 1.0.0

- Initial release — 4-phase project scaffolder (Context Gathering → Scaffold → AI Tooling →
  Lifecycle Setup)
- Interactive context-gathering wizard with 33 adaptive questions (developers answer 8-22
  depending on stack maturity and project type)
- Scaffolding skill supporting `full` mode (external CLI like `create-next-app`, `cargo new`,
  `rails new`) and `walking-skeleton` mode for experimental stacks without mature CLIs
  (Android + Kotlin + Compose, iOS + Swift + SwiftUI)
- Delegates ALL tooling generation to `/onboard:generate` enriched headless mode — forge is
  a thin orchestrator, onboard does CLAUDE.md, rules, skills, agents, hooks, CI/CD, harness,
  evolution, sprint contracts, and team support
- Generates `init.sh` environment bootstrap + `docs/feature-list.json` feature decomposition
  (the two artifacts that require scaffold-specific knowledge onboard doesn't have)
- Phase 4 lifecycle setup: integrates with the `engineering` plugin for ADRs, testing strategy,
  deploy checklists, system designs, runbooks, incident playbooks (graceful skip if plugin absent)
- Resume protocol: `.claude/forge-state.json` checkpoint at every skill Step; `/forge:resume`
  picks up mid-session from the last checkpoint
- Stack research: `stack-researcher` agent (WebSearch sub-agent) with main-session fallback
  when sub-agent web tools are denied
- Sibling project detection: anchors to neighbor projects in the parent directory for version
  consistency across an ecosystem of related projects
- Plugin discovery skill: curated catalog + optional web search + capability mapping for
  plugin-aware generation
