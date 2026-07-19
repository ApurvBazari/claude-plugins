---
name: render
description: Render a structured model already present in this conversation into the house-style HTML, as-is (no session synthesis). Internal building block invoked by other skills/plugins (e.g. lens) that have already assembled a model. Not for users — for a synthesized session recap use /walkthrough:create.
user-invocable: false
---

# Render — Assemble a Supplied Model into the House Style

You are invoked by a caller (e.g. the `lens` plugin) that has **already synthesized a model in
context**. You are the **programmatic entry** for the terminal render stages: skip gather + synthesize
and run only select → assemble → self-check → write. The model conforms to
`../create/references/session-model.md` (review fields allowed).

`references/render-contract.md` is the **canonical description** of those four shared stages (it is the
same select → assemble → self-check → write every producer ends on) plus the review-specific assembly
(`findings[]` → sheets, `diffHunks[]`, `adherence`, `verdict`). Follow it for the render half.

## Step 1: Locate the model + output path
The caller passes (a) a structured model in context and (b) an output path argument. If NO model is
present in context, stop and tell the user: "Nothing to render — use /walkthrough:create for a session
recap." Never synthesize from the transcript here.

## Step 2: Run the shared render stages
Run **select → assemble → self-check → write** exactly as described in `references/render-contract.md`,
including its § Review-specific assembly for `findings`/`diffHunks`/`adherence`. Write to the
caller-supplied output path (create the directory if missing); do not prompt for gitignore (the caller
owns its output location). Return the written path to the caller.

## Key Rules
- **Internal only.** `user-invocable: false`; callers invoke it via the Skill tool.
- **No synthesis.** Render the supplied model verbatim — never re-derive from the transcript.
- **Follow the contract.** The shared stages + review assembly live in `references/render-contract.md`; this
  skill is their programmatic entry point, not a second copy of them.
- **Self-contained + tokens only.** Same invariants as create; run the structural self-check before write.
- **Empty context → redirect to create.** Never silently fall back to synthesis.
