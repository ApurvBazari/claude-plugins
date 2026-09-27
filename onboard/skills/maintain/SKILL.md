---
name: maintain
description: Internal, non-interactive apply step of onboard's maintain entry. Given a maintain-detect report and optional owner-approved lessons (file paths), writes the new script lines marked apply into CLAUDE.md files and the approved lessons into tooling, then writes maintain-result.json. Called by an orchestrator such as matali's maintain phase; never prompts, never commits. Not user-invocable.
user-invocable: false
---

# Maintain Skill — Apply Detected Tooling Drift and Approved Lessons

You are running onboard's maintain apply step. The caller has already run `maintain-detect.sh` (a script, no model) and, optionally, collected lessons its owner approved. Your job is narrow: write the report's `apply` items and the approved lessons into tooling — verbatim, one line per fact, in each file's own style — and record what you did. The run is non-interactive: nobody will answer a question, so never ask one. Unsure → defer, never guess.

You may be running in the caller's main session or inside a subagent; the steps are the same (you need only the paths and the repository).

## Input

File paths only, given as `detect=<path> out=<path> [lessons=<path>]` or as a JSON object with those keys:

| Key | File | Contract |
|---|---|---|
| `detect` | the detect report | `${CLAUDE_PLUGIN_ROOT}/schemas/maintain-detect.json` |
| `lessons` | approved lessons (optional) | `${CLAUDE_PLUGIN_ROOT}/schemas/maintain-lessons.json` |
| `out` | where the result goes | `${CLAUDE_PLUGIN_ROOT}/schemas/maintain-result.json` |

## Who writes what

`.claude/` is a protected path in Claude Code: your Write and Edit tools may not write there in an unattended run. So:

- **You** edit `CLAUDE.md` files (Step 3) with the Edit tool.
- **`maintain-write.sh`** writes lesson entries (Step 4) and records every result entry; **`maintain-guard.sh after --result`** writes the result file (Step 5). Never write under `.claude/` or the `out` file with your own tools.

Read files — the inputs, tooling files, and this skill's `references/` — with the Read tool. Run every helper from the repository root as its own `bash "<script>" …` call — no `cd`, no shell variables, no `;` or `&&` chains, no pipes:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-guard.sh" before                   # prints <state>
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-detect.sh" --mentioned <script> --package <name|-> --manifest <package.json> <file>   # exit 0 = mentioned
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-detect.sh" --lesson-present --id <id> --text "<text>"   # {"status", "at"}
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-detect.sh" --lesson-file <glob>...                     # {"file", "exists"}
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" record --state <state> applied --id <id> --file <path> --summary "<text>"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" record --state <state> skipped --id <id> --file <path>
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" record --state <state> deferred --id <id> --reason <reason> --hint "<text>" [--existing <file:line>]
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" record --state <state> item --detect <detect> --id <id>
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" lesson --id <id> --text "<text>" --summary "<text>" --ref "<ref>" [--paths <glob>... | --file <path>]
```

## Step 0: Read and check

Read `detect`, and `lessons` if given. If a file is missing or not JSON, its `schemaVersion` is not `1`, a required top-level field is missing (`detect`: `range`, `project`, `items`; `lessons`: `lessons`), or `detect` is an error object (it has `error`):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" early --out <out> --id X1 --reason bad-input --hint "<what was wrong, one line>"
```

and stop.

## Step 1: Not onboarded (R10)

If `detect.project.onboarded` is false or `.claude/onboard-meta.json` does not exist: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-write.sh" early --out <out> --id <the not-onboarded item's id, else X1> --reason not-onboarded --command /onboard:start`, and stop.

## Step 2: Guard before

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-guard.sh" before` prints a state-file path. Every later `record` and Step 5 use it.

## Step 3: Report items

Go through `detect.items` in order.

**`inform` items:** ignore them. They never appear in the result.

**`defer` items:** `record --state <state> item --detect <detect> --id <id>` copies each one into the result as it is.

**`apply` items** (today only `script-added`) — for each:

1. **Find the target.** Walk up from the directory of the item's `file`: that directory's `CLAUDE.md`, then each parent directory's, ending at the root `CLAUDE.md`. The target is the first one with a *fitting commands section*: a heading at any level that names commands or scripts (`Commands`, `Build Commands`, `Development Commands`, `Essential Commands`, `Scripts`, or an equivalent) whose section holds at least one command entry — a list line, a table body row, a line inside a fenced code block, or an inline `A | B` line. A section of prose alone does not fit. No fitting section in any of those files → `record … deferred --id <id> --reason no-matching-section --hint "add a commands section, or run /onboard:update"` and go to the next item.
2. **Already there?** `--mentioned <name> --package <package, or - when null> --manifest <file> <target>`. Exit 0 → `record … skipped --id <id> --file <target>` and go to the next item.
3. **Write exactly one line** in the section's own style — list, fenced block, table row, or inline `A | B` — with the Edit tool. Follow `references/command-styles.md` exactly: which entry's style to copy, where the line goes, how to build the invocation (the section's runner form, including its package selector), and the description slot, which holds the item's `run` verbatim when the entries have descriptions. Never invented prose. No other line in the file changes.
4. **Check the write (D25).** Run the Step 3.2 `--mentioned` command again. Exit 0 → `record … applied --id <id> --file <target> --summary "<the invocation> under <heading>"`. Exit 1 → remove the line you just wrote, so the file is byte-identical to before, and `record … deferred --id <id> --reason unrecognized-style --hint "add the line by hand in the section's style"`. This is the only line you ever remove, and only your own.

## Step 4: Lessons

Skip this step when no `lessons` file was given. Otherwise, for each lesson in order:

1. `--lesson-present --id <id> --text "<text>"`. Status `present-id` or `present-text` → `record … skipped --id <id> --file <the file part of at>`.
2. A `target.file` that is not a `CLAUDE.md` (at any depth) and not under `.claude/rules/` → `record … deferred --id <id> --reason target-outside-tooling --hint "retarget the lesson to a CLAUDE.md or .claude/rules/"`.
3. **Near-duplicate check (D8).** Read the destination (untargeted: `.claude/rules/lessons.md`; `target.paths`: the file `--lesson-file` names; `target.file`: that file), the other `.claude/rules/lessons*.md` files, and the root `CLAUDE.md`. If an existing line already states the same rule in other words → `record … deferred --id <id> --reason possible-duplicate --existing <file>:<line> --hint "compare with the existing line"`. Only a clear restatement of the same rule counts; a related but different rule does not. Never merge or reword.
4. **Write it:** `maintain-write.sh lesson --id <id> --text "<text>" --summary "<evidence.summary>" --ref "<evidence.ref>"`, plus `--paths <each glob>` for a `target.paths` lesson or `--file <target.file>` for a `target.file` lesson. It prints `{"file": …}`; then `record … applied --id <id> --file <that file> --summary "lesson <id>"`. The bytes it writes are in `references/lesson-entries.md`. `evidence.pointer` is never passed or written.

## Step 5: Guard after — writes the result

Let `D` be the directory holding `out`. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-guard.sh" prefix-ok "D/"`; exit 0 means that folder may be exempted. Then:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/maintain-guard.sh" after --state <state> --allow <out> [--allow "D/"] --result <out>   # the second --allow only after prefix-ok exit 0
```

It restores or reports anything written outside tooling, turns each violation into a deferred `guard-violation`, and writes `out`: the recorded entries, `filesWritten` (tooling files whose content changed) and `preDirty`. Exit 3 means violations were recorded; that is still a finished run.

## Step 6: Reply

Read `out` and reply with its path and one line of counts (applied / deferred / skipped).

## Key Rules

- **Non-interactive.** No questions to the user, no subagent or skill dispatch, no task-list tools, no research runs. Anything that needs a person is deferred.
- **Never** stage, commit or push; write `.claude/onboard-meta.json`; read or clear `.claude/onboard-drift.json`; or rewrite or delete an existing tooling line. Removing the line you just wrote in Step 3.4 is not an existing line.
- **Your own writes** are `CLAUDE.md` edits only. Lesson entries and the result go through `maintain-write.sh` and `maintain-guard.sh after --result`; the guard restores anything else that was clean before.
- **Content is fixed by the input:** a script's name and its `run` command, or a lesson's text, verbatim. No invented prose, no rewording, no merging.
- **One line per script fact**, in the section's own style; the check in Step 3.4 is not optional.
- **Empty input** (no apply items, no lessons) still runs Steps 2 and 5, so an empty result is written.
