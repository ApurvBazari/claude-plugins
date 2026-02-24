# claude-plugins

A marketplace of plugins for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Available Plugins

| Plugin | Description |
|--------|-------------|
| [claude-onboard](./claude-onboard/) | Interactive wizard that analyzes your codebase and generates complete Claude tooling for AI-assisted development |
| [claude-notify](./claude-notify/) | macOS system notifications for Claude Code — get notified when tasks complete or need attention |

## Installation

Add this marketplace, then install any plugin:

```bash
# Add the marketplace
claude marketplace add https://github.com/apurvbazari/claude-plugins

# Install a plugin
claude plugin install claude-onboard
```

See each plugin's README for detailed usage instructions.

## License

[MIT](./LICENSE)
