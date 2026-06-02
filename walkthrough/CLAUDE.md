# walkthrough — Internal Conventions

Render the current session as a self-contained interactive HTML document with diagrams and clickable detail. Single skill, single output artifact, no hooks. Closest existing plugin in shape is `handoff/` (skill + script + optional in-repo settings file), but the heavy lifting lives in the skill's `references/`, which together form the renderer.

## Locked design dimensions

| Dimension | Choice | Reason |
|---|---|---|
| **Name / slash** | `walkthrough` → `/walkthrough:create [focus]` | One verb; the optional arg scopes synthesis to a focus |
| **Trigger** | User-invocable AND model-invocable (default frontmatter) | On-demand artifact; also auto-fires on "visualize this session" / "session recap" intent |
| **Output** | ONE self-contained interactive HTML file | Portable, archivable, openable anywhere with no plugin, server, or build step |
| **Design system** | ONE house style, tokens only | Consistent look across every walkthrough; no per-run theming drift |
| **Themes** | Dark + warm-light, in-document toggle | Two `:root` blocks; viewer picks per-view, no rebuild |
| **Component system** | Open — catalog is a floor, not a ceiling | Bespoke components composed from primitives when content fits no catalog entry |
| **Rendering** | Inline everything (CSS/JS/SVG); only external is a Google Fonts `@import` | Self-containment is the core promise — no CDN scripts, no `<img>`, no `<script src>` |
| **Storage** | `.claude/walkthrough/<ts>-<slug>.html`, in-repo, gitignore prompt on first run | Mirrors handoff's in-repo + gitignore-by-default privacy model |

## The 5-stage pipeline

The `create` skill runs a fixed model-before-markup pipeline. The model is fully synthesized before a single tag is written.

```
┌──────────┐   ┌─────────────┐   ┌──────────┐   ┌────────────┐   ┌─────────┐
│  gather  │ → │ synthesize  │ → │  select  │ → │  assemble  │ → │  write  │
│          │   │             │   │          │   │            │   │         │
│ git ctx  │   │ session     │   │ map model│   │ inline     │   │ to      │
│ + cited  │   │ model       │   │ → comps  │   │ scaffold + │   │ .claude/│
│ file     │   │ (sections,  │   │ (catalog │   │ tokens +   │   │ walk-   │
│ reads    │   │ nodes,edges,│   │ floor +  │   │ JS + comps │   │ through/│
│          │   │ decisions,  │   │ bespoke  │   │ + detail   │   │ + git-  │
│          │   │ files, …)   │   │ escape)  │   │ data)      │   │ ignore  │
└──────────┘   └─────────────┘   └──────────┘   └────────────┘   └─────────┘
   Step 2         Step 3            Step 4          Step 5        Steps 6–8
```

1. **gather** — run `collect-git-context.sh` (read-only) for branch / diffstat / changed files / recent log; read any source file you intend to cite so `path:line` refs are real.
2. **synthesize** — build the structured session model per `references/session-model.md` (`title`, `summary`, `typeTags`, `sections[]`, `nodes[]`, `edges[]`, `decisions[]`, `files[]`, `timeline[]`, `metrics[]`, `openQuestions[]`, `details{}`) BEFORE any HTML.
3. **select** — map the model to components via `references/authoring-guide.md` + `references/components.md`; apply "omit empty, never stub"; compose bespoke where no catalog entry fits.
4. **assemble** — start from `references/page-scaffold.md`; inline the `@import` + both `:root` blocks from `references/design-system.md`, the shared JS from `references/interactivity.md`, and the CSS/HTML for each chosen component plus its detail (`DET`) data.
5. **write** — compute `.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html` (collision → `-2`, `-3`, …), create the dir if missing, handle the first-run gitignore prompt, then write and offer to open (never auto-open).

## Design-system invariant + self-contained rules

These two invariants are non-negotiable — they are what make every walkthrough recognizably the same artifact and portable.

- **Tokens only.** Reproduce the signature patterns from `references/design-system.md`. Never emit a raw hex value, raw font name, or raw spacing literal — go through the CSS custom properties. Both the dark and warm-light themes are expressed as `:root` token blocks; the toggle swaps token sets, not stylesheets.
- **Self-contained.** All CSS, JS, and SVG are inlined into the single HTML file. The **only** permitted external resource is the Google Fonts `@import` at the top of the style block. No `<script src>`, no `<link rel=stylesheet>`, no `<img>`, no CDN libraries. The file must render with no network beyond that one font fetch.

## The open component system

The component catalog in `references/components.md` is a **floor, not a ceiling**.

- For content that maps cleanly to a catalog entry, use the catalog entry verbatim (CSS + HTML).
- For content that fits no catalog entry, **compose a bespoke component** following the recipe in `references/authoring-guide.md`. Bespoke components are built from the same design-system primitives (tokens, type scale, spacing, the shared JS toggle/expand helpers) and must pass the authoring-guide "looks-native" checklist — they should be indistinguishable in style from catalog components.
- "Omit empty, never stub": a component is rendered only when the model has real content for it. No placeholder cards, no "N/A" rows.

The escape hatch keeps the catalog small without forcing odd sessions into ill-fitting components.

## Script safety

`scripts/collect-git-context.sh` is the only executable. It is a **read-only utility**, not a hook, and it follows the utility-script half of the shell conventions with one deliberate exception for resilience:

- `#!/usr/bin/env bash`
- `set -uo pipefail` (NOT `-e` — like a hook, it must never abort the skill; it degrades to a minimal JSON object instead)
- **Always `exit 0`** — outside a repo or on any git failure it prints `{"in_repo": false}` (or a partial object) and exits clean
- **Read-only** — only `git rev-parse` / `branch` / `status --porcelain` / `diff --stat` / `log --oneline`; never writes, never executes session-derived code
- JSON-escapes values (backslashes then double quotes) and caps list sizes (`head -50`, `-15`) so output stays bounded
- POSIX `awk`/`sed`, ShellCheck-clean

The skill invokes it via the in-plugin form per `.claude/rules/plugin-script-paths.md`:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/collect-git-context.sh" "$PWD"
```

`test-collect-git-context.sh` is a colocated smoke test for the helper — not shipped behavior, but kept in `scripts/` so the read-only contract stays covered.

## Skills

One user-facing skill (shows in `/walkthrough:` autocomplete):

- `create/SKILL.md` — user- and model-invocable (default frontmatter, no `disable-model-invocation`). It is the entire entrypoint; the six `references/` files are its renderer.

No internal building blocks (no `user-invocable: false` skills), no agents, no hooks.

## AskUserQuestion usage

The skill makes two fixed-length `AskUserQuestion` calls — the thin-session prompt (2 options) and the first-run gitignore prompt (3 options). Both are hardcoded option lists, so the single-option failure mode does not apply; the skill still references `.claude/rules/ask-user-question-guard.md` per the convention for any skill that uses the tool.
