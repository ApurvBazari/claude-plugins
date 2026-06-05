# walkthrough

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/), [`notify`](../notify/), and [`handoff`](../handoff/).

Render the current session as a self-contained interactive HTML document with diagrams and clickable detail. Turns "what did we just do" into an explorable page — prose, architecture diagrams, decision records, and a file/timeline view — instead of a scroll back through the transcript.

walkthrough works from **two kinds of input**: a *session* (`create` / `update`, below) or a *subject* — a plugin, the marketplace, any path (`document`, below). Both render to the same house style.

## Install

```bash
claude plugin install walkthrough@apurvbazari-plugins
```

That's it. No setup step, no configuration file required.

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
- architecture / flow diagrams rendered as inline SVG
- decision records (what was chosen, what was rejected, why)
- a file-touch list with real `path:line` references
- a timeline and metrics where the session has them
- an **interactive explorer** — a selector that drives a live diagram region and a detail pane from one shared data model, useful for multi-component architectures where you want to navigate relationships rather than read a static diagram
- a **data-driven step timeline** — phases of parallel and sequential steps with source pills and micro-cycles, useful when the session covers a pipeline, workflow, or multi-phase build
- clickable detail — expand a node or a decision to see the supporting context

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

## Where files go

Walkthroughs are written to:

```
.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html
```

`<slug>` is a kebab-case version of the document title. If a walkthrough on the same subject (same slug) already exists, `create` asks whether to **update it in place**, **write a new versioned file**, or **overwrite** — rather than silently adding a `-2`/`-3` suffix. The directory is created on first run.

On the first run in a repo (when `.gitignore` exists and doesn't already cover the path), `create` offers to add `.claude/walkthrough/` to `.gitignore` and remembers your choice in `.claude/walkthrough/settings.md`.

> A walkthrough can contain session content — code snippets, file paths, decisions, prose you and Claude exchanged. Treat it like any other session artifact. Gitignoring the directory (the default offer) keeps walkthroughs out of commits and code review.

## What it is / isn't

**It is** a single self-contained HTML file. All CSS, JS, and SVG are inlined; the only external resource is one Google Fonts `@import`. Copy the file anywhere, email it, drop it in a wiki — it renders without the plugin, without a server, and without a network connection beyond the font fetch.

**It isn't** a live viewer — it's a snapshot of one session at the moment you ran it, not a dashboard that updates. And it isn't a raw transcript dumper — it synthesizes a structured model of the session (sections, diagram nodes, decisions, files) and renders *that*, rather than pasting the message log verbatim.

## License

[MIT](../LICENSE)
