# walkthrough

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/), [`notify`](../notify/), [`handoff`](../handoff/), and [`lens`](../lens/).

Render the current session as a self-contained interactive HTML document with diagrams and clickable detail. Turns "what did we just do" into an explorable page — prose, architecture diagrams, decision records, and a file/timeline view — instead of a scroll back through the transcript.

walkthrough works from **two kinds of input**: a *session* (`create` / `update`, below) or a *subject* — a plugin, the marketplace, any path (`document`, below). Both render to the same house style.

## Install

```bash
claude plugin install walkthrough@apurvbazari-plugins
```

That's it. No setup step, no configuration file required.

## Skills

- `/walkthrough:create [focus]` — render the current session as a self-contained interactive HTML document. See [Usage](#usage).
- `/walkthrough:update [changed-file-paths…]` — refresh an existing walkthrough in place. See [Updating an existing walkthrough](#updating-an-existing-walkthrough).
- `/walkthrough:document <subject> [output-path]` — render a plugin, the marketplace, or any path as a docs page. See [Documenting a subject](#documenting-a-subject).

> `render` is an internal building block (`user-invocable: false`) used by other plugins (e.g. lens) — see [The internal `render` skill](#the-internal-render-skill).

## Usage

```
/walkthrough:create [focus]
```

Run it whenever you want a readable artifact of the session — after a debugging marathon, at the end of a feature, before a handoff, or to share with someone who wasn't in the room. The optional `focus` argument scopes the synthesis (e.g. `/walkthrough:create architecture decisions` narrows the document to the decisions you made and why). With no argument it covers the whole session.

`create` is both user- and intent-invokable: typing the slash form works, and so does asking *"visualize this session"*, *"walk me through what we did"*, *"walk me through it"* (or "this" / "that"), or *"make a session recap"*.

### How it works

`create` runs a fixed five-stage pipeline: **gather** cited source files → **synthesize** a structured session model (sections, diagram nodes, decisions, files, timeline) → **select** components → **assemble** the page scaffold with inlined CSS/JS/SVG → **write** the file. The full model is built before a single HTML tag is written — rendering never starts from the raw transcript.

### What it produces

One HTML file. Open it in any browser and you get a composed document — not a transcript dump:

- a summary and type tags for the session
- flow diagrams, and **system maps** for anything with parts and connections (see [System maps](#system-maps))
- decision records (what was chosen, what was rejected, why)
- a file-touch list with real `path:line` references
- a timeline and metrics where the session has them
- an **interactive explorer** — a selector that drives a live diagram region and a detail pane from one shared data model, useful for multi-component architectures where you want to navigate relationships rather than read a static diagram
- a **data-driven step timeline** — phases of parallel and sequential steps with source pills and micro-cycles, useful when the session covers a pipeline, workflow, or multi-phase build
- **rich detail surfaces** — click a node, card, or cross-link and its detail opens in a structured glance **pane**, or a centered **sheet** for richer content (a hosted diagram, code) that can itself open further detail, nested
- a **concept-coverage map** plus five concept-shaped renderers — a decision tree, a recursive tree, a layer stack, a layered, cycle-aware ERD, and a cause→effect hypothesis ladder — so branching logic, hierarchies, layered stacks, data models (schema view with dependency-banded entities, field-anchored relationships, and foreign-key cycles/self-references), and debugging traces each render in the shape that fits them

Components adapt to the session. The catalog is a floor, not a ceiling: when content fits no off-the-shelf component, a bespoke one is composed from the same design-system primitives so it still looks native. Empty sections are omitted rather than stubbed.

After writing the file, `create` surfaces a short **coverage summary** — what made it into the document and what was intentionally omitted — so you can spot anything that got left out before you close the session.

### Dark / light toggle

The document ships in one house style with two themes — a dark theme and a warm-light theme — and an in-document toggle. The choice is yours per-view; nothing about the toggle requires a server or a build step.

## Updating an existing walkthrough

```
/walkthrough:update [changed-file-paths…]
```

A walkthrough is a snapshot — but you can refresh one in place as the work evolves. `update` lets you pick an existing document, reconstructs its content, folds in the spec/source files you name as arguments, and overwrites the **same file** with one coherent, up-to-date document in the same house style.

- It **always asks which document** to refresh before writing — nothing is overwritten silently, even when intent-invoked.
- The files you name as arguments are the new material; the conversation provides framing. There is no automatic git scan — you control exactly what gets pulled in. Run it with no arguments and it asks which files changed.
- The result is one evolving document at the same path: no new file, no backup, no "updated" banner — it simply becomes its up-to-date self.
- After writing, `update` surfaces the same **coverage summary** as `create` — included items and anything intentionally omitted — so you can check the refresh captured everything you named.

`update` is both user- and intent-invokable: the slash form works, and so does *"update the walkthrough"* or *"refresh the session doc with the new spec"*.

## Documenting a subject

```
/walkthrough:document <subject> [output-path]
```

`create` and `update` render a **session**. `document` renders a **subject** — a plugin, the whole marketplace, or any path — into the same self-contained house style. Its source of truth is the subject's own files: it reads the `README` + manifest (canonical) and the `skills/` surface, synthesizes the same kind of structured model, and emits one portable HTML page.

- **Same promises as `create`** — one house style, two themes, everything inlined, only the Google Fonts `@import` is external.
- **README + manifest are canonical** — the page is a rendering of them, not a separately-maintained doc. Change the README, regenerate the page.
- **It builds this project's own docs site** — every page under `site/` (the marketplace landing + one per plugin) is generated by `/walkthrough:document`, never hand-written.
- **Coverage summary** — after writing, `document` surfaces the same included/omitted summary so you can confirm the rendered page reflects the subject's full surface area.

`document` is both user- and intent-invokable: the slash form works, and so does *"document this plugin"* or *"make a docs page for notify"*.

### Mapping a codebase

Ask `document` for a codebase's architecture (*"map this system"*, *"draw a system map of this repo"*) and it reads the code instead of the README, then draws a [system map](#system-maps) of what it found.

- **Every box and wire shows where it was seen.** Click a box for the file and line. Anything supported only by indirect signals, such as a name or an environment-variable name, is drawn dotted and labelled *inferred*.
- **Two read-only agents do the reading.** One makes claims with evidence; the other tries to refute each claim against the code. Refuted claims are not drawn.
- **The reading is bounded, and the page says what was skipped.** A "Gaps" section lists the directories that were not read and the claims that were dropped.
- **Names only.** Environment-variable values are never copied, and `.env` files, keys and credential files are never opened.
- **Containers by default.** People, services, stores, queues and external systems. Ask for components to open a service up. A library with nothing deployable becomes a map of its packages.

## System maps

A system map draws anything with parts and connections: services, stores, queues, people, external systems, or the modules of a codebase.

- **Boxes nest.** A boundary holds other boxes, to any depth. Open or close one in place to move between the big picture and the detail. On a large system the map opens only as many boundaries as fit comfortably (about 16 boxes), and *expand all*, *collapse all* and *reset* are one click away.
- **Wires are labelled and directed.** Async flow is dashed. Several connections between two closed boundaries merge into one thicker wire; click its "N links" label to see them.
- **Cycles are fine.** A webhook that calls back into the gateway is drawn as what it is.
- **It can show a change.** Boxes and wires marked added, modified or deleted get a green, amber or rose ring and a text badge. A closed boundary shows how many changes it holds.
- **The page holds the whole graph as plain text.** Under every map is the full list of connections. With JavaScript off, or if the layout fails for any reason, you still see the boxes, nested as they are, and that list.
- **Direction is automatic.** Left to right when that fits the page, top to bottom when it does not.

The picture is drawn by a small layout engine carried inside the page itself, so the file stays self-contained. It replaces two older diagrams, the architecture map and the dependency graph; `update` upgrades a page that still has one.

## The internal `render` skill

Alongside the three user-facing skills, walkthrough ships one **internal** skill — `render` (`user-invocable: false`). It renders a model that's already in context straight to HTML, skipping the gather + synthesize stages, and reuses the same visual layer. It exists for *other plugins* to call programmatically — the [`lens`](../lens/) review companion uses it to render its findings. You never invoke it directly; "render the session" for users is `/walkthrough:create`.

## Where files go

Walkthroughs are written to:

```
.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html
```

`<slug>` is a kebab-case version of the document title. If a walkthrough on the same subject (same slug) already exists, `create` asks whether to **update it in place**, **write a new versioned file**, or **overwrite** — rather than silently adding a `-2`/`-3` suffix. The directory is created on first run.

In a **non-git folder** (common in Cowork), `create` instead asks on first run whether to use a visible `walkthroughs/` folder or the hidden `.claude/walkthrough/`, and records the choice in `<chosen-dir>/settings.md`. In a git repository it uses `.claude/walkthrough/` as described above.

On the first run in a repo (when `.gitignore` exists and doesn't already cover the path), `create` offers to add `.claude/walkthrough/` to `.gitignore` and remembers your choice in `.claude/walkthrough/settings.md`.

> A walkthrough can contain session content — code snippets, file paths, decisions, prose you and Claude exchanged. Treat it like any other session artifact. Gitignoring the directory (the default offer) keeps walkthroughs out of commits and code review.

## Works in Cowork

walkthrough has no hooks and no shell scripts, so it installs and runs in [Claude Cowork](https://claude.com/product/cowork) as it does in Claude Code. Its output is a single portable HTML file, which makes it a natural fit for a Cowork working session: run it and you get an explorable deliverable you can email, drop in a wiki, or open offline.

Two parts added in 1.6.0 each have a fallback, because how Cowork handles them has not been confirmed yet:

- **The system-map layout engine** is normally put into the page by one shell command. Where no shell can read the plugin's files, Claude types the engine into the page instead. The message after writing says which happened.
- **Mapping a codebase** normally uses two read-only agents. Where agents cannot be dispatched, the skill does the reading and the checking itself, and the page says its claims were not independently verified.

Because a Cowork folder is often not a git repository, `create` asks **on first run in a non-git folder** where to write — a visible `walkthroughs/` folder (easy to find) or the hidden `.claude/walkthrough/` — and remembers the choice. In a git repository (the typical Claude Code case) nothing changes: walkthroughs go to `.claude/walkthrough/` with no prompt.

## Limitations

- **Android / local-file JS.** As of 1.3.1 the document is fully readable without JavaScript — opened as a `file://` document on Android (which blocks local-file JS) or with JS disabled, all prose and diagrams render; only the click-to-open detail surfaces and the scroll-reveal animation are inert. For the full interactive experience, view on desktop or host the file over `http(s)`.
- **No print path.** The document is built for on-screen exploration; there is no dedicated print stylesheet, and collapsed detail (panes, sheets) will not appear in a printout.
- **A system map needs JavaScript for its picture.** Without it you see the boxes, nested as they are, and the full list of connections, but no drawn wires. That now includes a module dependency graph, which before 1.6.0 was a static drawing.
- **A long chain is drawn top to bottom.** A map is laid out left to right only when that fits the page. A chain of about seven steps with labelled wires does not fit, so it comes out tall.
- **A page with a system map is about 28 KB larger:** the size of the layout engine it carries. Pages without one are unchanged.

## What it is / isn't

**It is** a single self-contained HTML file. All CSS, JS, and SVG are inlined; the only external resource is one Google Fonts `@import`. Copy the file anywhere, email it, drop it in a wiki — it renders without the plugin, without a server, and without a network connection beyond the font fetch.

**It isn't** a live viewer — it's a snapshot of one session at the moment you ran it, not a dashboard that updates. And it isn't a raw transcript dumper — it synthesizes a structured model of the session (sections, diagram nodes, decisions, files) and renders *that*, rather than pasting the message log verbatim.

## License

[MIT](../LICENSE)
