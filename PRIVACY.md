# Privacy

This policy covers the five plugins in this repository: `onboard`, `notify`, `handoff`, `walkthrough` and `lens`.

## The short version

- The plugins have no server and no account. They collect no analytics or telemetry.
- Nothing is sent to the author, ever.
- Everything a plugin writes stays on your machine, in your project or your Claude settings folder.
- The plugins run inside Claude. What Claude reads while using them is handled under the terms of your Claude plan, as in any other session.

## What each plugin touches

| Plugin | Reads | Writes | Network |
|---|---|---|---|
| `onboard` | Your repository's files and git history | Claude tooling in your project (`CLAUDE.md`, `.claude/`, a project `.mcp.json`), after you approve a preview | `/onboard:update` reads the public Claude Code docs. `/onboard:verify` can open your own locally running app. Plugins you accept are installed from Anthropic's official marketplace. Remote MCP entries it writes (Vercel, Supabase) connect only when you use them. |
| `notify` | Claude Code's hook events | A copy of its script, a config file and three hook entries in the Claude settings scope you choose | None. Notifications go to your operating system's notification centre and can show Claude's last message, which you can turn off. |
| `handoff` | `.claude/handoff/` in your project, and git status | `.claude/handoff/` in your project; optionally one `.gitignore` line | None |
| `walkthrough` | The current session, and the files or subject you name | One HTML file, by default in `.claude/walkthrough/` | None. The pages it makes load nothing from the network. |
| `lens` | The session's diff, its spec and plan, and the source it cites | `.claude/lens/` in your project; optionally one `.gitignore` line | None |

Each plugin's README has the full list under **What it reads, writes, and sends**.

## Your data and its removal

The plugins store nothing outside the paths above. To remove what a plugin wrote, delete those paths. `/notify:uninstall` removes notify's hooks and files for you.

## Contact

Questions or concerns: open an issue at [github.com/ApurvBazari/claude-plugins/issues](https://github.com/ApurvBazari/claude-plugins/issues).

_Last updated: 2026-10-31._
