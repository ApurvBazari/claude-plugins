# Ecosystem Plugin Install — Canonical Procedure

Single source of truth for the `/onboard:start` Phase 6 ecosystem-plugin-install step: resolving the plugins the developer selected in the wizard (`ecosystemPlugins`), offering inline install for any that are missing, and delegating configuration to each plugin's own setup. This runs as the optional tail of Phase 6 Generation (it does not get its own phase task).

If the wizard answers include `ecosystemPlugins`, set up the requested plugins.

## Resolve Requested Ecosystem Plugins

For each plugin the developer selected in the wizard (`ecosystemPlugins.notify`, etc.), verify it's installed. If it's missing, **offer inline install** — do not skip silently, because the developer explicitly asked for it.

For each requested plugin, probe the filesystem:

```bash
# Check if notify is available
ls "${CLAUDE_PLUGIN_ROOT}/../notify/scripts/notify.sh" 2>/dev/null
```

Characteristic files per plugin:
- `notify` → `scripts/notify.sh`

**If the probe finds the file**, the plugin is installed — proceed to the notify delegation section below (for notify).

**If the probe returns nothing**, the plugin is missing. Tell the developer:

> You selected the **<plugin>** plugin during the wizard, but it's not installed yet.
>
> Install it now? (runs: `claude plugin install <plugin>`)

Use AskUserQuestion with two options:
- **Install now (Recommended)** — run the install command via Bash, then continue
- **Skip setup** — don't configure this plugin; continue with the rest of the flow

**If the developer installs:**
1. Run `claude plugin install <plugin>` via the Bash tool.
2. Re-run the detection probe to verify.
3. **On success** — proceed to the corresponding setup section. If the plugin's slash commands/scripts aren't immediately available, note: "Plugin installed, but its scripts may not be on disk yet until you restart the session. If setup fails, restart Claude Code and rerun `/onboard:start`."
4. **On install failure** — surface the underlying error verbatim. Then emit the explicit skip message below and continue with the next requested plugin.

**If the developer skips or install fails**, emit a clear skip message (never silent):

> Skipping **<plugin>** setup. You can install it later with `claude plugin install <plugin>` and run its setup command directly (`/notify:setup`, etc.).

Then continue to the next requested plugin. Repeat for each entry in `ecosystemPlugins`.

**Edge case** — if a plugin was NOT requested in the wizard (`ecosystemPlugins.<plugin>` is `false` or absent), skip it entirely. Do not probe, do not prompt. This procedure only acts on what the developer explicitly asked for.

**Guard Usage:** both options above are **fixed** (Install now / Skip setup), so the single-option guard in `.claude/rules/ask-user-question-guard.md` does not apply.

## Set Up Notify (if requested and available)

If `ecosystemPlugins.notify` is `true` and notify is installed, **delegate configuration to the notify plugin** — `/notify:setup` owns notify wiring and already handles global-vs-per-project scope and detects any pre-existing global config. onboard does **not** copy `notify.sh`, write a `notify-config.json`, run `install-notifier.sh`, or merge notify hooks into this project's `settings.json` — doing so would duplicate (and silently diverge from) whatever `/notify:setup` manages.

Tell the developer:

> The **notify** plugin is installed. Run `/notify:setup` to turn on system notifications — it lets you pick global (all projects) or this-project-only scope and skips anything already configured globally.

If notify was just installed in this step and its scripts aren't on disk yet, the same `/notify:setup` instruction applies once the session is restarted.

## Report Ecosystem Setup

> **Ecosystem plugins:**
> - [list each requested plugin and whether it's installed / was just installed / skipped]
>
> To finish configuring:
> - Notify: run `/notify:setup`

If no plugins were requested or available, skip this report entirely.
