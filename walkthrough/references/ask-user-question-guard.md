# AskUserQuestion Single-Option Guard

`AskUserQuestion` needs at least **two** options in every question (`options.minItems: 2`). A call
with one option fails with `Invalid tool parameters`. Most of walkthrough's questions have a fixed
list of two or more options. `update`'s target picker builds its list from the pages it finds, so it
follows the tree below: with one page it asks yes/no instead of a one-option list.

## Decision tree

```
options = build_options(...)

if len(options) == 0:
  ┗ SKIP the question entirely — nothing to ask.

elif len(options) == 1:
  ├─ standalone question
  │    → ask a single-select yes/no instead:
  │       AskUserQuestion({
  │         question: "Use <the-only-candidate>?",
  │         multiSelect: false,
  │         options: [
  │           { label: "Yes", description: "<why it is offered>" },
  │           { label: "No",  description: "Skip this" }
  │         ]
  │       })
  │
  └─ one group inside a call that asks several questions at once
       → pad that group with an explicit None option and keep the single call:
          options = [
            { label: <the-only-candidate>, description: "..." },
            { label: "None / Skip", description: "Do not include anything from this group" }
          ]

elif len(options) >= 2:
  ┗ pass through — no guard needed.
```

## Rules

- A selected `None / Skip` means the same as selecting nothing in that group.
- Do not fall back to several separate calls when one call was planned.
- Do not append `None / Skip` when there are already two or more real options.
- When a skill adds a question with a data-built option list, cite this file next to the call.
