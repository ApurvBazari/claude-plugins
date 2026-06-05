# Completeness -- coverage critic + coverage note

Two parts. Part 1 runs after the model is synthesized/merged, before assemble. Part 2 runs in the
offer step, after write. This gate guards *coverage*; the self-check guards *structure*.

## Part 1 -- coverage critic (after synthesis, before assemble)

Re-scan the source (the session transcript for `create`; the reconstructed prior model + named files
for `update`; the subject's canonical files for `document`). For each salient item, confirm it is
either represented in the model OR deliberately out of scope. Sweep at minimum:

| Category | Examples |
|----------|----------|
| Decisions | choices made, options rejected, rationale |
| Files / surfaces | everything created/edited/deleted, not only headline ones |
| Gotchas / constraints | edge cases, invariants, things that bit |
| Follow-ups | open questions, deferred work, out-of-scope notes |
| User corrections | anything the user explicitly asked for or pushed back on |

Fold anything missing into the model. Record anything intentionally dropped with a one-line reason.

## Part 2 -- coverage note (in the offer step, after write)

In the offer-to-open message, include a short passive summary:

> **Coverage:** included -- <comma list of the main things rendered>. Intentionally omitted --
> <item: one-line reason>, ...

It is a display, NOT an AskUserQuestion. The user can ask to fold any omission back in.
