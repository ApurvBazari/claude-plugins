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

## Report
Record pass/fail per line above, the Cowork build/version, and any rendering screenshots.
File issues for any failure; re-run after fixes until all green.
