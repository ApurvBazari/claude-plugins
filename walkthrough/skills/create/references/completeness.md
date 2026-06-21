# Completeness -- coverage critic + coverage note

Two parts. Part 1 runs after the model is synthesized/merged, before assemble. Part 2 runs in the
offer step, after write. This gate guards *coverage*; the self-check guards *structure*.

## Part 1 -- coverage critic (after synthesis, before assemble)

Run this as **two ordered steps** -- derive the checklist from the source FIRST, *then* compare it to
the model. The order matters: it keeps the critic from rubber-stamping its own synthesis. You are
checking the model against the source, not asking "did I miss anything?" of the thing you just wrote --
that self-attesting question is exactly how dropped details get reclassified as "intentional."

**Step A -- re-derive the salient-item checklist from the source, independent of the model.** Re-scan
the source (the session transcript for `create`; the reconstructed prior model + named files for
`update`; the subject's canonical files for `document`) and list every salient item *before* looking at
what you rendered. Sweep at minimum:

| Category | Examples |
|----------|----------|
| Decisions | choices made, options rejected, rationale |
| Files / surfaces | everything created/edited/deleted, not only headline ones |
| Code anchors | every `path:line` the source names -- each is a first-class detail |
| Gotchas / constraints | edge cases, invariants, things that bit |
| Follow-ups | open questions, deferred work, out-of-scope notes |
| User corrections | anything the user explicitly asked for or pushed back on |

**Step B -- diff the checklist against the model.** For each item, confirm it is either represented OR
deliberately out of scope, then:

- **Fold anything missing into the model.**
- **Depth, not just presence.** An item that carries real mechanism nuance in the source -- a "why it
  works this way," a subtle failure mode, a non-obvious mechanism -- must carry that nuance in its
  `details{}` `summary`/`points`, not a one-line restatement of its label. A present-but-shallow detail
  is an omission: deepen it.
- **In-session facts are non-droppable.** A `path:line`, decision, or gotcha the source actually
  contains may NOT be dropped as "unverified" or "not read" -- it was given to you; cite it. The only
  valid reason to omit something present in the source is **content-based**: genuinely out of scope, or
  redundant with another rendered item. Record each such omission with that one-line content reason.

## Part 1b — Concept-coverage assertion (mechanical)

After component selection, walk `concepts[]` and assert every entry rendered faithfully:

- Each entry has either `renderedBy` set to the component **registered for its `type`** in
  `concept-coverage.md`, OR `bespoke:true` with a non-empty `bespokeReason`.
- No entry is rendered by a component NOT registered for its type (a **force-fit** — a defect).
- No `concepts[]` entry is left unrendered (no `renderedBy` and not `bespoke`).

Any force-fit or unrendered concept is a defect to FIX before assemble — same discipline as the
structural self-check. This is a mechanical walk, not a judgment call.

## Part 2 -- coverage note (in the offer step, after write)

In the offer-to-open message, include a short passive summary:

> **Coverage:** included -- <comma list of the main things rendered>. Intentionally omitted --
> <item: one-line content reason>, ...

Every "intentionally omitted" reason must be **content-based** (out of scope / redundant) -- never a
process excuse like "file not read" for material the session already contained. It is a display, NOT an
AskUserQuestion. The user can ask to fold any omission back in.

Also include a concept-coverage line in the note: **"Explained N concepts across M types · F force-fits
· K bespoke."** (F must be 0 — a non-zero F means Part 1b was not honored.)
