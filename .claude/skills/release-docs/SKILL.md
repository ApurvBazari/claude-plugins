---
name: release-docs
description: Bring every doc surface (site pages, the root and plugin READMEs, the root CLAUDE.md tree and cross-plugin references) in line with what a release ships. It runs the docs detector over origin/main..HEAD, applies the mechanical fixes, edits the rest in place from the sources, declares every new CHANGELOG entry in the coverage ledger, and verifies the result (re-detect, render-check, the docs-verifier agent, belts and guards). Use before a develop→main release, or when the "Docs Obligations" check is red. It runs locally or as the CI docs bot (mode=ci).
disable-model-invocation: true
---

# Release Docs — Sync the Docs With What a Release Ships

You are running the release docs sync. A script has already decided what must change (the obligations). Your job has three parts: make those changes truthfully from the sources, declare coverage in the ledger, and prove the result with the checks. Read `references/obligations.md` (what each obligation means and how to resolve it) and `references/page-style.md` (rules for every page edit) before editing anything.

Arguments: `mode=local` (the default) or `mode=ci`. In `mode=ci`, nobody will answer a question, so never ask one. Anything that needs a person goes into the report.

Paths used below:

- scripts: `.claude/skills/release-docs/scripts/docs-detect.sh`, `.claude/skills/release-docs/scripts/post-checks.sh`, `.claude/skills/release-docs/scripts/render-check.sh` and `.claude/skills/release-docs/scripts/og-regen.sh`
- surfaces: `.github/docs-surfaces.json` (at the repo root, not under this skill)
- ledger: `.github/docs-ledger.json`
- run directory: `.release-docs/run/` (gitignored). It holds `before.snap`, `obligations.before.json`, `verifier.json`, `post-checks.md`, `pr-body.md` and `shots/`.

## Guard

- `.claude-plugin/marketplace.json` must exist in the working directory. If it doesn't, you're not at the claude-plugins root: stop.
- Tracked files must be clean (`git diff --quiet HEAD`). If they aren't, stop and say which files are dirty. Untracked files belong to the owner: never touch them.
- `mode=local`: if the current branch is `main` or `develop`, run `git switch -c docs/release-sync-<YYYYMMDD>` first. Never commit on `main` or `develop`.
- `mode=ci`: the workflow has already created the branch and written the snapshot to `.release-docs/run/before.snap`. Never create or switch branches, commit, or push. Never run `post-checks.sh --snapshot`: the workflow owns the snapshot, and `--snapshot` refuses to overwrite an existing file.

## Step 0: Snapshot

`mode=local` only (CI has already done this). Start from an empty run directory, so no file from an earlier run is read as this run's:

```bash
rm -rf .release-docs/run && mkdir -p .release-docs/run
git fetch -q origin main
bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot .release-docs/run/before.snap
```

The snapshot is JSON: HEAD, plus every path dirty before the run with a digest of its content. The write fence in Step 5 compares against it. Never write to `before.snap` after this step.

## Step 1: Detect

```bash
bash .claude/skills/release-docs/scripts/docs-detect.sh --out .release-docs/run/obligations.before.json
```

Read the report. If `open` is 0, reply "nothing to sync" and stop.

## Step 2: Mechanical fixes

```bash
bash .claude/skills/release-docs/scripts/docs-detect.sh --fix-mechanical
```

## Step 3: Content edits

Resolve every open obligation whose `resolver` is `model`, in this order: plugin pages, then the landing page, then READMEs and the root `CLAUDE.md`, then cross-plugin references.

- **Sources, in order of authority:**
  1. The CHANGELOG entries in the range. Each `changelog-entry` obligation carries its `text`, cut at 200 characters, so read the whole bullet in the CHANGELOG.
  2. The plugin's README.
  3. SKILL.md frontmatter.
  4. The range diff: `git diff <base>..HEAD -- <plugin>/`, where `base` is the report's `range.base`.

  Never state a capability, count, path or behaviour that no source states.
- **`page-missing` for a site page:** invoke the walkthrough document skill (`Skill` tool, `walkthrough:document`, arguments `<plugin> site/<plugin>/index.html`) from this main session. It can't be dispatched to a subagent. Then follow the `page-missing` row of `references/obligations.md`.
- **`site/og.png`:** when `site/og-card.html` changes, regenerate the card with `bash .claude/skills/release-docs/scripts/og-regen.sh`, never by hand. If it prints `og.png NOT regenerated`, `site/og.png` is untouched; put that in the report for the owner.
- Follow `references/page-style.md` on every page edit.

## Step 4: Ledger

- For each `changelog-entry` obligation, add its `id` to `.github/docs-ledger.json` `entries`:
  - `{"disposition": "covered", "at": ["<file>#<anchor>", …]}`, pointing at the text that documents it;
  - or `{"disposition": "not-user-facing", "reason": "…"}`.
- Never write `waived`: that disposition is the owner's.
- For a `stale-mention` you decide is deliberately historical, add an `intentional` entry: `file`, `token` (the obligation's own `token`), `context` (a phrase on that exact line) and `reason`.
- List the range candidates with `bash .claude/skills/release-docs/scripts/docs-detect.sh --candidates origin/main..HEAD`. Append each one you confirmed as retired to `retired[]` in `.github/docs-surfaces.json`, and leave out any that are still live names.
- In `.github/docs-surfaces.json`, change only the `og` and `retired` keys. The write fence fails the run if `surfaces`, `frozen`, `pages` or `landing` change.

## Step 5: Verify

1. Re-detect with `bash .claude/skills/release-docs/scripts/docs-detect.sh --gate`. If obligations are still open, fix what can be fixed inside the doc surfaces and re-detect, at most 2 more times. Then list every obligation still open, and why, in the report and go on. Some are the owner's by rule, such as a manifest `inventory-row` (`references/obligations.md` note 1).
2. Dispatch the `docs-verifier` agent. Its prompt is two things:
   - the output of `git diff HEAD` over the changed doc files. A new file (such as a generated page) is untracked, so `git diff HEAD` leaves it out: add `git diff --no-index -- /dev/null <file>` for each one;
   - the source paths: each changed plugin's `CHANGELOG.md`, `README.md`, `skills/`, `agents/` and `scripts/`.

   Write the JSON array it returns to `.release-docs/run/verifier.json` yourself (the agent is read-only).
   - Fix each `refuted` claim.
   - Cut each `unsupported` claim, or rewrite it to what a source states.
   - Dispatch the verifier once more on the new diff (at most 2 rounds). Keep the final array in `verifier.json`; any non-`ok` items left are reported, not hidden.

   If the verifier can't be dispatched, or returns no JSON array, don't write `verifier.json` and say so in the report. The PR body is still built with that path (by Step 6 locally, by the workflow in CI), so it shows "verifier output missing" rather than leaving the section out.
3. Run the deterministic checks:

   ```bash
   bash .claude/skills/release-docs/scripts/post-checks.sh --before .release-docs/run/before.snap \
     --report .release-docs/run/post-checks.md --shots .release-docs/run/shots
   ```

   `post-checks.sh` runs the write fence, the no-waiver check, the gate, `render-check.sh` on the changed pages, and every belt and guard. Its exit code decides what happens next:

   - **0:** everything passed.
   - **1:** read `post-checks.md`. Fix only what is inside the doc surfaces, and run it again, at most 2 more times. Then list every failure that can't be fixed inside the fence in the report, and go on to Step 6. Those include:
     - obligations that are the owner's by rule;
     - belts and guards that fail outside the surfaces;
     - an overflow that `references/page-style.md` rule 11 calls pre-existing;
     - a fence failure on a path the owner had dirty before the run.
   - **2:** bad input. The fence didn't run, so the tree is unchecked. Stop, and never commit it.

## Step 6: Report

- `mode=local`:
  - Build the PR body. Always pass `--verifier`, even when the verifier didn't run:

    ```bash
    bash .claude/skills/release-docs/scripts/docs-detect.sh --pr-body \
      --before .release-docs/run/obligations.before.json \
      --verifier .release-docs/run/verifier.json > .release-docs/run/pr-body.md
    ```

  - Show the owner the resolved, still-open and verifier-disagreement sections, and point them at `.release-docs/run/shots/`.
  - Commit on the branch when `post-checks.sh` exited 0, or when it exited 1 and the owner, shown what still fails, says to commit anyway. Never commit after exit 2.
    - `git add` each file this run changed, by name: the doc surfaces, `.github/docs-ledger.json`, `.github/docs-surfaces.json`, `site/og.png` and any new `site/<plugin>/index.html`. Never `git add -A` or `git add .`.
    - `git commit` as `docs(release): sync docs for <base7>..<head7>` (the 7-character SHAs of the report's `range`), with the repo's `Co-Authored-By` trailer.
  - Ask before pushing or opening a PR. A docs PR targets `develop`: `gh pr create --base develop`.
- `mode=ci`: don't run the `--pr-body` command. Reply with one line of counts (resolved / still open / verifier disagreements). The workflow builds the PR body itself, re-runs post-checks independently, then commits, pushes and opens the PR.

## Key Rules

- **Truth over green.** A badge-only edit, a `covered` pointer at an unrelated anchor, or an `intentional` on a genuinely stale line makes the gate pass without making the docs true. That's the exact failure this skill exists to prevent.
- **Doc surfaces only.** Never edit CHANGELOGs, SKILL.md, agents, scripts, manifests or workflows. `post-checks.sh` restores anything outside the surfaces and fails the run.
- **`.github/docs-surfaces.json`: `og` and `retired` only.** A change to `surfaces`, `frozen`, `pages` or `landing` fails the write fence.
- **Never `waived`, never `<head>` except `og-copy` (or a new page's head block under `page-missing`), never frozen docs.**
- **Sources, not memory.** Every new claim traces to a CHANGELOG entry, a README, frontmatter or the diff; the verifier checks that.
- **The snapshot is the fence's record.** Never write `.release-docs/run/before.snap` after Step 0, and never commit after `post-checks.sh` exits 2. In `mode=ci`, never run `post-checks.sh --snapshot` at all: the workflow owns the snapshot.
- **Bounded loops.** The re-detect and post-checks loops each get at most 2 more runs. After that, report what is left instead of retrying.
- **`mode=ci`:** no questions, no branch changes, no commits, no pushes.
