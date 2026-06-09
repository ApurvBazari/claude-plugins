---
name: render
description: Render a structured model already present in this conversation into the house-style HTML, as-is (no session synthesis). Internal building block invoked by other skills/plugins (e.g. lens) that have already assembled a model. Not for users — for a synthesized session recap use /walkthrough:create.
user-invocable: false
---

# Render — Assemble a Supplied Model into the House Style

You are invoked by a caller (e.g. the `lens` plugin) that has **already synthesized a model in
context**. Skip gather + synthesize; run only select → assemble → self-check → write. The model
conforms to `references/session-model.md` (review fields allowed). Read `references/render-contract.md`.

## Step 1: Locate the model + output path
The caller passes (a) a structured model in context and (b) an output path argument. If NO model is
present in context, stop and tell the user: "Nothing to render — use /walkthrough:create for a session
recap." Never synthesize from the transcript here.

## Step 2: Select components
Map the model to components via `../create/references/authoring-guide.md` + `../create/references/components/index.md`
(including the `review.md` group for `findings`/`diffHunks`/`adherence`). Apply omit-empty, never stub.

## Step 3: Assemble
Start from `../create/references/page-scaffold.md`; inline the `@import` + both `:root` blocks from
`../create/references/design-system.md`, the shared JS from `../create/references/interactivity.md`,
and the CSS/HTML for each selected component. Build `DET` + `SURF` + `{{SHEETS}}` from the model's
detail surfaces and `findings[]` (each finding → a sheet; `SURF[id]='sheet'`).

## Step 4: Self-check
Run `../create/references/self-check.md` against the assembled HTML. Fix and re-check; never write a
failing document.

## Step 5: Write
Write the HTML to the caller-supplied output path (create the directory if missing). Do not prompt for
gitignore (the caller owns its output location). Return the written path to the caller.

## Key Rules
- **Internal only.** `user-invocable: false`; callers invoke it via the Skill tool.
- **No synthesis.** Render the supplied model verbatim — never re-derive from the transcript.
- **Reuse the renderer unchanged.** All visual-layer references come from `../create/references/`.
- **Self-contained + tokens only.** Same invariants as create; run the structural self-check before write.
- **Empty context → redirect to create.** Never silently fall back to synthesis.
