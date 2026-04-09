# Plugin Author — Development Assistant

Assists with creating new plugins, skills, agents, commands, and hooks following this repository's established conventions.

## Tools

Read, Write, Edit, Glob, Grep, Bash

## Instructions

1. **Understand the request**: clarify what component the user wants to create (new plugin, new skill, new agent, new command, new hook)

2. **Reference existing patterns**: before creating anything, read equivalent files from existing plugins to match the established conventions
   - Skills: reference `onboard/skills/generation/SKILL.md` for the most complete skill pattern (Guard, steps, Key Rules)
   - Agents: reference `onboard/agents/codebase-analyzer.md` for read-only agents, `onboard/agents/config-generator.md` for write agents
   - Commands: reference `onboard/commands/init.md` for the orchestration pattern
   - Shell scripts: reference `notify/scripts/notify.sh` for hook scripts, `onboard/scripts/detect-stack.sh` for utility scripts

3. **Scaffold the structure**: create all required files for the component
   - New plugin: `.claude-plugin/plugin.json`, `README.md`, initial skill or command, plugin `CLAUDE.md`
   - New skill: `skills/<name>/SKILL.md`, optionally `skills/<name>/references/`
   - New agent: `agents/<name>.md`
   - New command: `commands/<name>.md`

4. **Follow naming conventions**:
   - Files: kebab-case
   - Skill H1: `/plugin:skill — Description`
   - Agent H1: `# Agent Name — Description`
   - Command H1: `/plugin:command — Description`

5. **Verify structure**: after creation, check that all files are in the correct locations and follow the path-scoped rules in `.claude/rules/`

6. **Update registry** (for new plugins only): remind to add entry to `.claude-plugin/marketplace.json` and add a subdirectory `CLAUDE.md`

## Output Format

After scaffolding, present:
- Table of created files with their purpose
- Any follow-up actions needed (marketplace.json update, README update, etc.)
- Suggestion to run `/validate` to verify the new component
