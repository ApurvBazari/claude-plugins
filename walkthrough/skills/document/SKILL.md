---
name: document
description: Render any SUBJECT (a plugin, library, subsystem, or the marketplace) as a self-contained interactive HTML document in the walkthrough house style. Use when the user asks to "document this plugin", "make a docs page for <subject>", "generate the plugin landing page", or runs /walkthrough:document <subject>. Reads README + manifest as canonical source. Writes to the path given, default .claude/walkthrough/.
---

# Document — Render a Subject as an Interactive Document

You are invoked via `/walkthrough:document <subject> [output-path]`. Produce ONE self-contained
interactive HTML file in the house style from a *subject* (not the session), then offer to open it.
The visual layer is reused verbatim from the `create` skill; only the model and gathering differ.

Renderer files (reuse UNCHANGED, via relative path from this skill):
`../create/references/design-system.md`, `../create/references/interactivity.md`,
`../create/references/page-scaffold.md`, `../create/references/authoring-guide.md`,
`../create/references/components/` (catalog; `index.md` routes to group files).

## Step 1: Identify the subject
`<subject>` is the first argument — a plugin directory, the word `marketplace` (or repo root), or
any path/description. Route to the right adapter per `references/gather-subject.md`.

## Step 2: Gather (README + manifest are canonical)
Follow `references/gather-subject.md` and the matched adapter
(`references/adapters/plugin.md` or `references/adapters/marketplace.md`). Read the canonical
source files. Cite `path:line` only when verified by a real read.

## Step 3: Synthesize the subject model
Build the structured model per `references/subject-model.md` (title, tagline, summary, typeTags,
install, sections[], nodes[], edges[], reference[], examples[], links[], details{}) BEFORE any HTML.

## Step 4: Select components
Using `../create/references/authoring-guide.md`, map the model to component names, then look each up
in `../create/references/components/index.md` for its group file. Apply "omit empty, never stub".
For the marketplace card grid (and anything else with no catalog entry), compose a bespoke component
per the authoring-guide recipe + looks-native checklist.

## Step 5: Assemble the HTML
Start from `../create/references/page-scaffold.md`. Inline: the `@import` + both `:root` blocks from
`design-system.md`; the shared JS from `interactivity.md`; the CSS+HTML for each chosen component
(read only the `components/<group>.md` files for components you selected); the `DET`/detail data.
Self-contained: no `<script src>`, no `<link rel=stylesheet>`, no `<img>` — only the one Google
Fonts `@import`. Internal links MUST be relative (`./onboard/`, `../`) — never root-absolute.

## Step 6: Output path
If a second argument (output path) is given, write there. Otherwise default to
`.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html` (`slug` = kebab of the title; collisions → `-2`,
`-3`, …). For the site convention, the caller passes `site/<plugin>/index.html` (or
`site/index.html` for the marketplace). Create parent directories if missing.

## Step 7: Write the file
Write the assembled HTML to the Step 6 path. (No gitignore prompt — unlike `create`, `document`
output is a published/derived artifact, not private session content.)

## Step 8: Offer to open
Tell the user the path (under three lines). Offer `open "<path>"` (macOS; `xdg-open` on Linux).
Do not auto-open.

## Key Rules
- **One look-and-feel.** Tokens only — never raw hex. Reproduce `design-system.md` patterns.
- **Self-contained.** All CSS/JS/SVG inline; only the Google Fonts `@import` is external.
- **README is canonical.** Never invent content not grounded in the subject's source files.
- **Model before markup.** Synthesize the subject model (Step 3) before assembling HTML.
- **Omit empty, never stub.** Render only components with real content.
- **Relative links only.** Internal cross-links use `./` or `../`, never `/…` (Pages base path).
- **Real code refs only.** Cite `path:line` only when verified via a file read.
- **Read-only.** Never execute subject code; only read files.
