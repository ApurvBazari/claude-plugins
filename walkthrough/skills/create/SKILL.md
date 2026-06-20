---
name: create
description: Generate an interactive HTML walkthrough of the current session — a self-contained, explorable document (prose + diagrams + clickable detail) in a fixed house style. Use when the user asks to "visualize this session", "create a walkthrough", "walk me through it", "walk me through this/that", "walk me through what we did", "make a session recap/document", or runs /walkthrough:create. Writes to .claude/walkthrough/ (or a chosen walkthroughs/ folder in a non-git directory).
---

# Create — Render the Session as an Interactive Document

You are invoked via `/walkthrough:create [optional focus]`, or auto-invoked when the user asks
to visualize/recap the session. Produce ONE self-contained interactive HTML file in the house
style, then offer to open it. The renderer is six `references/` files (including `concept-coverage.md`)
plus the `references/components/` catalog (its `index.md` routes to per-group recipe files you read on
demand). Load them as the steps direct.

## Step 1: Scope
If an argument was given (e.g. `architecture decisions`), scope synthesis to that focus.
Otherwise cover the whole session. If the session is trivially short, ask via AskUserQuestion
(2 fixed options: "Generate anyway" / "Skip") before proceeding.

## Step 2: Gather
The session transcript is the source of record — synthesize from the conversation, not from
repository state. Read any source files you will cite so code locations (`path:line`) are real —
never invent a line number; if unverified, cite `path` only or omit.

## Step 3: Synthesize the session model
Build the structured model per `references/session-model.md` (title, summary, typeTags,
sections[], concepts[], nodes[], edges[], decisions[], files[], timeline[], metrics[], openQuestions[],
details{}) BEFORE writing any HTML.

## Step 4: Coverage critic
Run `references/completeness.md` Part 1 against the session before selecting components. Fold omitted
salient items into the model; note intentional omissions for the coverage note.

## Step 5: Select components
Using `references/authoring-guide.md`, map the model to component names, then look each name up in
`references/components/index.md` to find its group file. Apply "omit empty, never stub". For content
that fits no catalog entry, compose a bespoke component per the authoring-guide recipe + looks-native checklist.
Before accepting a catalog **diagram**, run the authoring-guide § 1 diagram-fidelity check: cyclic /
guarded `nodes[]`+`edges[]` → state / transition diagram; timed messages between actors → sequence /
swimlane diagram; a shape the catalog still cannot draw faithfully → compose a bespoke diagram. Never
force-fit a state machine or a message trace into a flow / architecture map.

Run the **concept-fidelity gate** (`references/authoring-guide.md` § 1, routed by
`references/concept-coverage.md`): classify each `concepts[]` entry into a concept-type, bind it to the
registered renderer, and never force-fit an uncovered concept (compose bespoke instead). The
mechanical concept-coverage assertion (`references/completeness.md` Part 1b) must pass before assemble.

## Step 6: Assemble the HTML
Start from `references/page-scaffold.md`. Inline: the `@import` + both `:root` blocks from
`references/design-system.md`; the shared JS from `references/interactivity.md`; the CSS+HTML
for each chosen component — read **only** the `references/components/<group>.md` files for the
components you selected in Step 5 (routed via `components/index.md`); the `DET`/detail data. Keep it
self-contained: no `<script src>`, no `<img>`, only the one Google Fonts `@import`.
Generate `{{NAV_LINKS}}` deterministically from `sections[]` (one `<a href="#id">` per section, id reused from the section; first link `class="on"`) — do not hand-write or hand-match ids.

## Step 6.5: Resolve output base directory
Decide where walkthroughs are written in this folder, and remember the choice, BEFORE computing the path.
`<base>` (used by Steps 7, 8, 10, 11) is the directory resolved here.

1. **Remembered choice wins.** Look for a `settings.md` recording an `output-location:` in EITHER candidate:
   - `walkthroughs/settings.md` (visible)
   - `.claude/walkthrough/settings.md` (hidden)
   If found, set `<base>` to that location and do NOT prompt.

2. **No remembered choice → first run in this folder:**
   - If `.claude/walkthrough/` already contains any `*.html` (a pre-feature user, no `settings.md`),
     treat **hidden** (`.claude/walkthrough/`) as the established base and do NOT prompt — never split
     history across two directories.
   - Else determine whether this is a git repository: `git rev-parse --is-inside-work-tree` (exit 0 = git repo).
     - **Git repo** → `<base>` = `.claude/walkthrough/` silently (today's behavior; no new prompt).
     - **Not a git repo** (the knowledge-work / Cowork case) → ask via `AskUserQuestion`
       (single-select, fixed 2 options per `.claude/rules/ask-user-question-guard.md`):
       - **Visible — `walkthroughs/`** (recommended): a plain folder at the project root, easy to find.
       - **Hidden — `.claude/walkthrough/`**: tucked away, consistent with Claude Code projects.
     Persist the choice as a line `output-location: <visible|hidden>` in `<chosen-base>/settings.md`
     (create the base dir if missing).

## Step 7: Output path (proliferation guard)
Compute `slug` = kebab of the title. List `<base>/*.html` and strip the
`<YYYY-MM-DD-HHMM>-` prefix from each to get existing slugs.

- **No slug match** -> use `<base>/<YYYY-MM-DD-HHMM>-<slug>.html` (collision on the exact
  name -> append `-2`, `-3`, ...). Create `<base>` if missing.
- **Slug matches an existing file** -> do NOT silently version. Ask via `AskUserQuestion`
  (single-select, fixed 3 options per `.claude/rules/ask-user-question-guard.md`):
  - **Update in place** -> stop `create` and hand off to `/walkthrough:update` on the matched file.
  - **New versioned file** -> proceed with the timestamped `-2`/`-3` name (today's behavior).
  - **Overwrite** -> write to the matched file's path.

This is honored even when model-invoked -- there is no silent-proliferation path.

## Step 8: Gitignore prompt (first run only)
Only when `<base>` is `.claude/walkthrough/`: if it is not already gitignored and `.gitignore`
exists, ask via AskUserQuestion (fixed 3 options: "Add pattern" / "Skip" / "Don't ask again");
persist the choice in `<base>/settings.md`. (See `.claude/rules/ask-user-question-guard.md`.)
When `<base>` is `walkthroughs/` (a non-git folder has no `.gitignore`), this step self-skips.

## Step 9: Self-check (structure)
Before writing, run `references/self-check.md` against the assembled HTML. Fix any failure and
re-check. Do not write a document that fails the self-check.

## Step 10: Write the file
Write the assembled HTML to the path from Step 7.

## Step 11: Offer to open
Tell the user the path (under three lines). Offer to open it:

```bash
open "<path>"        # macOS;  xdg-open on Linux
```

Do not auto-open; offer.

Include the `completeness.md` Part 2 coverage note (included / intentionally omitted) in the message,
above the open offer. It is a passive summary, not an `AskUserQuestion`.

## Key Rules
- **One look-and-feel.** Tokens only — never raw hex. Reproduce the signature patterns from `design-system.md`.
- **Self-contained.** All CSS/JS/SVG inline; only the Google Fonts `@import` is external. No CDN scripts/libs.
- **Model before markup.** Always synthesize the session model (Step 3) before assembling HTML.
- **Omit empty, never stub.** Render only components with real content.
- **Real code refs only.** Cite `path:line` only when verified via a file read.
- **Read-only.** Never execute session-derived code; only read files to verify citations.
- **AskUserQuestion guard.** The thin-session (2), output-location (2, first-run non-git only), gitignore (3), and proliferation-guard (3, conditional) prompts use fixed-length option lists per `.claude/rules/ask-user-question-guard.md`.
- **Self-check before write.** Run `self-check.md` on the assembled HTML; never write a document that fails it.
- **Completeness gate.** Run the coverage critic after synthesis and surface the coverage note at the offer step.
