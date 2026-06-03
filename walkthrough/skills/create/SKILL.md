---
name: create
description: Generate an interactive HTML walkthrough of the current session — a self-contained, explorable document (prose + diagrams + clickable detail) in a fixed house style. Use when the user asks to "visualize this session", "create a walkthrough", "walk me through what we did", "make a session recap/document", or runs /walkthrough:create. Writes to .claude/walkthrough/.
---

# Create — Render the Session as an Interactive Document

You are invoked via `/walkthrough:create [optional focus]`, or auto-invoked when the user asks
to visualize/recap the session. Produce ONE self-contained interactive HTML file in the house
style, then offer to open it. The renderer is five `references/` files plus the `references/components/`
catalog (its `index.md` routes to per-group recipe files you read on demand). Load them as the steps direct.

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
sections[], nodes[], edges[], decisions[], files[], timeline[], metrics[], openQuestions[],
details{}) BEFORE writing any HTML.

## Step 4: Select components
Using `references/authoring-guide.md`, map the model to component names, then look each name up in
`references/components/index.md` to find its group file. Apply "omit empty, never stub". For content
that fits no catalog entry, compose a bespoke component per the authoring-guide recipe + looks-native checklist.

## Step 5: Assemble the HTML
Start from `references/page-scaffold.md`. Inline: the `@import` + both `:root` blocks from
`references/design-system.md`; the shared JS from `references/interactivity.md`; the CSS+HTML
for each chosen component — read **only** the `references/components/<group>.md` files for the
components you selected in Step 4 (routed via `components/index.md`); the `DET`/detail data. Keep it
self-contained: no `<script src>`, no `<img>`, only the one Google Fonts `@import`.

## Step 6: Output path
Compute `.claude/walkthrough/<YYYY-MM-DD-HHMM>-<slug>.html` (`slug` = kebab of the title). If it
exists, append `-2`, `-3`, … Create `.claude/walkthrough/` if missing.

## Step 7: Gitignore prompt (first run only)
If `.claude/walkthrough/` is not already gitignored and `.gitignore` exists, ask via
AskUserQuestion (fixed 3 options: "Add pattern" / "Skip" / "Don't ask again"); persist the
choice in `.claude/walkthrough/settings.md`. (See `.claude/rules/ask-user-question-guard.md`.)

## Step 8: Write the file
Write the assembled HTML to the path from Step 6.

## Step 9: Offer to open
Tell the user the path (under three lines). Offer to open it:

```bash
open "<path>"        # macOS;  xdg-open on Linux
```

Do not auto-open; offer.

## Key Rules
- **One look-and-feel.** Tokens only — never raw hex. Reproduce the signature patterns from `design-system.md`.
- **Self-contained.** All CSS/JS/SVG inline; only the Google Fonts `@import` is external. No CDN scripts/libs.
- **Model before markup.** Always synthesize the session model (Step 3) before assembling HTML.
- **Omit empty, never stub.** Render only components with real content.
- **Real code refs only.** Cite `path:line` only when verified via a file read.
- **Read-only.** Never execute session-derived code; only read files to verify citations.
- **AskUserQuestion guard.** The thin-session and gitignore prompts use fixed-length option lists per `.claude/rules/ask-user-question-guard.md`.
