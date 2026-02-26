# Best Practices

Practical guidance for combining plugins effectively.

## Install Order

Install plugins in this order so each layer builds on the previous:

1. **onboard** — Generates CLAUDE.md, rules, skills, hooks tailored to your project
2. **devkit** — Detects your tooling and writes `.claude/devkit.json` config
3. **notify** — Configures notification hooks (works with devkit's ship pipeline)
4. **Official companions** — Add as needed (see [recommended-stack.md](./recommended-stack.md))

**Why this order?** onboard's analysis informs everything downstream. devkit needs the project to be set up before it can detect tooling. notify is independent but benefits from devkit being configured first (ship pipeline notifications).

## onboard + claude-md-management

onboard bootstraps your Claude tooling; claude-md-management maintains it over time.

**Handoff workflow:**

1. Run `/onboard:init` — generates CLAUDE.md files, rules, skills, hooks
2. Install `claude-md-management`
3. Use its quality scoring periodically to audit onboard-generated files
4. Run `/revise-claude-md` at end of sessions to capture learnings
5. When your project evolves significantly, run `/onboard:update` to realign with latest practices

onboard handles the big-picture generation. claude-md-management handles the incremental drift.

## onboard + hookify

These plugins coexist without conflict:

- **onboard** writes hooks to `settings.json` at setup time (formatters, linters)
- **hookify** reads `.claude/hookify.*.local.md` files for behavioral rules post-setup

Use onboard for the initial hook configuration. Use hookify when you want to add project-specific behavioral rules on-the-fly (e.g., "warn on console.log in production code") without re-running onboard.

## Choosing a Review Tool

### devkit:review vs code-review vs pr-review-toolkit

```
What do you need?
│
├─ Local review before committing?
│  └─ Use devkit:review
│     (runs locally, multi-category, integrated with ship pipeline)
│
├─ Async PR comments for your team?
│  └─ Use code-review
│     (posts comments on PRs, team-facing, async)
│
└─ Deep, specialist-level review before merge?
   └─ Use pr-review-toolkit
      (multiple focused agents: security, performance, correctness)
```

These are complementary, not competing. A typical flow:

1. `/devkit:review` — quick local check during development
2. `/devkit:ship` — quality gates + commit
3. `/devkit:pr` — create the PR
4. `code-review` or `pr-review-toolkit` — async review on the PR

### devkit:check vs pr-review-toolkit specialists

```
What are you checking?
│
├─ Pre-commit production readiness?
│  └─ Use devkit:check
│     (debug artifacts, security basics, performance, quality)
│
└─ Deep domain-specific analysis on a PR?
   └─ Use pr-review-toolkit specialists
      (dedicated agents for security, performance, correctness)
```

`devkit:check` is broad and fast — it catches common issues before committing. pr-review-toolkit's specialists go deeper in specific domains during PR review.

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────┐
│                   Development Lifecycle                   │
├─────────┬───────────┬───────────┬───────────┬───────────┤
│  SETUP  │  DEVELOP  │   SHIP    │  REVIEW   │  MONITOR  │
│         │           │           │           │           │
│ onboard │ feature-  │ devkit:   │ code-     │ notify    │
│   +     │   dev     │  ship     │  review   │           │
│ hookify │           │  test     │    or     │           │
│         │           │  lint     │ pr-review │           │
│         │           │  check    │  toolkit  │           │
│         │           │  commit   │           │           │
│         │           │  pr       │           │           │
└─────────┴───────────┴───────────┴───────────┴───────────┘
     │           │           │           │           │
     ▼           ▼           ▼           ▼           ▼
  Bootstrap   Implement   Quality    Async PR    Get notified
  tooling     features    gates +    feedback    on completion
                          commit
```
