# walkthrough — Internal Conventions

Render an explorable, self-contained interactive HTML document — from one of **two input modes**: a *session* (`create` renders from scratch, `update` refreshes in place) or a *subject* (`document` renders a plugin, the marketplace, or any path). Three skills, one shared visual layer, one output artifact per run, no hooks. Closest existing plugin in shape is `handoff/` (skills + optional in-repo settings file, no scripts), but the heavy lifting lives in the skills' `references/`, which together form the renderer.

The visual layer (`create/references/`: `design-system.md`, `interactivity.md`, `page-scaffold.md`, `authoring-guide.md`, `components/`, `self-check.md`, `completeness.md`) is shared across all three skills. `update` and `document` reuse it unchanged and bring only what differs: `update` adds `reconstruct-and-merge.md`; `document` swaps the model — its own `subject-model.md` + `gather-subject.md` + `adapters/` replace `create`'s session model.

## Locked design dimensions

| Dimension | Choice | Reason |
|---|---|---|
| **Name / slash** | `walkthrough` → `/walkthrough:create [focus]` | One verb; the optional arg scopes synthesis to a focus |
| **Trigger** | User-invocable AND model-invocable (default frontmatter) | On-demand artifact; also auto-fires on "visualize this session" / "session recap" / "walk me through it" intent |
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
│ session  │   │ session     │   │ map model│   │ inline     │   │ to      │
│ + cited  │   │ model       │   │ → comps  │   │ scaffold + │   │ .claude/│
│ file     │   │ (sections,  │   │ (catalog │   │ tokens +   │   │ walk-   │
│ reads    │   │ nodes,edges,│   │ floor +  │   │ JS + comps │   │ through/│
│          │   │ decisions,  │   │ bespoke  │   │ + detail   │   │ + git-  │
│          │   │ files, …)   │   │ escape)  │   │ data)      │   │ ignore  │
└──────────┘   └─────────────┘   └──────────┘   └────────────┘   └─────────┘
   Step 2         Step 3            Step 4          Step 5        Steps 6–8
```

1. **gather** — read any source file you intend to cite so `path:line` refs are real. The session transcript is the source of record; there is no repository scan.
2. **synthesize** — build the structured session model per `references/session-model.md` (`title`, `summary`, `typeTags`, `sections[]`, `nodes[]`, `edges[]`, `decisions[]`, `files[]`, `timeline[]`, `metrics[]`, `openQuestions[]`, `details{}`) BEFORE any HTML.
3. **select** — map the model to components via `references/authoring-guide.md` + the `references/components/` catalog (look up each chosen component in `components/index.md`); apply "omit empty, never stub"; compose bespoke where no catalog entry fits.
4. **assemble** — start from `references/page-scaffold.md`; inline the `@import` + both `:root` blocks from `references/design-system.md`, the shared JS from `references/interactivity.md`, and the CSS/HTML for each chosen component (read only the `references/components/<group>.md` files for the components you selected) plus its detail (`DET`) data.
5. **write** — compute `.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html` (collision → `-2`, `-3`, …), create the dir if missing, handle the first-run gitignore prompt, then write and offer to open (never auto-open).

## The update skill — reconstruct, merge, overwrite in place

`update` does not persist or re-read a session model; the existing HTML is the only prior record. It adds two stages in front of create's renderer:

```
┌─────────────┐   ┌────────┐   ┌──────────── reuses create stages ──────────────┐
│ reconstruct │ → │ merge  │ → │  select  →  assemble  →  write (IN PLACE)       │
│ model from  │   │ prior  │   │  (authoring-guide + components + scaffold)      │
│ rendered    │   │ + new  │   │                                                 │
│ HTML (DET)  │   │ named  │   │                                                 │
│             │   │ files  │   │                                                 │
└─────────────┘   └────────┘   └─────────────────────────────────────────────────┘
```

- **Target picker is the overwrite safety gate.** `update` always confirms which `.claude/walkthrough/*.html` to refresh (yes/no when one exists; a 2–4-option list, plus the tool's built-in "Other", otherwise), even when model-invoked. No silent-overwrite path. Picker option lists are fixed-length per `.claude/rules/ask-user-question-guard.md`.
- **Reconstruct from HTML.** Part A of `references/reconstruct-and-merge.md` maps rendered anchors back to the `session-model` schema; the trailing `const DET={…}` store is the high-fidelity source for `details{}`. No model island, no sidecar — `create` is untouched.
- **Named files drive, conversation frames.** The command arguments are the changed spec/source files; no automatic git discovery. No args → `update` asks which files changed. The nav kicker is session metadata (date · type · scope), not git.
- **Merge into one coherent doc.** Part B: revise superseded content, merge overlaps, add new, keep `sections[].id` / `details{}` keys stable, then hand to create's renderer.
- **Overwrite in place, seamless.** Same filename, no new file, no backup, no update chrome. Repeated reconstruct→overwrite cycles can accumulate minor structural drift; the escape hatch is a fresh `create`.
- **Invocation is a deliberate deviation.** `update` keeps default (user + model) frontmatter even though it overwrites in place — diverging from the repo's "destructive → `disable-model-invocation`" convention (root `CLAUDE.md` § Skill Frontmatter Categories; `.claude/rules/skills-authoring.md` names `update` as a typical lock candidate). The always-on target picker (Step 1) is an unbypassable confirm gate that substitutes for the invocation lock, so model-invocation cannot cause a silent overwrite. Decided during brainstorming (2026-06-02).

## Design-system invariant + self-contained rules

These two invariants are non-negotiable — they are what make every walkthrough recognizably the same artifact and portable.

- **Tokens only.** Reproduce the signature patterns from `references/design-system.md`. Never emit a raw hex value, raw font name, or raw spacing literal — go through the CSS custom properties. Both the dark and warm-light themes are expressed as `:root` token blocks; the toggle swaps token sets, not stylesheets.
- **Self-contained.** All CSS, JS, and SVG are inlined into the single HTML file. The **only** permitted external resource is the Google Fonts `@import` at the top of the style block. No `<script src>`, no `<link rel=stylesheet>`, no `<img>`, no CDN libraries. The file must render with no network beyond that one font fetch.
- **Section kickers are auto-numbered.** A CSS counter on `.sec-label` increments automatically — authors write only the label text, never a hard-coded number.

## Pre-write gates

Two model-performed gates run before write, shared by all three skills: `self-check.md` (structure — self-contained, tokens, ASCII CSS, nav↔id, DET keys) and `completeness.md` (coverage — the salient-item critic after synthesis + the coverage note at the offer step).

## The open component system

The component catalog in `references/components/` (indexed by `components/index.md`) is a **floor, not a ceiling**.

- For content that maps cleanly to a catalog entry, use the catalog entry verbatim (CSS + HTML).
- For content that fits no catalog entry, **compose a bespoke component** following the recipe in `references/authoring-guide.md`. Bespoke components are built from the same design-system primitives (tokens, type scale, spacing, the shared JS toggle/expand helpers) and must pass the authoring-guide "looks-native" checklist — they should be indistinguishable in style from catalog components.
- "Omit empty, never stub": a component is rendered only when the model has real content for it. No placeholder cards, no "N/A" rows.

The escape hatch keeps the catalog small without forcing odd sessions into ill-fitting components.

First-class catalog additions in v0.4.0:
- **`components/interactive.md`** — two new components: interactive explorer (expandable node graph) and data-driven step timeline.
- **`.chip` primitive** — five status roles: `ok`, `info`, `warn`, `danger`, `neutral`. Use inline within any component for status badges.

## Skills

Three user-facing skills (all show in `/walkthrough:` autocomplete; all default frontmatter — user- and model-invocable, no `disable-model-invocation`):

- `create/SKILL.md` — renders the current session from scratch. The renderer is five `references/` files plus the `references/components/` catalog (`index.md` + per-group recipes loaded on demand).
- `update/SKILL.md` — refreshes an EXISTING walkthrough in place: reconstructs the prior model from the rendered HTML, merges in explicitly-named files, and overwrites the same file. Reuses `create`'s renderer references unchanged for the render half (five `references/` files + the `components/` catalog); its own `references/reconstruct-and-merge.md` covers the reconstruct + merge stages.
- `document/SKILL.md` — renders a *subject* (a plugin, the marketplace, or any path) instead of a session. Reuses `create`'s visual-layer references unchanged; brings its own `references/subject-model.md`, `references/gather-subject.md`, and `references/adapters/` (plugin + marketplace). README + manifest are canonical; the output path is an argument (the docs site passes `site/<plugin>/index.html`). No gitignore prompt — output is a published/derived artifact, not private session content.

No internal building blocks (no `user-invocable: false` skills), no agents, no hooks, no scripts.

## AskUserQuestion usage

`create` makes up to three `AskUserQuestion` calls: the thin-session prompt (2 options), the first-run gitignore prompt (3 options), and — conditionally — a proliferation-guard prompt (3 options) triggered when a same-subject slug already exists in `.claude/walkthrough/`. `update` adds the target picker, whose options are built **dynamically** from the `.claude/walkthrough/` listing — kept fixed-length per the guard: a yes/no confirm when a single doc exists, and a 2–4-option list (plus the tool's built-in "Other") otherwise. Because the list is dynamic, the guard's single-option case is handled by the yes/no form. Both skills reference `.claude/rules/ask-user-question-guard.md` per the convention for any skill that uses the tool.
