# Contributing to claude-plugins

Thanks for considering a contribution. This marketplace hosts three plugins (`forge`, `onboard`, `notify`), and the bar is *"ships to a solo developer's terminal without breaking."* Keep changes self-contained, add a runnable example or test, and you're in.

---

## Before you open an issue or PR

- **Questions about Claude Code itself** belong in the [Claude Code discussions](https://github.com/anthropics/claude-code/discussions), not here.
- **Security reports** go to <apurvbazari@live.com> — see [SECURITY.md](./SECURITY.md). Please do **not** open public issues for security vulnerabilities.
- **Duplicate first** — search [existing issues](https://github.com/ApurvBazari/claude-plugins/issues?q=is%3Aissue) and the per-plugin CHANGELOGs (`onboard/CHANGELOG.md`, `forge/CHANGELOG.md`, `notify/CHANGELOG.md`) before filing.

---

## Types of contributions welcomed

| Contribution | Process |
|---|---|
| **Bug fix** in an existing plugin | Branch off `main`, fix + test, PR |
| **New skill / agent / hook** inside an existing plugin | Open an issue first describing the use case; agreement → PR |
| **Entirely new plugin** | Open an issue proposing it *before* building. The marketplace keeps scope tight — most needs fit as a skill inside an existing plugin. |
| **Documentation** (READMEs, per-plugin guides, CLAUDE.md) | PR directly. Small wording fixes need no issue. |
| **Tooling gap closures** (from `docs/tooling-gap-reports/`) | Follow the gap closure process described below. |

---

## Repository layout

```
.claude-plugin/marketplace.json   ← registry all three plugins live under
onboard/     ← codebase analyzer + tooling generator
forge/       ← greenfield scaffolder (delegates to onboard for tooling)
notify/      ← cross-platform system notifications
```

Every plugin follows the same convention:

```
<plugin>/
  .claude-plugin/plugin.json      ← manifest (name, version, description, author, license, keywords)
  README.md                       ← user-facing docs
  CHANGELOG.md                    ← per-plugin release notes
  CLAUDE.md                       ← internal conventions for that plugin
  skills/<name>/SKILL.md          ← one directory per skill (YAML frontmatter + instructions)
  agents/<name>.md                ← agent definitions (when applicable)
  scripts/*.sh                    ← shell scripts, ShellCheck-clean, `set -euo pipefail`
```

Components live at the **plugin root**, not inside `.claude-plugin/`. Only `plugin.json` goes in `.claude-plugin/`.

Full conventions: [`CLAUDE.md`](./CLAUDE.md). Read it before submitting a new skill, agent, or script — it codifies naming, frontmatter spelling, and skill-invocation policy.

---

## Development workflow

1. **Fork + branch off `main`.** Branch naming: `type/short-description` where `type ∈ {feat, fix, refactor, docs, chore}`.
   Example: `feat/onboard-mcp-generation`, `fix/notify-subtitle-escaping`.
2. **Keep commits scoped.** One logical change per commit. Use conventional-commit format:
   ```
   type(scope): description
   ```
   `scope` is the plugin name when the change is plugin-specific (`feat(onboard): add verify skill`). Cross-cutting changes can omit the scope.
3. **Run `/validate`** (provided by this repo as a skill) before pushing — it checks all plugins for manifest validity, reference integrity, skill frontmatter, and shell-script sanity.
4. **Push + open PR** against `main`. The PR template prompts for motivation, affected files, and a verification checklist.
5. **Squash-merge** is the default — one PR = one commit on `main`.

---

## Quality bars

- **Shell scripts** pass ShellCheck with no warnings: `shellcheck scripts/*.sh`. Use `#!/usr/bin/env bash` and `set -euo pipefail` (utility scripts) or `exit 0` (hook scripts).
- **JSON manifests** (`plugin.json`, `marketplace.json`) have required fields: `name`, `version`, `description`, `author`, `license`, `keywords`. Version in `plugin.json` must match its entry in `marketplace.json`.
- **Skills** use hyphenated frontmatter (`user-invocable`, `disable-model-invocation`) per the [Claude Code docs](https://code.claude.com/docs/en/skills). Underscore spellings are silently ignored.
- **References** — every file referenced by a skill or agent must exist. `/validate` catches broken refs.
- **No emojis** in code or comments unless explicitly required.
- **Documentation URLs** use the current home `https://code.claude.com/docs/en/*`, not the legacy `docs.anthropic.com` redirects.

---

## Closing a tooling gap

If Anthropic ships a new Claude Code feature and our plugins don't yet generate it, that's a tooling gap. Gaps are surfaced by the recurring audit under `docs/tooling-gap-reports/` — the most recent dated report is the source of truth. Audit cadence and schema live in `docs/tooling-gap-reports/README.md`; the workflow that produces each report is `.github/workflows/tooling-gap-audit.yml`.

Process:
1. Pick an unresolved P0 or P1 finding from the most recent dated gap report.
2. Create a branch: `feat/<plugin>-<short-description>`.
3. Implement against `main`.
4. Open a PR referencing the gap by its item text.
5. Note the closure in the PR description — the next audit run (1st / 15th of the month) will reflect the fix automatically.

Full infra design: `docs/superpowers/specs/2026-04-16-tooling-gap-audit-infrastructure-design.md`.

---

## Testing

- **Plugin smoke test** — after your change, install the plugin in a fresh workspace:
  ```
  claude plugin marketplace add https://raw.githubusercontent.com/ApurvBazari/claude-plugins/main/.claude-plugin/marketplace.json
  claude plugin install <plugin>@apurvbazari-plugins
  ```
  Run the skill or command your change touches. Confirm the user-facing surface still works.
- **Release-gate sweep** — major changes should also run the release-gate audit: `tests/release-gate/run-automated-checks.sh`. Findings land in `tests/release-gate/findings-*.md`.
- **Manual verification** is expected — this repo ships markdown, shell, and JSON; there is no Jest / pytest harness to lean on.

---

## License

By contributing, you agree your contribution is licensed under the [MIT License](./LICENSE).

---

## Recognition

Contributors appear in the commit history. Significant contributions also get called out in the relevant plugin's `CHANGELOG.md`.

Questions? Open a [discussion](https://github.com/ApurvBazari/claude-plugins/discussions) or ping <apurvbazari@live.com>.
