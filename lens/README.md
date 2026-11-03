# lens

Review Claude's work against the spec and plan it was meant to follow, before it ships.

**Works in:** Claude Code ✓ · Cowork: likely, untested · claude.ai chat ✗ (its six finder agents don't load in chat, and it needs the session's git diff)

> Part of [`claude-plugins`](https://github.com/ApurvBazari/claude-plugins) — see also [`onboard`](https://github.com/ApurvBazari/claude-plugins/tree/main/onboard), [`notify`](https://github.com/ApurvBazari/claude-plugins/tree/main/notify), [`handoff`](https://github.com/ApurvBazari/claude-plugins/tree/main/handoff), and [`walkthrough`](https://github.com/ApurvBazari/claude-plugins/tree/main/walkthrough).

## Install

**From Anthropic's plugin directory** (once lens is listed): on claude.ai open **Customize → Plugins**, or run `/plugin directory` in Claude Code, and add **lens**.

**From this repository's marketplace:**

```bash
claude plugin marketplace add ApurvBazari/claude-plugins
```

```bash
claude plugin install lens@apurvbazari-plugins
```

Install [`walkthrough`](https://github.com/ApurvBazari/claude-plugins/tree/main/walkthrough) as well if you want the interactive HTML review. Without it, lens writes a markdown report with the same content.

There is no setup step up front. The first time you review in a repo, lens asks two questions (see [Where files go](#where-files-go)).

## What it does

lens runs inside the session that produced the code, so it can ask the question a diff-only reviewer can't: *did this build what was asked, and did it follow the plan?* A clean build of the wrong spec is the failure `/code-review` and PR bots never catch.

- Works out what you meant to build: the spec and plan files that match the diff, or the intent stated in this session.
- Checks the diff for **spec adherence** (built what was asked, no more and no less) and **plan adherence** (followed the plan, or quietly diverged).
- Also looks for bugs, silent failures, security issues, risky files, and missing tests.
- Hands every finding to an independent skeptic that tries to disprove it against the real code. Only findings it can't disprove reach the report.
- Writes one review document. You read it and decide what to do; lens never decides for you.

## Commands

| Command | What it does |
|---|---|
| `/lens:review [target]` | Review the current change against its spec and plan. With no argument it reviews the working tree plus this branch's commits since the merge-base with the default branch. `target` replaces that scope with a path, a ref, or a range. |

> `engine` is an internal building block (`user-invocable: false`) — the data-only judgment core that `review` calls; you never invoke it directly.

> `render-review` is also internal — the pure HTML render entrypoint an orchestrator calls after `engine`; you never invoke it directly.

> `capability` is also internal — the compatibility gate an orchestrator calls to learn what this installation supports before it sends a review; you never invoke it directly.

## What it reads, writes, and sends

| | |
|---|---|
| **Reads** | The git diff in scope and the source around it; the spec and plan files that match the diff (or this session's conversation when there are none); `.claude/lens/settings.md`; `.claude/lens/review-state.json` from earlier reviews. |
| **Writes** | Only its own files: `.claude/lens/settings.md` (first run), the review document (default `.claude/lens/<YYYY-MM-DD-HHMM>-<slug>.html`, or `.md` without walkthrough; you can pick another folder on the first run), and `.claude/lens/review-state.json`. On the first run it offers to add `.claude/lens/` to `.gitignore`, and changes `.gitignore` only if you accept. It never edits, stages, or commits your code. |
| **Runs** | Six subagents. The five finders use Read, Grep, and Glob only. The `verifier` may also run inspection commands to test a finding: read-only git (`git diff`, `git log`, `git show`), search, and your project's typecheck or test command scoped to the changed code. A typecheck or test runs your project's own code. The verifier never installs packages or changes git state. If you have other review plugins installed, lens can use their agents as optional adapters, instructed to report findings only. |
| **Network** | None. lens makes no network calls and sends nothing anywhere. |
| **Changes to your Claude settings** | None. lens adds no hooks, permissions, or MCP servers. |

## Where it works

| Surface | Status | Why |
|---|---|---|
| Claude Code | ✓ | Built and tested here. |
| Cowork | Likely, untested | Skills and agents load in Cowork, but lens needs a git repository in the session. |
| claude.ai chat | ✗ | Chat doesn't load plugin agents, so the finders and the verifier never run, and there is no session git diff. |

## How it works

### The brain and the eyes

lens is the **brain** — it judges. [`walkthrough`](https://github.com/ApurvBazari/claude-plugins/tree/main/walkthrough) is the **eyes** — it renders. lens does the reasoning (scope, intent, analysis, verification) and produces a structured review model; it then hands that model to `walkthrough:render` to become a self-contained interactive HTML review document, in the same house style as every other walkthrough.

- **walkthrough present** → you get the full interactive HTML review (annotated diff hunks, an adherence panel, a findings list, an overall verdict).
- **walkthrough absent** → lens falls back to a self-contained **markdown report** with the same content. You just get a plainer artifact.

Neither plugin imports the other. lens checks for walkthrough at runtime and switches to the markdown report if it isn't installed.

### Optional adapters

If you have other review tooling installed (e.g. the `pr-review-toolkit` agents), lens can use it as an **optional adapter** — a second set of specialized finders feeding the same review. Adapters are detected at runtime and skipped silently when absent. Every adapter is held to the same findings-only contract as lens itself: an adapter can report, never edit, stage, commit, or block.

## Where files go

All lens state lives under `.claude/lens/`. On the first review in a repo, lens does a one-time setup:

- asks whether to add `.claude/lens/` to `.gitignore` (review artifacts can contain session content — gitignoring is the default offer), and
- asks for a default output path for rendered reviews.

Both choices persist to `.claude/lens/settings.md`, which also holds your **project-custom finder registry** (extra finders specific to this codebase). The rendered review is written under `.claude/lens/` by default, and `.claude/lens/review-state.json` records prior findings and their statuses so a re-review can show what's **fixed / still open / new** and the **severity trend** over time.

## What it is / isn't

**It is** an intent-grounded, in-session review companion. It reads the diff and the source, reconstructs what you were asked to build, verifies its own findings adversarially, and renders a review document for a human to act on.

**It is NOT:**

- **a diff-only linter** — the whole point is judging against spec and plan, not just the patch in isolation.
- **a CI gate** — lens runs in your session, on demand. It does not run in CI and does not gate merges.
- **anything that changes your code** — lens never commits, edits, stages, or blocks. It writes only its own files listed in [What it reads, writes, and sends](#what-it-reads-writes-and-sends). You read the review; you decide.

## License

[MIT](https://github.com/ApurvBazari/claude-plugins/blob/main/lens/LICENSE)
