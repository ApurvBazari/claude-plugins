# Plugin Surface Probe

Canonical procedure for classifying each detected plugin's entry surface (commands / skills / hooks / agents) BEFORE emitting references to it in generated CLAUDE.md. Closes 2026-04-17 release-gate finding G.3 (fabricated `/security-guidance:security-review` for a hooks-only plugin) and the broader G-audit (G.1, G.4, G.5.2-6 routing disambiguation).

## Why this exists

Before the 2026-04-18 refactor, the Plugin Integration template emitted `/<plugin>:<slug>` refs for every entry in `installedPlugins` without checking whether those slash commands actually existed on disk. `security-guidance/` is a hooks-only plugin — no `commands/`, no `skills/` — but the generated CLAUDE.md still referenced `/security-guidance:security-review`. Invoking that command would fail; referencing it in docs misleads the developer.

## When to invoke

Called from `init/SKILL.md` Phase 2.5.2 (Probe Plugin Surfaces) and from `generate/SKILL.md` as a fallback when `callerExtras.pluginSurfaces` is absent. Outputs the `pluginSurfaces` map, which feeds the Plugin Integration template in `claude-md-guide.md`.

## Inputs

`installedPlugins` array (from the deep probe in `plugin-detection-guide.md § Known Plugin Probe List`). Each entry is a plugin name — e.g., `"security-guidance"`, `"superpowers"`, `"code-review"`.

## Output

A `pluginSurfaces` object keyed by plugin name:

```jsonc
{
  "pluginSurfaces": {
    "superpowers": {
      "type": "command-or-skill",
      "commands": [],
      "skills": ["brainstorming", "writing-plans", "test-driven-development",
                 "systematic-debugging", "verification-before-completion",
                 "executing-plans", "finishing-a-development-branch"],
      "hooks": [],
      "agents": []
    },
    "security-guidance": {
      "type": "hooks-only",
      "commands": [],
      "skills": [],
      "hooks": [
        { "event": "PreToolUse:Write", "behavior": "secret-literal-scan" },
        { "event": "UserPromptSubmit", "behavior": "sensitive-pattern-detection" }
      ],
      "agents": []
    },
    "feature-dev": {
      "type": "command-and-agent",
      "commands": ["feature-dev"],
      "skills": [],
      "hooks": [],
      "agents": ["code-architect", "code-reviewer", "code-explorer"]
    }
  }
}
```

### Surface type enum

| Type value | When it applies |
|---|---|
| `"command-or-skill"` | Plugin has `commands/*.md` OR `skills/*/SKILL.md` (at least one user-invocable). Safe to emit slash refs. |
| `"hooks-only"` | Plugin has `hooks/` but NO `commands/` AND NO user-invocable `skills/`. Emit hook-behavior narrative instead of slash refs. |
| `"agent-only"` | Plugin has `agents/*.md` but no other user-facing surface. Emit agent refs only. |
| `"command-and-agent"` | Plugin has commands/skills AND agents. Emit both slash refs and agent refs. |
| `"hooks-and-agent"` | Hooks + agents, no commands/skills. Emit hook narrative + agent refs. |
| `"empty"` | No discoverable surface (misconfigured plugin). Skip the plugin entirely in Plugin Integration — log a warning. |

## Probe procedure — per plugin

For each plugin name `P` in `installedPlugins`, resolve the plugin root using the same two-location search as `plugin-detection-guide.md § Known Plugin Probe List`:

```bash
# 1. Dev-repo siblings
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/../${P}" ]; then
  ROOT="${CLAUDE_PLUGIN_ROOT}/../${P}"

# 2. Marketplace cache (versioned dir)
elif ROOT=$(ls -d "$HOME/.claude/plugins/cache"/*/"${P}"/*/ 2>/dev/null | head -1); then
  ROOT="${ROOT%/}"

# 3. Marketplace cache (unversioned)
elif ROOT=$(ls -d "$HOME/.claude/plugins/cache"/*/"${P}"/ 2>/dev/null | head -1); then
  ROOT="${ROOT%/}"

else
  # Plugin isn't actually installed — caller shouldn't have added it to
  # installedPlugins. Skip and log a warning.
  continue
fi
```

### Step 1: Enumerate `commands/`

```bash
COMMANDS=()
if [ -d "$ROOT/commands" ]; then
  while IFS= read -r -d '' cmd; do
    # Derive the slash-form slug from the filename
    SLUG=$(basename "$cmd" .md)
    COMMANDS+=("$SLUG")
  done < <(find "$ROOT/commands" -maxdepth 1 -name '*.md' -type f -print0)
fi
```

### Step 2: Enumerate user-invocable `skills/`

Skills with `user-invocable: false` in frontmatter are internal building blocks — DO NOT expose them as slash refs.

```bash
SKILLS=()
if [ -d "$ROOT/skills" ]; then
  while IFS= read -r -d '' skill; do
    # Parse YAML frontmatter for name + user-invocable
    SKILL_DIR=$(dirname "$skill")
    SKILL_NAME=$(grep -E '^name:' "$skill" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"')
    [ -z "$SKILL_NAME" ] && SKILL_NAME=$(basename "$SKILL_DIR")

    USER_INVOCABLE=$(grep -E '^user-invocable:' "$skill" | head -1 | sed 's/^user-invocable:[[:space:]]*//' | tr -d '"')
    # Default is true — only exclude when explicitly false
    if [ "$USER_INVOCABLE" != "false" ]; then
      SKILLS+=("$SKILL_NAME")
    fi
  done < <(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -print0)
fi
```

### Step 3: Enumerate `hooks/`

Parse `hooks/hooks.json` if present (canonical). Fall back to listing `hooks/*.sh` and extracting intent from filenames if the JSON is missing or malformed.

```bash
HOOKS=()
if [ -f "$ROOT/hooks/hooks.json" ]; then
  # Parse the manifest. Output format: one { "event": ..., "behavior": ... } per entry.
  while IFS= read -r entry; do
    HOOKS+=("$entry")
  done < <(jq -c '[.hooks // {} | to_entries[] |
    .key as $ev | .value[] |
    {event: $ev, behavior: (.description // .matcher // .command // "unknown")}
  ] | .[]' "$ROOT/hooks/hooks.json" 2>/dev/null)
fi

# Fallback: scan shebangs + filenames
if [ ${#HOOKS[@]} -eq 0 ] && [ -d "$ROOT/hooks" ]; then
  while IFS= read -r -d '' hook; do
    BASENAME=$(basename "$hook" .sh)
    HOOKS+=("{\"event\":\"unknown\",\"behavior\":\"$BASENAME\"}")
  done < <(find "$ROOT/hooks" -maxdepth 1 -name '*.sh' -type f -print0)
fi
```

### Step 4: Enumerate `agents/`

```bash
AGENTS=()
if [ -d "$ROOT/agents" ]; then
  while IFS= read -r -d '' agent; do
    AGENT_NAME=$(grep -E '^name:' "$agent" | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '"')
    [ -z "$AGENT_NAME" ] && AGENT_NAME=$(basename "$agent" .md)
    AGENTS+=("$AGENT_NAME")
  done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f -print0)
fi
```

### Step 5: Classify the surface type

```
if commands + skills non-empty AND agents non-empty:
  type = "command-and-agent"
elif commands + skills non-empty AND hooks non-empty:
  # Hooks are secondary; slash refs still safe.
  type = "command-or-skill" with hookHints
elif commands + skills non-empty:
  type = "command-or-skill"
elif hooks non-empty AND agents non-empty:
  type = "hooks-and-agent"
elif hooks non-empty:
  type = "hooks-only"
elif agents non-empty:
  type = "agent-only"
else:
  type = "empty"  # log warning; skip plugin
```

## Disambiguation rules

When the assembled `installedPlugins` list triggers routing conflicts between plugins with overlapping descriptions (observed in release-gate findings G.1, G.4, G.5.2-6), apply these rules in order. Each rule outputs guidance consumed by the Plugin Integration template in `claude-md-guide.md`.

### R1 — Superpowers suppresses feature-dev top-level orchestration

When `superpowers` + `feature-dev` are both installed: drop `feature-dev:feature-dev` from top-level Plugin Integration entries. Keep `feature-dev:code-architect` as an adjunct tool (invoked during superpowers phase 4 if needed).

**Rationale**: `superpowers:brainstorming.description` uses "You MUST" imperative plus keyword "creating features" — wins auto-invoke tiebreak. Once brainstorming fires, `SKILL.md:66` forbids invoking anything other than writing-plans. `feature-dev:feature-dev` as a top-level entry is effectively dead code in any superpowers-installed project (G.2, G.5.2).

Emit narrative:

> Feature work: start with `/superpowers:brainstorming`. Architecture sub-decisions can be delegated to `feature-dev:code-architect` as an adjunct tool during brainstorming's phase 4.

### R2 — Code-review vs pr-review-toolkit disambiguation

When `code-review` + `pr-review-toolkit` are both installed:

Emit narrative:

> - `/code-review:code-review` — **light review**. Single-pass command. Use for iterative in-session reviews.
> - `/pr-review-toolkit:review-pr` — **heavy review**. Runs 6 specialized sub-agents (code-reviewer, silent-failure-hunter, code-simplifier, comment-analyzer, pr-test-analyzer, type-design-analyzer). Use before finalizing a PR for merge.

### R3 — Frontend-design owns UI feature work

When `frontend-design` is installed AND the project's detected stack includes a frontend framework (Next.js, React, Vue, Svelte, Astro, Remix, SolidJS):

Emit narrative:

> UI feature work: `frontend-design:frontend-design` owns web component / page / application generation. Non-UI feature work defaults to the superpowers → feature-dev flow above.

### R4 — Agent name collisions — always plugin-prefixed

Agents like `code-reviewer` exist under both `feature-dev:` and `pr-review-toolkit:`. Always emit the plugin-prefixed form in CLAUDE.md agent references — never the bare name.

Examples:

- ✅ `feature-dev:code-reviewer` (adjunct to feature-dev phase 6)
- ✅ `pr-review-toolkit:code-reviewer` (runs inside the heavy-review command)
- ❌ `code-reviewer` (ambiguous — tells Claude nothing about which to pick)

### R5 — Superpowers pipeline self-containment note

When `superpowers` is installed, add a short clarifying note to the Plugin Integration section:

> Note: superpowers' `brainstorming → writing-plans` forms a self-contained pipeline. It does not invoke external plugins mid-flow (per `brainstorming/SKILL.md:66`). If you want to interrupt to use another plugin, finish the current brainstorming exchange first.

### R6 — Hooks-only plugin narrative

When a plugin's `pluginSurfaces[<p>].type === "hooks-only"`, emit a narrative paragraph derived from the probed hook events. Do NOT invent `/<p>:<slug>` references.

Template:

> `<plugin>` hooks fire on <event1, event2, ...> to <behavior1; behavior2; ...>. No slash commands — behavior is always automatic.

Example for `security-guidance`:

> `security-guidance` hooks fire on PreToolUse:Write (secret-literal-scan) and UserPromptSubmit (sensitive-pattern-detection). No slash commands — behavior is always automatic.

When hook behavior cannot be resolved from `hooks.json`, fall back to filename-derived description:

> `<plugin>` is hooks-only. Installed hook scripts: <list of filenames>. See `<plugin>/README.md` for event details.

## Edge cases

1. **Plugin has both `commands/` and `skills/`** — enumerate both, merge slash refs. Classify as `command-or-skill`.

2. **Plugin has all four surfaces** — classify as `command-and-agent` if slash surfaces + agents; include a secondary note about hooks.

3. **Skill's `name` frontmatter differs from its directory** — prefer the frontmatter `name` for the slash ref. Falls back to directory name only if frontmatter is missing.

4. **Skill has `user-invocable: false`** — exclude from slash refs entirely. Classify under the plugin's type but omit from user-facing references.

5. **Plugin manifest missing (`plugin.json` absent)** — probe its directories anyway; surface probe is based on file structure, not manifest.

6. **hooks.json malformed** — fall back to filename scan. If still empty, emit the "hooks-only fallback" narrative without specific event/behavior info.

7. **Plugin directory exists but is empty** — `type: "empty"`, skip in Plugin Integration, emit a warning.

8. **Plugin with legacy `commands/` directory** — enumerate anyway (repo convention says commands/ is deprecated per `.claude/rules/plugin-structure.md`, but many third-party plugins still use it). Treat as `command-or-skill` surface.

## Integration points

- `init/SKILL.md § Phase 2.5.2` — primary caller during interactive init
- `generate/SKILL.md` — fallback when `callerExtras.pluginSurfaces` is absent (forge-path)
- `plugin-drift-detection.md § Probe Procedure` — re-runs this procedure when drift is detected to pick up newly-surfaced or surface-changed plugins
- `claude-md-guide.md § Plugin Integration template` — consumes the `pluginSurfaces` map and applies R1-R6 disambiguation rules
- `evolve/SKILL.md` — reads `pluginSurfaces` from the meta file during drift evaluation

## Key rules

1. **Never emit slash refs without surface verification** — every `/<plugin>:<slug>` in the generated CLAUDE.md must correspond to an actual file at `<plugin>/commands/<slug>.md` OR `<plugin>/skills/<slug>/SKILL.md`.
2. **Hooks-only plugins get behavior narratives, not slash refs** — fabricating commands was the B13 / G.3 class of bug. This is a hard rule.
3. **Disambiguation rules apply in order** — R1 runs first (feature-dev suppression), then R2-R6 in sequence. Some rules are conditional on combinations of plugins being present.
4. **Respect `user-invocable: false`** — never expose internal-only skills as user-facing slash refs.
5. **Fail open on malformed hooks manifests** — never crash the generation phase because a third-party plugin has a broken `hooks.json`. Fall back gracefully.
