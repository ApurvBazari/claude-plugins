# Lifecycle Setup Skill — Engineering Document Generation

You are executing Phase 4 of Forge: generating engineering lifecycle documents by delegating to the `engineering` plugin's skills. This phase is entirely optional — if the developer skips all documents or the engineering plugin is not installed, proceed directly to Handoff.

## Guard: engineering prerequisite

The `engineering` plugin is **optional** for Phase 4. It lives in a different marketplace (`knowledge-work-plugins`), so probe its common install locations first, then fall back to asking the developer if detection is inconclusive.

### Step 1: Detect

Try the filesystem probe. The engineering plugin may be installed as a sibling of forge (same marketplace parent) or under a separate marketplace directory one level up:

```bash
ls "${CLAUDE_PLUGIN_ROOT}/../engineering" 2>/dev/null || \
ls "${CLAUDE_PLUGIN_ROOT}/../../engineering" 2>/dev/null
```

**If either probe finds the directory**, treat engineering as installed and proceed to Step 1 of the main skill flow.

**If both probes fail**, the engineering plugin is either missing or installed somewhere we can't detect automatically (e.g., a user-local path). Ask the developer with AskUserQuestion:

> I couldn't auto-detect the **engineering** plugin (it lives in the separate `knowledge-work-plugins` marketplace, so location varies).
>
> Is it already installed and available?

Options:
- **Yes, it's installed** — treat as present, proceed to Step 1
- **No, install it now (Recommended)** — go to Step 2 below
- **Skip Phase 4** — proceed directly to Handoff

### Step 2: Offer inline install (when confirmed missing)

Tell the developer what engineering does, where it lives, and offer install:

> The **engineering** plugin is an optional Anthropic-official plugin that generates project-specific engineering documents — Architecture Decision Records, testing strategies, deploy checklists, system designs, runbooks, and incident playbooks — using the context we gathered in Phase 1.
>
> It lives in the **`knowledge-work-plugins`** marketplace (separate from Apurv Bazari's plugins), so you may need to add the marketplace first:
>
> ```
> claude marketplace add knowledge-work-plugins
> claude plugin install engineering
> ```
>
> Install it now, or skip Phase 4 and install later?

Use AskUserQuestion with options: **Install now (Recommended)**, **Skip Phase 4**.

When the developer chooses "Install now", run both commands in sequence via the Bash tool:

```bash
claude marketplace add knowledge-work-plugins 2>&1 && claude plugin install engineering
```

If the marketplace is already added, the first command is a no-op and the second still succeeds.

### Step 3: Handle install outcome

**If the developer installs:**
1. Run `claude plugin install engineering` via the Bash tool.
2. Re-run the detection probes from Step 1.
3. **On success** — proceed to Step 1 of the main skill flow. If engineering's slash commands aren't immediately available in this session, tell the developer: "Engineering is installed, but its skills may not be available until you restart the session. If the first `engineering:*` skill invocation fails, restart Claude Code and rerun `/forge:init` Phase 4 manually."
4. **On install failure** — surface the underlying error verbatim (common causes: `knowledge-work-plugins` marketplace not added, network issue, auth). Then skip Phase 4 gracefully and proceed directly to Handoff. Do not block the rest of the flow — Phase 4 is optional.

**If the developer skips** (explicitly declines install, or says "no" to the detection question):

Proceed directly to Handoff — do not present the lifecycle menu. Tell the developer: "Skipping Phase 4. You can install engineering later with `claude plugin install engineering` and run `/engineering:architecture`, `/engineering:testing-strategy`, etc. directly on this project."

---

## Inputs

You receive:
1. The complete Phase 1 context object (from context-gathering skill)
2. Phase 2 scaffold metadata (from `.claude/forge-meta.json`)
3. Phase 3 installed plugins list and generated tooling summary

---

## Step 1: Present Lifecycle Menu

Build a checklist of engineering documents to generate. Use context intelligence to determine which documents to recommend:

| Document | Engineering Skill | Recommend when | Default |
|---|---|---|---|
| Architecture Decision Record | `engineering:architecture` | Always | Checked |
| Testing Strategy | `engineering:testing-strategy` | Always | Checked |
| Deploy Checklist | `engineering:deploy-checklist` | `willDeploy = true` | Checked if deploying |
| System Design Document | `engineering:system-design` | `appType` is `web-app`, `api`, or `fullstack`, OR project has 3+ services | Checked if matches |
| Technical Runbook | `engineering:documentation` | Always | Checked |
| Incident Response Playbook | `engineering:incident-response` | `isProduction = true` AND `securitySensitivity != "standard"` | Checked if matches |

Present the menu using the AskUserQuestion tool with `multiSelect: true`:

> **Phase 4: Engineering Documents**
>
> Based on your project context, I recommend generating these engineering documents.
> Each one is produced by the `engineering` plugin using the details we gathered earlier.
>
> Select which documents to generate (or deselect all to skip):

For each document, show:
- Name
- One-line description
- Why it's recommended (e.g., "[deploying to Vercel]", "[production app with elevated security]")

If the developer deselects all items, inform them:

> Skipping engineering documents. You can generate them later by installing the engineering
> plugin and running the individual skills (e.g., `/engineering:architecture`).

Proceed directly to Handoff.

---

## Step 2: Generate Documents Sequentially

For each selected document, follow this process:

### 2a. Compose Context Argument

Read `references/context-mapping.md` and compose the natural language argument for the engineering skill. Map Phase 1 context fields to the argument template for the selected document type.

Key rules for argument composition:
- Only include fields that have values — skip missing fields rather than saying "not specified"
- Use `webResearch` findings to enrich the Architecture ADR with trade-offs
- Keep arguments specific to the project — the engineering skill generalizes from there

### 2b. Invoke Engineering Skill

Invoke via the Skill tool:

```
Skill(engineering:<skill-name>, args: "<composed context argument>")
```

The engineering skill will produce markdown output in the conversation.

### 2c. Capture and Save Output

After the engineering skill completes, capture its output and write it to the project's `docs/engineering/` directory.

Create the `docs/engineering/` directory if it doesn't exist.

**File naming convention:**

| Document | Filename |
|---|---|
| Architecture Decision Record | `adr-001-tech-stack.md` |
| Testing Strategy | `testing-strategy.md` |
| Deploy Checklist | `deploy-checklist.md` |
| System Design Document | `system-design.md` |
| Technical Runbook | `runbook.md` |
| Incident Response Playbook | `incident-playbook.md` |

### 2d. Report Progress

After each document is saved, briefly confirm:

> Generated `docs/engineering/<filename>` via `engineering:<skill-name>`.

If a document generation fails (skill error, unexpected output), log the error and continue with the next document:

> Could not generate [document name]: [brief error]. Continuing with remaining documents.
> You can retry later with `/engineering:<skill-name>`.

---

## Step 3: Update CLAUDE.md

After all selected documents are generated, append an "Engineering Documents" section to the project's root CLAUDE.md:

```markdown
## Engineering Documents

Project engineering documents generated during setup, stored in `docs/engineering/`:

| Document | Path | Generated by |
|---|---|---|
| Architecture Decision Record | `docs/engineering/adr-001-tech-stack.md` | `engineering:architecture` |
| Testing Strategy | `docs/engineering/testing-strategy.md` | `engineering:testing-strategy` |
| [etc.] | | |

These documents capture decisions and strategies from project inception. Update them as
the project evolves — they serve as living references, not frozen snapshots.
```

Only list documents that were actually generated (not skipped or failed).

---

## Step 4: Update forge-meta.json

Read the existing `.claude/forge-meta.json` and add a `lifecycleDocuments` array:

```json
{
  "lifecycleDocuments": [
    {
      "type": "adr",
      "path": "docs/engineering/adr-001-tech-stack.md",
      "skill": "engineering:architecture",
      "generatedAt": "2026-04-09T..."
    },
    {
      "type": "testing-strategy",
      "path": "docs/engineering/testing-strategy.md",
      "skill": "engineering:testing-strategy",
      "generatedAt": "2026-04-09T..."
    }
  ]
}
```

Only include documents that were successfully generated.

---

## Key Rules

- **Phase 4 is entirely optional.** If the user skips all documents, proceed to Handoff with no penalty.
- **Never block Phase 3 completion.** Phase 4 runs AFTER all AI tooling is generated and verified.
- **Each document generation is independent.** If one fails, continue with the rest. Never abort the entire phase for a single failure.
- **Pass Phase 1 context faithfully.** Do not invent details the user didn't provide. If a field is missing, omit it from the argument rather than fabricating a value.
- **The engineering plugin does the work.** This skill is purely orchestration and context mapping. Do not duplicate or override what the engineering skills produce.
- **Respect the docs/engineering/ convention.** All lifecycle documents go in this subdirectory, never at the project root or in other locations.
- **Use ISO 8601 timestamps** in forge-meta.json entries.
