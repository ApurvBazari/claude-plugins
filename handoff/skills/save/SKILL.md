---
name: save
description: Save the current session's intent as a handoff file so the next session can pick it up. Auto-invokes when the user signals end-of-session with phrases like "save handoff", "pick this up later", "continue in new session", "handoff this", "I'll come back to this", or "save for later". Prompts for confirmation via AskUserQuestion before writing — false positives are zero-cost. Slash form `/handoff:save` is the no-confirm fallback.
---

# Save Skill — Capture Session Intent for Handoff

You are auto-invoked when the user signals end-of-session, or invoked explicitly via `/handoff:save`. Capture what the next session needs to pick up, then write it to `.claude/handoff/active.md`.

## Step 1: Determine invocation mode

| Trigger | Mode |
|---|---|
| User typed `/handoff:save` (explicit) | **Direct mode** — skip the confirm step in Step 2; proceed straight to Step 3 |
| Auto-invocation on NL trigger phrase | **Confirm mode** — run Step 2 before anything else |

If unsure, default to **Confirm mode** — a single AskUserQuestion is always safer than a silent false-positive save.

## Step 2: Confirm before saving (Confirm mode only)

Ask the user via AskUserQuestion (single-select, 3 options):

- **Save now** *(Recommended)* — "I'll draft a directive from the current session and write it to `.claude/handoff/active.md` immediately."
- **Edit before saving** — "I'll draft a directive, show it to you, let you edit, then write."
- **Cancel** — "Don't save. I'll continue the current task."

If **Cancel**: exit silently. Do not write anything.
If **Save now** or **Edit before saving**: proceed to Step 3.

## Step 3: Synthesize the directive

Draft a directive (3-6 bullets or short prose) capturing what the next session must know to pick up cleanly. Pull from the current conversation context.

Include:

1. **What to pick up** — the concrete next step (one sentence, action-oriented).
2. **Pointers** — memory files, key source paths, git refs, PR numbers worth reading first.
3. **Constraints** — what NOT to do (decisions already made, scope guards, "don't relitigate X").
4. **State expectations** — what should be true at resume (e.g., "PR #50 is open against develop, do not push").
5. **Open questions** — if any are unresolved and the next session needs to handle them.

Style rules:

- **Directive prose only.** Do NOT embed state that the next session can derive — git log will tell them current commits / branch / working-tree status; memory files will tell them prior context. Capture intent, not snapshots.
- Use present-tense imperative addressing the future Claude instance: "Read `<memory>` first", "Do NOT push without confirming".
- Length budget: under 400 words. If you need more, the directive is doing too much.
- If the user is in the middle of a multi-step task with a written plan, point to the plan rather than restating it.

## Step 4: Edit gate (only if user picked "Edit before saving")

Present the draft directive to the user as a code block. Ask: "Edit anything before saving? Tell me what to change, or say 'looks good' to proceed."

Iterate until the user approves, then continue to Step 5.

## Step 5: Capture frontmatter metadata

Compute the metadata via Bash:

```bash
saved_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
saved_at_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
saved_at_branch="$(git branch --show-current 2>/dev/null || echo unknown)"
saved_from_cwd="$(pwd)"
```

If git fails (not a repo), use `unknown` for sha and branch. Skip nothing — the file should always have all four fields.

## Step 6: Check overwrite

If `.claude/handoff/active.md` already exists, ask via AskUserQuestion (single-select, 3 options):

- **Overwrite** *(Recommended)* — replace the existing handoff with the new one.
- **Append** — keep the old content and add the new directive below it under a `## Previous handoff (saved <old-saved-at>)` heading.
- **Cancel** — keep the existing file; abort the save.

The existing handoff's `saved-at` is in its frontmatter — read it for the prompt.

## Step 7: Write the handoff file

Create `.claude/handoff/` if it doesn't exist (`mkdir -p`). Write `.claude/handoff/active.md` with frontmatter:

```markdown
---
saved-at: <iso8601-utc>
saved-at-sha: <short-sha>
saved-at-branch: <branch>
saved-from-cwd: <abs-path>
---

<directive prose from Step 3 / Step 4>
```

Do NOT include `deferred-at` — that field is written only by the resume flow.

## Step 8: Gitignore prompt (first save only)

Read `.claude/handoff/settings.md` if present. If `gitignore-prompt: never`, skip.
If `.gitignore` doesn't exist, or already contains `.claude/handoff/`, skip.
Otherwise present the prompt at `references/prompts/gitignore.md` — verbatim
option text — and apply the per-option behavior documented there.

## Step 9: Retention prompt (first save only)

Read `.claude/handoff/settings.md` if it exists. If the `archive-retention` key is present, skip this step — the user has already made the choice.

Otherwise, ask via AskUserQuestion (single-select, 4 options):

- **Default 10** *(Recommended)* — "Keep the most recent 10 archived handoffs (consumed + discarded + expired combined)."
- **5** — "Keep the most recent 5."
- **20** — "Keep the most recent 20."
- **Don't ask again** — "Use the default 10 and don't ask again."

Per-option write to `.claude/handoff/settings.md` (the `archive-retention` key — append to existing frontmatter, do not clobber `gitignore-prompt` or other keys):

| Selection | Key written |
|---|---|
| Default 10 (Recommended) | `archive-retention: 10` |
| 5 | `archive-retention: 5` |
| 20 | `archive-retention: 20` |
| Don't ask again | `archive-retention: 10` |

"Default 10" and "Don't ask again" produce identical settings — the distinction is purely UX (whether the user inspected the default or just dismissed). No separate flag is written.

To merge a key into existing settings frontmatter without clobbering siblings, call the shared helper:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/merge-fm-key.sh" .claude/handoff/settings.md archive-retention 10
```

The helper handles all three cases atomically:
- File missing → creates `.claude/handoff/settings.md` with `---\narchive-retention: 10\n---`.
- File present but key absent → appends the key just before the closing `---`, preserving sibling keys.
- File present with key already there → replaces the value in place.

Substitute the trailing `10` for `5` or `20` per the user's selection.

## Step 10: Confirm with the user

Tell the user (terse — under three lines):

> Saved to `.claude/handoff/active.md` (sha `<short-sha>` on `<branch>`). Will surface at next SessionStart in this project.

Mention the gitignore step if it ran ("Added `.claude/handoff/` to `.gitignore`."). Don't list the directive content back — they already saw it (or wrote it).

## Key Rules

- **Confirm step is non-negotiable in Confirm mode.** Even a "high-confidence" NL trigger gets the AskUserQuestion gate. False positives are zero-cost.
- **Directive only, no state.** Don't embed commits / working-tree / task lists — derivable at resume.
- **Always set all four frontmatter fields** (`saved-at`, `saved-at-sha`, `saved-at-branch`, `saved-from-cwd`). Use `unknown` if computation fails; do not omit.
- **Single active slot.** If a handoff already exists, prompt before overwriting. Do not silently replace.
- **Gitignore prompt is once-per-repo.** Persist the user's choice in `.claude/handoff/settings.md` so future saves don't nag. The retention prompt is also once-per-repo, suppressed by the presence of the `archive-retention` key.
- **No `deferred-at` on save.** That field belongs to the resume flow's "Save for later" path.
- **AskUserQuestion guard** (`.claude/rules/ask-user-question-guard.md`): all four AskUserQuestion calls in this skill have static, fixed-length option lists (3 options each for Steps 2, 6, and 8; 4 options for Step 9). No dynamic single-option risk.
