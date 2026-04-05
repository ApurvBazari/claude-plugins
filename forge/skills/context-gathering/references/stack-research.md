# Stack Research Guide

How to research a tech stack using the stack-researcher agent during Phase 1.

## When to Research

Research is triggered after Q2.1/Q2.2, when the developer names their tech stack. The stack-researcher agent runs while the wizard pauses.

## What to Research

For each technology in the stack, the agent searches for:

### 1. Current Version
- Search: "[framework] latest version [current year]"
- Source: Official website, GitHub releases page, npm/PyPI/crates.io
- Extract: Latest stable version number, release date

### 2. Official Scaffold CLI
- Search: "[framework] create project CLI", "[framework] getting started"
- Source: Official documentation getting-started guide
- Extract: CLI command, available flags/options, interactive prompts it asks

### 3. Recommended Project Structure
- Search: "[framework] recommended project structure"
- Source: Official docs, getting-started guide output
- Extract: Directory layout, key files, naming conventions

### 4. Best Practices (Current Year)
- Search: "[framework] best practices [current year]"
- Source: Official blog, migration guides, well-regarded community guides
- Extract: Recommended patterns, anti-patterns to avoid, configuration defaults

### 5. Companion Ecosystem
- Search: "[framework] recommended libraries [current year]"
- Source: Official docs recommendations section, community consensus
- Extract: Testing framework, ORM, auth library, styling, state management

### 6. Known Issues
- Search: "[framework] breaking changes", "[framework] migration guide"
- Source: Changelog, migration docs, GitHub issues
- Extract: Recent breaking changes, deprecated features, common gotchas

### 7. Deployment Recommendations
- Search: "best deployment platform for [framework]"
- Source: Official docs deploy section, community comparisons
- Extract: Recommended platforms with reasoning, official integrations

## How Research Feeds into Forge

Research output stays in conversation context (not written to a file during Phase 1). It informs:

1. **Q2.3**: Scaffold approach recommendation — "SvelteKit 3.0's `sv create` now supports TS by default"
2. **Q3.4**: Deploy recommendation — "Next.js deploys best on Vercel or Cloudflare"
3. **Phase 2**: Correct CLI flags, version pins, project structure
4. **Phase 3**: Accurate CI/CD commands, test framework setup

After scaffolding, research findings are saved to `forge-meta.json` under the `webResearch` key.

## Freshness

Research happens once during Phase 1. For ongoing freshness:
- Weekly CI tooling audit can re-check framework versions
- SessionStart hook can flag if `forge-meta.json` stack version is behind latest
