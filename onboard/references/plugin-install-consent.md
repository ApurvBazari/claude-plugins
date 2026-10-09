# Plugin Install Consent — the one rule for every install

Single source of truth for when onboard may install another Claude Code plugin. Every skill, agent and
reference that names `install-plugins.sh` points here instead of describing installs itself. Consumers:
`../agents/config-generator.md`, `../skills/wizard/SKILL.md`, `../skills/update/SKILL.md`,
`../skills/evolve/SKILL.md`, and the MCP and LSP emission specs under
`../skills/generation/references/emission/`.

## The rule

**R1.** A plugin is installed only when an offer naming that plugin was shown to a person in this run
and the person selected it. A skip, a dismissal, no answer, no interactive user, or an absent field
installs nothing.

**R2.** An explicit list from a programmatic caller (`callerExtras.lspPlugins`,
`callerExtras.mcpPlugins`) counts as acceptance by that caller. An absent list means none, never
"all detected".

**R3.** Installs happen only in a full `write` generation that follows an approved `start` gate, or in
an `update` / `evolve` step that has just received the acceptance. A `regenerateOnly` or `reResearch`
generation never installs, even if stored `wizardAnswers` carry an earlier accepted list.

**R4.** Only plugin names from onboard's own hardcoded catalogs
(`../skills/generation/references/catalogs/mcp-guide.md` and
`../skills/generation/references/catalogs/lsp-plugin-catalog.md`) may be offered or installed. A name
from anywhere else is dropped and reported as a warning.

## The offer

One `AskUserQuestion` call, `multiSelect: true`, one option per plugin:

- `label` — the plugin name, exactly as it would be passed to `claude plugin install`.
- `description` — what the plugin adds, and the MCP server or language it belongs to.

Rows for the plugin behind an MCP server start unchecked. LSP rows keep their existing pre-check
(checked at 10 or more source files). A pre-checked row the person submits is an accepted, named offer.

Do not offer a plugin that is already installed. Probe once with `claude plugin list --json`. If the
probe fails, offer every candidate; the installer skips installed plugins.

**Option count.** `AskUserQuestion` needs at least two options. Follow
`.claude/rules/ask-user-question-guard.md`: no candidates, ask nothing; one candidate in a standalone
question, a single-select with the two options `Install <plugin>` and `Skip`, neither marked
recommended; one candidate inside a combined call, pad that group with `None / Skip`.

## When nobody answers

If the prompt cannot be shown, is dismissed, or returns no selection:
install nothing, record nothing as offered, and print the manual command so the person can act later.

> `<plugin>` was not installed. To add it yourself: `claude plugin install <plugin>`

Recording nothing matters. A plugin that was never really offered must be offered again, not
remembered as declined.

## What gets recorded

| Field | Where | Meaning |
|---|---|---|
| `wizardAnswers.mcpPlugins` | wizard output, context, `onboard-meta.json` | Accepted MCP-server plugins. `[]` = offered and declined all, skipped, or nothing to offer. Absent = no offer was made. Both install nothing. |
| `wizardAnswers.lspPlugins` | same | Accepted LSP plugins. `[]` and absent both install nothing. |
| `callerExtras.mcpPlugins`, `callerExtras.lspPlugins` | generation context | A programmatic caller's explicit accepted list (R2). |
| `decisions.pluginInstalls` | generation manifest | Every plugin the write run will install. Shown in the preview; `[]` renders as "none". |
| `mcpStatus.pluginOffers` | `onboard-meta.json` | `{ "offered": [...], "accepted": [...] }`, both sorted alphabetically. `offered` stops a declined plugin being asked about again. |

A project onboarded before 3.3.0 has no `mcpStatus.pluginOffers`. `update` and `evolve` seed it on
first read; see `../skills/update/references/drift-classification.md` § 4b.4.

### Who writes `mcpStatus.pluginOffers`

| Flow | Written by | When |
|---|---|---|
| `start`, full `write` generation | MCP emission Step 5 | Every time, including when nothing was accepted. |
| Repair run (`regenerateOnly` / `reResearch`) | nobody | Never. The stored ledger is left as it is. |
| `update` | Step 8 | When Step 4b.4 seeded it, or an `install-plugin-*` offer was shown and answered. A deferred or dismissed offer is not recorded. |
| `evolve` | Step 2c | The pre-3.3.0 seed at once; `offered` and `accepted` after an answer; nothing for a plugin nobody answered about. |
| `adopt` | baseline synthesis | `offered` = the plugins of catalog servers already in `.mcp.json`; `accepted` = `[]`. |

## The call

Only after an acceptance, and only with the accepted names:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" <accepted-plugin> [<accepted-plugin> ...]
```

Skip the call entirely when the accepted list is empty. The script never fails its caller: read its
JSON (`installed`, `alreadyInstalled`, `failed`) and record the results in the status block's
`autoInstalled` / `autoInstallFailed` keys. Those key names are historical; they record installs that
followed an acceptance.
