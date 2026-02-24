# claude-plugins

This is a Claude Code plugin marketplace repository containing multiple plugins.

## Structure

- `claude-onboard/` — Codebase analysis and Claude tooling generator plugin
- `claude-notify/` — macOS notification hooks plugin
- Each plugin follows the `.claude-plugin` manifest convention

## Conventions

- Each plugin is self-contained in its own directory
- Plugin manifests live at `<plugin>/.claude-plugin`
- Commands, skills, and agents are organized per the Claude Code plugin spec
- Keep READMs concise — audience is developers already familiar with Claude Code
