# walkthrough

Turn a Claude session, or any plugin or codebase, into one interactive HTML page you can open anywhere.

**Works in:** Claude Code ✓ · Cowork ✓ · claude.ai chat (loads, not yet tested). See [Where it works](#where-it-works).

> Part of [claude-plugins](https://github.com/ApurvBazari/claude-plugins). See also [onboard](https://github.com/ApurvBazari/claude-plugins/tree/main/onboard), [notify](https://github.com/ApurvBazari/claude-plugins/tree/main/notify), [handoff](https://github.com/ApurvBazari/claude-plugins/tree/main/handoff) and [lens](https://github.com/ApurvBazari/claude-plugins/tree/main/lens).

## Install

From Anthropic's plugin directory, once walkthrough is listed there: **Customize → Plugins** on claude.ai, or `/plugin directory` in Claude Code.

From this repository's marketplace:

```bash
claude plugin marketplace add ApurvBazari/claude-plugins
claude plugin install walkthrough@apurvbazari-plugins
```

There is no setup step and no configuration file.

## What it does

- **Session recap.** `/walkthrough:create` turns what happened in the session into one page: a summary, diagrams, decision records, the files touched with `path:line` references, and a timeline.
- **Refresh in place.** `/walkthrough:update` folds new spec or source files into an existing page and overwrites that same file, after you confirm which one.
- **Docs for a subject.** `/walkthrough:document` renders a plugin, the marketplace or a path as a docs page from its README and manifest. Asked for a map of a codebase, it reads the code and draws a system map.
- **One file, no network.** All CSS, JavaScript and SVG are inside the page, and the fonts are the ones your system already has. The page loads nothing from the network. Email it, put it in a wiki, or open it offline.

## Commands

| Command | What it does |
|---|---|
| `/walkthrough:create [focus]` | Render the current session as one interactive HTML page. `focus` narrows it, for example `architecture decisions`. See [Usage](#usage). |
| `/walkthrough:update [changed-file-paths…]` | Refresh an existing page in place with the files you name. It always asks which page first. See [Updating an existing walkthrough](#updating-an-existing-walkthrough). |
| `/walkthrough:document <subject> [request] [output-path]` | Render a plugin, the marketplace, a path, or a codebase's system map as a docs page. See [Documenting a subject](#documenting-a-subject). |

`render` is an internal skill that other plugins, such as lens, call. You don't run it. See [The internal `render` skill](#the-internal-render-skill).

## What it reads, writes, and sends

| | |
|---|---|
| **Reads** | The current conversation and the files it cites. `update` also reads the page you pick and the files you name. `document` reads the subject's README, manifest and `skills/` folder. For a codebase map, two read-only agents read the code within a fixed budget. They are told never to open `.env` files, keys or credential files, and never to copy an environment variable's value. |
| **Writes** | One HTML file, at `.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html` by default. In a folder that isn't a git repository you can pick a visible `walkthroughs/` folder instead, and `document` writes where you tell it. A small `settings.md` beside the pages remembers your choices. On the first run it offers to add `.claude/walkthrough/` to `.gitignore`, and edits `.gitignore` only if you say yes. `update` overwrites the page you confirmed. |
| **Runs** | No scripts of its own. `create` runs a read-only `git rev-parse` to tell whether the folder is a git repository. Before it offers a page, it checks the page's scripts with `node --check` and parses its data block as JSON. These are syntax checks; nothing on the page is executed. When a page has a system map, one `awk` command copies the layout engine from the plugin into the page. If that can't run, Claude types the engine in instead. At the end it offers to open the page with `open` or `xdg-open`, and runs that only if you say yes. |
| **Network** | None. The plugin sends nothing anywhere, and the page it writes loads nothing from the network. |
| **Changes to your Claude settings** | None. No hooks, no permission rules, no MCP servers. |

A page can contain session content: code snippets, file paths, decisions, and prose from the conversation. Treat it like any other session artifact before you share it.

## Where it works

| Surface | Status |
|---|---|
| Claude Code | ✓ Full support. |
| Cowork | ✓ walkthrough has no hooks and no shell scripts, so it installs and runs as it does in Claude Code. Two parts have fallbacks there; see [Works in Cowork](#works-in-cowork). |
| claude.ai chat | Loads, not yet tested. Skills load in chat, but the two code-reading agents don't. A codebase map is then read and checked by the skill itself, and the page says its claims were not independently verified. |

## Usage

```
/walkthrough:create [focus]
```

Run it whenever you want a readable artifact of the session — after a debugging marathon, at the end of a feature, before a handoff, or to share with someone who wasn't in the room. The optional `focus` argument scopes the synthesis (e.g. `/walkthrough:create architecture decisions` narrows the document to the decisions you made and why). With no argument it covers the whole session.

`create` is both user- and intent-invokable: typing the slash form works, and so does asking *"create a walkthrough"*, *"visualize this session"*, *"walk me through what we did"*, or *"make a session recap"*. A plain request to explain some code or a concept is answered in chat, not turned into a page.

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
/walkthrough:document <subject> [request] [output-path]
```

`create` and `update` render a **session**. `document` renders a **subject** — a plugin, the whole marketplace, or any path — into the same self-contained house style. Its source of truth is the subject's own files: it reads the `README` + manifest (canonical, except for a [mapped codebase](#mapping-a-codebase)) and the `skills/` surface, synthesizes the same kind of structured model, and emits one portable HTML page.

The optional `request` says what to draw: `/walkthrough:document . architecture` maps the codebase in the current directory (see [Mapping a codebase](#mapping-a-codebase)). The output path is the last argument, and only when it ends in `.html`; everything else after the subject is read as the request.

- **Same promises as `create`** — one house style, two themes, everything inlined, nothing loaded from the network.
- **README + manifest are canonical** — the page is a rendering of them, not a separately-maintained doc. Change the README, regenerate the page. The exception is a [mapped codebase](#mapping-a-codebase): there the code is the source, not the README.
- **It builds this project's own docs site** — every page under `site/` (the marketplace landing + one per plugin) is generated by `/walkthrough:document`, never hand-written.
- **Coverage summary** — after writing, `document` surfaces the same included/omitted summary so you can confirm the rendered page reflects the subject's full surface area.

`document` is both user- and intent-invokable: the slash form works, and so does *"document this plugin"*, *"make a docs page for notify"* or *"draw a system map of this repo"*.

### Mapping a codebase

Ask `document` for a page that maps a codebase (*"draw a system map of this repo"*, or `/walkthrough:document . architecture`) and it reads the code instead of the README, then draws a [system map](#system-maps) of what it found. `document` also does this by itself: when the subject is a repository root that has a build or deploy manifest and is not a plugin or the marketplace, `/walkthrough:document .` maps the code with no request for a map. Either way it dispatches two agents to do the reading, and the reading has a fixed budget of files and lines. If the reading finds nothing to map, `document` falls back to rendering the README and says why.

- **Every box and wire shows where it was seen.** Click a box for the file and line. Anything supported only by indirect signals, such as a name or an environment-variable name, is drawn dotted and labelled *inferred*.
- **Two read-only agents do the reading.** One makes claims with evidence; the other tries to refute each claim against the code. Refuted claims are not drawn.
- **The reading is bounded, and the page says what was skipped.** A "Gaps" section lists the directories that were not read and the claims that were dropped.
- **Names only.** The agents, and the skill itself, are told never to open, search or cite `.env` files, keys and credential files (tool, cloud and Terraform ones included) or anything outside the folder being mapped, and never to copy an environment variable's value; a template such as `.env.example` is read for variable names only. That is an instruction, not a technical block. The verifier refutes any claim that rests on one of those files or carries a value, and the page is checked again before it is written.
- **Containers by default.** People, services, stores, queues and external systems. Ask for components to open a service up. A library with nothing deployable becomes a map of its packages.

## System maps

A system map draws anything with parts and connections: services, stores, queues, people, external systems, or the modules of a codebase.

- **Boxes nest.** A boundary holds other boxes, to any depth. Open or close one in place to move between the big picture and the detail. On a large system the map opens only as many boundaries as fit comfortably (about 16 boxes), and *expand all*, *collapse all* and *reset* are one click away.
- **Wires are labelled and directed.** Async flow is dashed. Several connections between two closed boundaries merge into one thicker wire; click its "N links" label to see them.
- **Cycles are fine.** A webhook that calls back into the gateway is drawn as what it is.
- **It can show a change.** Boxes and wires marked added, modified or deleted get a green, amber or rose ring and a text badge. A closed boundary shows how many changes it holds.
- **The page holds the whole graph as plain text.** Under every map is the full list of connections. With JavaScript off, or if the layout fails for any reason, you still see the boxes, nested as they are, and that list; when the layout engine gives up on a map, it leaves one line in the browser console saying why.
- **Direction is automatic.** Left to right when that fits the page, top to bottom when it does not.

The picture is drawn by a small layout engine carried inside the page itself, so the file stays self-contained. It replaces two older diagrams, the architecture map and the dependency graph; `update` upgrades a page that still has one.

## The internal `render` skill

Alongside the three user-facing skills, walkthrough ships one **internal** skill — `render` (`user-invocable: false`). It renders a model that's already in context straight to HTML, skipping the gather + synthesize stages, and reuses the same visual layer. It exists for *other plugins* to call programmatically — the [`lens`](https://github.com/ApurvBazari/claude-plugins/tree/main/lens) review companion uses it to render its findings. You never invoke it directly; "render the session" for users is `/walkthrough:create`.

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

- **The system-map layout engine** is normally put into the page by one shell command. Where that command cannot be used, for example because no shell can read the plugin's files, Claude types the engine into the page instead. The message after writing says which happened.
- **Mapping a codebase** normally uses two read-only agents. Where agents cannot be dispatched, the skill does the reading and the checking itself, and the page says its claims were not independently verified.

Because a Cowork folder is often not a git repository, `create` asks **on first run in a non-git folder** where to write — a visible `walkthroughs/` folder (easy to find) or the hidden `.claude/walkthrough/` — and remembers the choice. In a git repository (the typical Claude Code case) nothing changes: walkthroughs go to `.claude/walkthrough/` with no prompt.

## Limitations

- **Android / local-file JS.** As of 1.3.1 the document is fully readable without JavaScript — opened as a `file://` document on Android (which blocks local-file JS) or with JS disabled, all prose and diagrams render; only the click-to-open detail surfaces and the scroll-reveal animation are inert. For the full interactive experience, view on desktop or host the file over `http(s)`.
- **No print path.** The document is built for on-screen exploration; there is no dedicated print stylesheet, and collapsed detail (panes, sheets) will not appear in a printout.
- **A system map needs JavaScript for its picture.** Without it you see the boxes, nested as they are, and the full list of connections, but no drawn wires. That now includes a module dependency graph, which before 1.6.0 was a static drawing.
- **An ordinary system map is drawn top to bottom.** A map is laid out left to right only when that fits the page. In the live test runs so far, the only maps laid out left to right had 3 to 5 boxes; every map of 10 to 15 boxes came out top to bottom. Expect a tall map for an ordinary system, not only for a long chain.
- **A backslash in the plugin's path stops the shell insert.** The command that puts the layout engine into the page fails when the engine file's path contains a backslash, as a native Windows path does. The page is left untouched and Claude types the engine into the page instead.
- **A page with a system map is about 28 KB larger:** the size of the layout engine it carries. Pages without one are unchanged.

## What it is / isn't

**It is** a single self-contained HTML file. All CSS, JS, and SVG are inlined, and the fonts are system fonts, so the page loads nothing from the network. Copy the file anywhere, email it, drop it in a wiki — it renders without the plugin, without a server, and without a network connection. Pages made before 1.7.0 still fetch Google Fonts; `/walkthrough:update` removes that when it rewrites one.

**It isn't** a live viewer — it's a snapshot of one session at the moment you ran it, not a dashboard that updates. And it isn't a raw transcript dumper — it synthesizes a structured model of the session (sections, diagram nodes, decisions, files) and renders *that*, rather than pasting the message log verbatim.

## License

[MIT](https://github.com/ApurvBazari/claude-plugins/blob/main/walkthrough/LICENSE)
