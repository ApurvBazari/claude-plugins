# lens

> Part of [`claude-plugins`](../README.md) — see also [`onboard`](../onboard/), [`notify`](../notify/), [`handoff`](../handoff/), and [`walkthrough`](../walkthrough/).

Review Claude's work **before it ships** — against the spec and plan it was supposed to follow. lens runs inside the live session that produced the code, so it can ask the one question no diff-only reviewer can: *did this build what was actually asked, and did it follow the plan?* A bug-free implementation of the **wrong** spec is the failure that `/code-review` and external PR bots can never catch — and lens can.

## Install

```bash
claude plugin install lens@apurvbazari-plugins
```

That's it. No setup step required up front — lens does a small first-run setup the first time you review in a repo (see [Where files go](#where-files-go)).

## Skills

- `/lens:review [target]` — intent-grounded review of the current change against its spec and plan; adversarially verifies findings and renders an interactive review (HTML via walkthrough, or a markdown fallback). Full details under [Usage](#usage) below.

> `engine` is an internal building block (`user-invocable: false`) — the data-only judgment core that `review` calls; you never invoke it directly.

> `render-review` is also internal — the pure HTML render entrypoint an orchestrator (e.g. matali) calls after `engine`; you never invoke it directly.

## Usage

```
/lens:review [target]
```

Run it when you've finished a change and want a second, intent-aware opinion before you commit, push, or open a PR. With no argument, lens reviews the working tree plus this branch's commits against the merge-base with the default branch. The optional `target` overrides the diff scope (a path, a ref, a range).

### What it does

lens reviews **the current session's diff against its own intent**. It resolves what you were trying to build (from the spec and plan), reads the actual diff and source, and produces a review that judges the work on two axes a diff-only tool can't reach:

- **Spec adherence** — does the change implement what the spec asked for, no more and no less?
- **Plan adherence** — did it follow the plan it set out, or quietly diverge?

On top of that it runs the usual correctness, risk, test-gap, and (via optional adapters) security / type / silent-failure / comment checks. Every candidate finding then survives an **adversarial verification** pass — an independent skeptic agent tries to refute it against real source, and only unrefuted findings make the report. The output is an **interactive review document** you read, then decide what to do. lens never decides for you.

### The brain and the eyes

lens is the **brain** — it judges. [`walkthrough`](../walkthrough/) is the **eyes** — it renders. lens does the reasoning (scope, intent, analysis, verification) and produces a structured review model; it then hands that model to `walkthrough:render` to become a self-contained interactive HTML review document, in the same house style as every other walkthrough.

- **walkthrough present** → you get the full interactive HTML review (annotated diff hunks, an adherence panel, a findings list, an overall verdict).
- **walkthrough absent** → lens degrades gracefully to a self-contained **markdown report** with the same content. No install of walkthrough is required to use lens; you just get a plainer artifact.

Neither plugin imports the other. lens checks for walkthrough at runtime and skips silently to the markdown fallback if it isn't installed.

### Optional adapters (the hybrid tap)

If you have other review tooling installed (e.g. the `pr-review-toolkit` agents), lens can tap it as an **optional read-only adapter** — a second set of specialized finders feeding the same review. Adapters are runtime-detected and skipped silently when absent. Every adapter is constrained to the same read-only, findings-only contract as lens itself: an adapter can report, never edit, stage, commit, or block.

## Where files go

All lens state lives under `.claude/lens/`. On the first review in a repo, lens does a one-time setup:

- asks whether to add `.claude/lens/` to `.gitignore` (review artifacts can contain session content — gitignoring is the default offer), and
- asks for a default output path for rendered reviews.

Both choices persist to `.claude/lens/settings.md`, which also holds your **project-custom finder registry** (extra finders specific to this codebase). The rendered review is written under `.claude/lens/`, and `.claude/lens/review-state.json` records prior findings and their statuses so a re-review can show what's **fixed / still open / new** and the **severity trend** over time.

## What it is / isn't

**It is** an intent-grounded, in-session review companion. It reads the diff and the source, reconstructs what you were asked to build, verifies its own findings adversarially, and renders a review document for a human to act on.

**It is NOT:**

- **a diff-only linter** — the whole point is judging against spec and plan, not just the patch in isolation.
- **a CI gate** — in v1 lens runs in your session, on demand. It does not run in CI and does not gate merges.
- **anything that writes to your code** — lens is **read-only by contract**. It never commits, edits, stages, or blocks. The only things it writes are the rendered review artifact and `.claude/lens/review-state.json`. You read the review; you decide.

## License

[MIT](../LICENSE)
