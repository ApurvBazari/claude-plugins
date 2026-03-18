# onboard — Internal Conventions

Interactive wizard that analyzes codebases and generates complete Claude tooling infrastructure.

## Phased Architecture

```
/onboard:init
     │
     ▼
Phase 1: Analysis ──→ codebase-analyzer agent (read-only)
     │                   ├── analyze-structure.sh
     │                   ├── detect-stack.sh
     │                   └── measure-complexity.sh
     ▼
Phase 2: Wizard ──→ wizard skill (adaptive Q&A, presets)
     │
     ▼
Phase 3: Generation ──→ config-generator agent (write)
     │                   └── reads analysis report + wizard answers from context
     ▼
Phase 4: Handoff ──→ explains generated artifacts, suggests next steps
```

## Agent Handoff Pattern

- `codebase-analyzer` runs first (read-only) — produces structured analysis report
- Report stays in conversation context — NOT written to a file
- `config-generator` runs second (write) — receives analysis + wizard answers via prompt
- Both agents are spawned from the `/onboard:init` command

## Skill Hierarchy

- `wizard/SKILL.md` — drives the interactive Q&A (presets: Minimal/Standard/Comprehensive/Custom)
- `analysis/SKILL.md` — tech stack pattern matching, model recommendations
- `generation/SKILL.md` — artifact generation logic, references contain authoritative guides

The `generation/references/` directory is the single source of truth for how Claude tooling artifacts should be structured. Other plugins and external users reference these guides.

## Script Conventions

- Scripts are supplementary — if they fail, the wizard continues with deep exploration only
- POSIX-compatible: must work on macOS (BSD) and Linux (GNU)
- `analyze-structure.sh`: uses `find`, `wc`, `awk` — beware BSD vs GNU awk differences
- `detect-stack.sh`: checks for lock files, config files, framework markers
- `measure-complexity.sh`: LOC counting, file counts, directory depth analysis
- All scripts output structured text with `## Section` headers for parsing

## Reference Organization

Each skill's `references/` directory contains domain-specific guides:
- `analysis/references/`: tech-stack-patterns, model-recommendations, config-extraction-guide
- `generation/references/`: claude-md-guide, rules-guide, hooks-guide, skills-guide, agents-guide, collaboration-guide
- `wizard/references/`: question-bank, workflow-presets

## Key Patterns

- Maintenance headers on all generated artifacts (version + date) — prompt users to re-run when patterns drift
- Quick Mode: infers wizard answers from analysis results + one autonomy question
- Preset path: pre-filled values for Minimal/Standard/Comprehensive profiles
- Script failure fallback: log failure, continue with codebase exploration only
