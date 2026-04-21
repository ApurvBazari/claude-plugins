# Security Policy

## Reporting a vulnerability

If you've found a security issue in `onboard`, `forge`, `notify`, or any shared infrastructure in this repository, please report it privately — **do not open a public GitHub issue**.

Email <apurvbazari@live.com> with:

- A description of the issue and its impact.
- Steps to reproduce (or a proof-of-concept if one is already written).
- The affected plugin and version (check each plugin's `.claude-plugin/plugin.json`).
- Whether the issue is already public elsewhere.

You'll get an acknowledgement within 72 hours. Expect a fix timeline in the first reply, weighted by severity.

## Scope

In scope:

- Command injection, path traversal, or arbitrary file-write in any plugin script (`scripts/*.sh`, hook scripts).
- Secrets logged to the filesystem or leaked through hook outputs.
- Supply-chain issues in what the plugins shell out to (`claude plugin install`, `brew`, `jq`, `terminal-notifier`, `notify-send`).
- Misuse of `${CLAUDE_PLUGIN_ROOT}` that escapes the plugin sandbox.
- Skill / agent frontmatter injection that bypasses intended tool restrictions.

Out of scope:

- Issues in Claude Code itself — report those to [Anthropic](https://github.com/anthropics/claude-code/security/policy).
- Issues in third-party plugins listed in the *Companion plugins* table of the root README. Report those to the plugin's own repository.
- LLM prompt-injection attacks against Claude itself — report to Anthropic.
- Vulnerabilities in development-only dependencies that aren't shipped with the plugins.

## What counts as a fix

A reported vulnerability is considered resolved when:

1. A patch lands on `main`.
2. The affected plugin's `.claude-plugin/plugin.json` version is bumped.
3. A new GitHub release is published with the fix called out in the release notes.
4. For user-facing exploitable issues: a short advisory is posted to the repo's security advisories tab.

## Credit

Reporters who want public recognition are credited in the advisory and in the relevant plugin's `CHANGELOG.md`. Reporters who prefer to stay anonymous will be respected.

Thanks for taking the time to report responsibly.
