---
name: document
description: Render any SUBJECT (a plugin, library, subsystem, or the marketplace) as a self-contained interactive HTML document in the walkthrough house style. Use when the user asks to "document this plugin", "make a docs page for <subject>", "generate the plugin landing page", "map this codebase's architecture", "draw a system map of this repo", or runs /walkthrough:document <subject>. Reads README + manifest as canonical source; for a codebase's architecture it reads the code itself and shows where each part was seen. Writes to the path given, default .claude/walkthrough/.
---

# Document — Render a Subject as an Interactive Document

You are invoked via `/walkthrough:document <subject> [output-path]`. Produce ONE self-contained
interactive HTML file in the house style from a *subject* (not the session), then offer to open it.
The visual layer is reused verbatim from the `create` skill; only the model and gathering differ.

Renderer files (reuse UNCHANGED, via relative path from this skill):
`../create/references/design-system.md`, `../create/references/interactivity.md`,
`../create/references/page-scaffold.md`, `../create/references/authoring-guide.md`,
`../create/references/components/` (catalog; `index.md` routes to group files).

Two more files are named here because a path is only filled in inside a skill's own text:

- the system-map layout engine, needed by any page that has a system map:
  `${CLAUDE_PLUGIN_ROOT}/skills/create/references/system-map-engine.js` (the same file as
  `${CLAUDE_SKILL_DIR}/../create/references/system-map-engine.js`). Step 9 uses it;
- the reading rules of the system adapter: `${CLAUDE_PLUGIN_ROOT}/references/system-reading.md` (the
  same file as `${CLAUDE_SKILL_DIR}/../../references/system-reading.md`). Step 2 passes this path to
  the adapter's agents.

## Step 1: Identify the subject
`<subject>` is the first argument — a plugin directory, the word `marketplace` (or repo root), a
codebase whose architecture you are asked to map, or any path/description. Route to the right adapter
per `references/gather-subject.md`.

## Step 2: Gather (README + manifest are canonical, except for the system adapter)
Follow `references/gather-subject.md` and the matched adapter (`references/adapters/plugin.md`,
`references/adapters/marketplace.md` or `references/adapters/system.md`). Read the canonical
source files. Cite `path:line` only when verified by a real read.

The **system adapter** reads code, not a README. It dispatches the read-only `walkthrough:system-analyzer`
agent and then the read-only `walkthrough:system-verifier` agent, applies the verifier's verdicts, and
falls back to doing both passes itself when agents cannot be dispatched. Follow
`references/adapters/system.md` step by step; for that adapter, machine-read files beat prose.

## Step 3: Synthesize the subject model
Build the structured model per `references/subject-model.md` (title, tagline, summary, typeTags,
install, sections[], nodes[], edges[], graphs[], reference[], examples[], links[], details{}) BEFORE any HTML.

## Step 4: Coverage critic
Run `../create/references/completeness.md` Part 1 against the subject before selecting components.
Fold omitted salient items in; note intentional omissions for the coverage note. For the system
adapter the critic checks the model against the surviving claims and the gaps list, never against the
code: follow Step E of `references/adapters/system.md`.

## Step 5: Select components
Run the shared **select** stage of `../render/references/render-contract.md`: using
`../create/references/authoring-guide.md`, map the model to component names, then look each up in
`../create/references/components/index.md` for its group file; apply "omit empty, never stub". For the
marketplace card grid (and anything else with no catalog entry), compose a bespoke component per the
authoring-guide recipe + looks-native checklist.

## Step 6: Assemble the HTML
Assemble per the shared **assemble** stage of `../render/references/render-contract.md` — the single
canonical source for the select→assemble→self-check→write mechanics (copy
`../create/references/page-scaffold.md` verbatim, fill its component slots from the selected recipes,
inline `../create/references/interactivity.md`, emit the inert `{{DATA_JSON}}` island, generate
`{{NAV_LINKS}}` deterministically; self-contained, only the one Google Fonts `@import`). When the page
has a system map, fill `{{SYSMAP_ENGINE}}` with the engine block holding its marker line; otherwise
delete that slot.
**Document-specific:** internal links MUST be relative (`./onboard/`, `../`) — never root-absolute.

**Rebrand the scaffold chrome.** The page-scaffold ships session-doc branding (the `◆ walk·through`
nav logo and a `— walkthrough` `<title>` suffix). Replace it with the subject's identity: set
`<title>` to `<subject title> — <site/collection name>` (for a plugin in this repo,
`<name> — claude-plugins`) and the nav logo to the site/collection wordmark (here
`◆ claude-plugins`). For a codebase mapped by the system adapter, the collection is that codebase
itself: `<title>` is `<repository name> — system map` and the nav logo is `◆ <repository name>`.
Never put `claude-plugins` on another project's page. Never leave the literal `walkthrough` session
branding on a subject page.

**The rebrand does not touch the provenance footer.** `<footer class="wt-credit">generated by
walkthrough</footer>` is provenance, not session branding — it states which tool produced the file,
which stays true after a subject rebrand. Retain it verbatim on subject pages. The rebrand covers
the nav logo and the `<title>` suffix only.

## Step 7: Output path
If a second argument (output path) is given, write there. Otherwise resolve `<base>` first (same as
`create` Step 6.5): if a `settings.md` with `output-location:` exists in `walkthroughs/` (visible) or
`.claude/walkthrough/` (hidden), use that base; else default to `.claude/walkthrough/`. Then default to
`<base>/<YYYY-MM-DD-HHMM>-<slug>.html` (`slug` = kebab of the title; collisions → `-2`,
`-3`, …). For the site convention, the caller passes `site/<plugin>/index.html` (or
`site/index.html` for the marketplace). Create parent directories if missing.

## Step 8: Self-check (structure)
Run the shared **self-check** stage of `../render/references/render-contract.md`
(`../create/references/self-check.md`) against the assembled HTML; fix and re-check before writing.

## Step 9: Write the file
Per the shared **write** stage of `../render/references/render-contract.md`, write the assembled HTML to
the Step 7 path. (No gitignore prompt — unlike `create`, `document` output is a published/derived
artifact, not private session content.)

When the page has a system map, then run the contract's **insert the system-map engine** step, with the
engine path named at the top of this skill, and run its check.

## Step 10: Offer to open
Tell the user the path (under three lines). Offer `open "<path>"` (macOS; `xdg-open` on Linux).
Do not auto-open.

Include the `completeness.md` Part 2 coverage note (included / intentionally omitted) in the message,
above the open offer. It is a passive summary, not an `AskUserQuestion`.

When the page has a system map, also include the contract's `System map engine: …` line. When the
system adapter ran, also include its reading line (`Read by agents: analyzer and verifier.` or
`Read inline (agents unavailable): claims were not independently verified.`) and the number of gaps.

## Key Rules
- **One look-and-feel.** Tokens only — never raw hex. Reproduce `design-system.md` patterns.
- **Self-contained.** All CSS/JS/SVG inline; only the Google Fonts `@import` is external.
- **README is canonical.** Never invent content not grounded in the subject's source files. For the system adapter the canon is the machine-read files instead: manifests beat prose.
- **No evidence, no box.** On a code-read map every box and wire shows where it was seen, or is marked inferred. Refuted claims are not drawn, gaps are listed, and no environment-variable value reaches the page.
- **Engine by the contract.** A page with a system map gets its engine through the insert step of `render-contract.md`; never offer a page that still holds the marker line.
- **Model before markup.** Synthesize the subject model (Step 3) before assembling HTML.
- **Omit empty, never stub.** Render only components with real content.
- **Relative links only.** Internal cross-links use `./` or `../`, never `/…` (Pages base path).
- **Real code refs only.** Cite `path:line` only when verified via a file read.
- **Read-only.** Never execute subject code; only read files.
- **Self-check before write.** Run `self-check.md` on the assembled HTML; never write a document that fails it.
- **Completeness gate.** Run the coverage critic after synthesis and surface the coverage note at the offer step.
