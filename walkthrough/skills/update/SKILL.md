---
name: update
description: Refresh an EXISTING walkthrough HTML in place so it reflects new work — reconstructs the prior content from the document, folds in explicitly-named spec/source files, and overwrites the same file as one coherent document. Use when the user asks to "update the walkthrough", "refresh the session doc", "regenerate the walkthrough with the new spec", or runs /walkthrough:update. Reads from and writes to .claude/walkthrough/.
---

# Update — Refresh an Existing Walkthrough In Place

You are invoked via `/walkthrough:update [changed-file-paths…]`, or auto-invoked when the user asks
to refresh/update an existing walkthrough. Unlike `create`, you do not start from a blank session
model — you **reconstruct** the prior model from an existing walkthrough HTML, **merge** in newly-
named files, and **overwrite that same file** with one coherent, up-to-date document in the same
house style.

`create` is the renderer of record. This skill reuses its references unchanged for the render half;
the two stages unique to `update` (reconstruct + merge) live in `references/reconstruct-and-merge.md`.

## Step 1: Resolve the target (always confirm — the overwrite safety gate)

Resolve `<base>` first (same as `create` Step 6.5): if a `settings.md` with `output-location:` exists in
`walkthroughs/` (visible) or `.claude/walkthrough/` (hidden), use that base; else default to
`.claude/walkthrough/`. List `<base>/*.html` (not a hardcoded `.claude/walkthrough/`). Never overwrite
without explicit user confirmation, even when model-invoked. Per `.claude/rules/ask-user-question-guard.md`
(a repo-development convention, not shipped with the plugin; the shipped constraint — AskUserQuestion option
lists must have ≥2 entries, the schema's `minItems: 2` — is inlined per-branch below):

- **0 files** → do not proceed. Tell the user: *"No walkthrough exists yet — run `/walkthrough:create` first."* Offer to run it. Stop.
- **1 file** → confirm with a 2-option single-select `AskUserQuestion`: `"Update <filename>?"` → `Yes` / `No`. (A 1-option list violates the schema's `minItems: 2`; the yes/no form satisfies it.)
- **2–4 files** → `AskUserQuestion`, one option per file (label = filename, description = its `<title>` + modified time). The user picks one.
- **>4 files** → `AskUserQuestion` with the 4 most-recently-modified files as options; the user picks one or chooses the tool's built-in "Other" to type a different filename.

The confirmed file is `TARGET`.

## Step 2: Reconstruct the prior model

Read `TARGET` and rebuild the session model from its rendered HTML following
`references/reconstruct-and-merge.md` Part A. Parse the trailing `const DET={…}` store directly for
`details{}` (the highest-fidelity source). Do not fabricate structure that is not present.

## Step 3: Gather the new material (named files only)

The command arguments are the changed spec/source file paths.

- **If no paths were given**, ask the user which spec/source files changed and wait for paths before
  proceeding — auto-discovery is intentionally off. Do not fall back to a session-only refresh.
- Read each named file. If a named file does not exist, warn and skip it; if *every* named file is
  missing, re-ask rather than producing an empty refresh.
- Read any source file you will cite so `path:line` refs are real — never invent a line number.
- The current conversation is **framing context** only; the named files are the authoritative new
  material.
- The nav kicker (`{{KICKER}}`) is session metadata — derive it from the session date, the primary
  `typeTag`, and the focus/scope. Do not shell out for branch/commit context.

## Step 4: Merge into one coherent model

Combine the reconstructed prior model (Step 2) with the new material (Step 3) into ONE refreshed
session model following `references/reconstruct-and-merge.md` Part B — revise superseded content,
merge overlaps, add genuinely new material, and keep existing `sections[].id` / `details{}` keys
stable. The result is a normal session model (the `session-model.md` schema), nothing special.

## Step 5: Coverage critic
Run `${CLAUDE_PLUGIN_ROOT}/skills/create/references/completeness.md` Part 1 against the merged model
before selecting components. Fold omitted salient items in; note intentional omissions for the coverage note.

## Step 6: Select components

Read the renderer references from `${CLAUDE_PLUGIN_ROOT}/skills/create/references/` and run the shared
**select** stage of `../render/references/render-contract.md` against the merged model — the single
canonical source for the shared select→assemble→self-check→write mechanics (map to components via
`authoring-guide.md` + `components/index.md`; "omit empty, never stub"; compose bespoke where nothing fits).

## Step 7: Assemble the HTML

Assemble per the shared **assemble** stage of `../render/references/render-contract.md`: copy
`page-scaffold.md` verbatim, fill its component slots from the recipes you selected, inline
`interactivity.md` into `{{INTERACTIVITY_JS}}`, emit the inert `{{DATA_JSON}}` island, and generate
`{{NAV_LINKS}}` deterministically from `sections[]`; self-contained, only the one Google Fonts `@import`.
**Update-specific:** fill `{{KICKER}}` from session metadata (date · primary type · scope), uppercase per
`page-scaffold.md` — the nav status line; produce **no** update chrome — no "updated" badge, no changelog;
the document simply reflects the new combined state.

## Step 8: Self-check (structure)
Run the shared **self-check** stage of `../render/references/render-contract.md`
(`${CLAUDE_PLUGIN_ROOT}/skills/create/references/self-check.md`) against the assembled HTML; fix and
re-check before overwriting.

## Step 9: Write in place

Overwrite `TARGET` with the assembled HTML. Keep the same filename — do not write a new timestamped
file, do not create a backup. (`.claude/walkthrough/` already exists and is gitignored from the first
`create` run, so no gitignore prompt is needed; honor the persisted gitignore choice in any existing `.claude/walkthrough/settings.md` and do not re-prompt.)

## Step 10: Offer to open

Tell the user the path (under three lines). Offer to open it:

```bash
open "<TARGET>"        # macOS;  xdg-open on Linux
```

Do not auto-open; offer.

Include the `completeness.md` Part 2 coverage note (included / intentionally omitted) in the message,
above the open offer. It is a passive summary, not an `AskUserQuestion`.

## Key Rules
- **Confirm before overwrite.** Step 1 always resolves the target through a user confirmation, even when model-invoked. There is no silent-overwrite path.
- **Reconstruct, don't fabricate.** Recover only what the HTML actually contains; the `DET` store is the reliable source for details. Note partial fidelity on degraded input.
- **Named files drive; conversation frames.** No automatic git discovery of changes. No paths → ask which files changed.
- **One coherent doc.** Revise/merge/add into a single narrative; keep ids stable; never staple old + new.
- **Same look, reused renderer.** Render via create's renderer references unchanged — six `references/` files plus the `components/` catalog (index + on-demand group recipes); tokens only, self-contained, one Google Fonts `@import`.
- **In place, seamless.** Overwrite the same file; no new file, no backup, no update chrome.
- **Read-only except the final write.** Never execute session-derived code; only read the named and cited files.
- **AskUserQuestion guard.** The target picker uses fixed-length option lists per `.claude/rules/ask-user-question-guard.md`.
- **Self-check before write.** Run `self-check.md` on the assembled HTML; never write a document that fails it.
- **Completeness gate.** Run the coverage critic after synthesis and surface the coverage note at the offer step.
