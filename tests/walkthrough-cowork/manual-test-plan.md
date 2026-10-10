# walkthrough — Cowork manual acceptance test

Pair-test: Claude prepares this; the user runs it in the **Claude Cowork desktop app** (Claude
cannot drive Cowork) and reports results back. Goal: prove walkthrough is first-class in Cowork.

## Setup
1. Install walkthrough in Cowork (marketplace `walkthrough@apurvbazari-plugins`, or a local plugin dir).
2. Prepare two Cowork projects:
   - **A — non-git folder** (a plain Documents folder) — the knowledge-work case.
   - **B — a git repository** — the control.

## Procedure
For each project: run a short working session, then trigger walkthrough **both** ways:
- the slash form `/walkthrough:create`
- intent: ask "walk me through what we did"

## Pass/fail checklist
- [ ] **A (non-git):** first run shows the output-location prompt (Visible `walkthroughs/` vs Hidden `.claude/walkthrough/`).
- [ ] **A:** the choice persists — a 2nd `create` in the same folder does NOT re-prompt.
- [ ] **A:** if "Visible" chosen, the HTML is in `walkthroughs/` and `settings.md` is co-located there; NO stray `.claude/` directory is created.
- [ ] **B (git repo):** NO location prompt; HTML written to `.claude/walkthrough/` (today's behavior).
- [ ] Open the produced HTML in a browser: both themes + the dark/light toggle work.
- [ ] Diagrams render (inline SVG); detail surfaces open — pane and sheet; interactivity (selector → diagram + detail) works.
- [ ] **Offline font fallback:** with the font fetch blocked (offline / devtools request-block), text still renders in a sane native font (existing generic-family fallback) — no bare/broken type.
- [ ] Self-contained: devtools shows no console errors and no failed external requests except the Google Fonts `@import`.
- [ ] The in-session coverage summary (included / intentionally omitted) is shown after writing.

## Probes (1.6.0) — what Cowork does with a plugin path and with plugin agents

Two facts the 1.6.0 design could not confirm from outside Cowork. Both have a fallback, so neither
blocks a release; the answers decide what the README's "Works in Cowork" section may say. Run them
with **released** plugins (walkthrough 1.5.0 or later, and lens): no branch has to be installed.

**P1 — does a plugin path reach the skill, and can the shell read a file at it?** In a Cowork session:

1. Run `/walkthrough:update`. When it asks which document to update, answer and then stop it; the
   point is only that the skill has loaded.
2. Ask: *"Quote, exactly as you received it, the `completeness.md` path in Step 5 of the update skill.
   Does it start with a real path or with the literal text `${CLAUDE_PLUGIN_ROOT}`? Also quote the
   'Base directory for this skill' line you were given, or say there was none."*
3. Ask it to run, in its shell, and paste the output of each:
   - `ls -la '<the path from step 2>'`
   - `echo "${CLAUDE_PLUGIN_ROOT:-unset} ${CLAUDE_SKILL_DIR:-unset}"`
   - `command -v awk node`

Record: the quoted path; the base-directory line; whether `ls` found the file; both variables; which of
`awk` and `node` exist.

**P2 — can a plugin agent be dispatched?** With lens installed:

1. Ask: *"List the agent types you can dispatch. Is `lens:verifier` among them?"*
2. If it is: *"Dispatch `lens:verifier` with the prompt: reply with the single word READY and the list
   of tools you have."* Record the reply.

Record: whether the agent is listed, whether the dispatch returned, and the tools it reported.

## System map (1.6.0)

In either project, ask for something with parts and connections (*"walk me through how the services
fit together"*), then, in project B, run `/walkthrough:document . architecture`.

- [ ] The message after writing carries one `System map engine:` line. Record which: *inserted by shell command*, *typed by the model*, or *not included*.
- [ ] Open the page: the map is laid out, with wires and arrowheads. *Expand all*, *collapse all* and *reset* work; a closed boundary opens when clicked.
- [ ] With JavaScript disabled in the browser, the same page shows the boxes, nested, and the open list of connections.
- [ ] For `document . architecture`: the message carries a reading line. Record which: *Read by agents* or *Read inline*.
- [ ] Every box opens a detail with a file and line; inferred boxes are dotted and say so; the page has a "Gaps" section if anything was skipped.
- [ ] No environment-variable value appears anywhere on the page.

## Report
Record pass/fail per line above, the Cowork build/version, and any rendering screenshots.
File issues for any failure; re-run after fixes until all green.
