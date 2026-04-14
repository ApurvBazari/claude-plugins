---
name: scaffolding
description: Forge Phase 2 — executes the project scaffold (CLI, from-scratch, template, or walking-skeleton), sets up git, runs hello-world verification. Internal building block invoked by forge init — not user-invocable.
user-invocable: false
---

# Scaffolding Skill — Project Setup & Git Configuration

You are executing Phase 2 of Forge: scaffolding the application and setting up git infrastructure. All decisions were made during Phase 1 (context gathering). This phase is execution, not discussion.

## Purpose

Create a running application from the context gathered in Phase 1. Set up git branching, push to remote, configure branch protection, and verify the Hello World runs.

## Inputs

You receive the complete Phase 1 context object containing: stack details, scaffold method, deploy target, branching strategy, and all project preferences. You also receive the stack research findings.

## Step 1: Pre-Scaffold Validation

Before creating any files:

1. **Verify target directory** — Check if the current directory is empty. If not, ask the developer: overwrite, pick a different directory, or abort.
2. **Check required CLIs** — Run the bundled detector script to enumerate all available scaffold CLIs on the system:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/detect-scaffold-cli.sh"
   ```

   The script emits section headers (`## Available Scaffold CLIs`, `### Package Managers`, `### Runtimes`, `### Scaffold Tools`, `### Container Tools`, `### Version Control`) and a line per available tool with its version. Parse the output and verify the stack's required CLIs are listed:

   - Node.js projects: `node`, at least one of `npm`/`pnpm`/`yarn`/`bun`
   - Python projects: `python3`, at least one of `pip`/`poetry`/`uv`
   - Go projects: `go`
   - Rust projects: `cargo`
   - Ruby projects: `ruby` + `gem`

   If a required CLI is missing from the detector output, show the appropriate install command and wait for the developer to install it before proceeding. Do not attempt to scaffold with missing prerequisites.

3. **Check git** — The detector script includes git under `### Version Control`. Verify it's present; if missing, halt and tell the developer git is required for repo setup.

## Step 1.5: Sibling Project Detection

Before scaffolding, check the parent directory for similar existing projects that could serve as version anchors. This is particularly valuable for experimental stacks where fresh research may differ from what the developer has already standardized on in their own ecosystem.

**Detection protocol**:

1. `ls` the parent directory of the target scaffold location
2. For each sibling directory:
   - Check for a manifest file matching the current stack:
     - `package.json` (JavaScript/TypeScript)
     - `pyproject.toml` / `setup.py` / `requirements.txt` (Python)
     - `go.mod` (Go)
     - `Cargo.toml` (Rust)
     - `build.gradle(.kts)` (JVM: Kotlin, Android)
     - `Package.swift` (Swift)
     - `Gemfile` (Ruby)
   - If found, read the manifest and extract: dependencies, version, framework identity
3. If any sibling project matches the target stack family, offer to anchor to it:

   > I noticed `../[sibling-name]` is also a [framework] project. Should I anchor to its versions and conventions? This would:
   > - Pin the same framework version (e.g., [specific version from sibling])
   > - Use the same build tool versions
   > - Match its directory structure conventions
   > - Reduce cognitive load when working across your projects
   >
   > The alternative is to use fresh research-informed versions from the `stack-researcher` agent, which may differ from the sibling.

   Use `AskUserQuestion` with options: **Anchor to sibling** (recommended if confidence is high), **Use fresh research**, **Compare both and pick**.

4. If the developer anchors to a sibling:
   - Store `anchorProject: "../sibling-name"` in the context
   - Read specific versions from the sibling's manifest
   - Override the stack-researcher's version pins with the anchor's versions
   - Note the anchor in `forge-meta.json` for future reference

5. If no siblings are found, proceed normally.

**Why this matters**: during the jamakhata session that produced this feature, the sibling `notifyguard` project was the version anchor for Gradle, Kotlin, Hilt, Room, and Compose — saving hours of research and ensuring consistency across the developer's own projects. Without sibling detection, the user would have had to manually tell us about `notifyguard`.

**Limits**: do NOT anchor to sibling projects that are very old (check `git log` for recent activity), that use conflicting styles, or that the developer explicitly says are experiments they don't want to replicate. When in doubt, ask.

## Step 2: Execute Scaffold

Based on the `scaffoldMethod` from Phase 1 **and** the `scaffoldMode` (`full` vs `walking-skeleton`):

- `scaffoldMode === "full"` → use Path A, B, or C as defined below, producing a complete runnable scaffold
- `scaffoldMode === "walking-skeleton"` → use **Path D** (walking skeleton) regardless of what `scaffoldMethod` says; control returns to `/forge:init` after Path D completes, which then runs Phase 3 (AI tooling) against the walking skeleton BEFORE a second scaffold expansion in Phase 2b

### Path A: External CLI Scaffold

Construct the CLI command from Phase 1 context + stack research:
- Use the exact CLI and flags identified by the stack-researcher
- Pin to the latest stable version from research
- Include all options selected during Phase 1 (TypeScript, styling, linting, etc.)

Run the command and stream output. If it fails:
- Show the error and diagnose the cause
- Offer to retry with different flags, or switch to Path B (from scratch)
- Do NOT clean up partial files — leave them for the developer to inspect

### Path B: From Scratch

Create the project structure manually following the research findings:
1. Write the package manifest (package.json, pyproject.toml, Cargo.toml, go.mod)
2. Write configuration files (tsconfig, eslint, prettier, etc.) using research-informed defaults
3. Create the directory structure following the framework's recommended layout
4. Write a minimal entry point and Hello World (route, page, handler, main function)
5. Install dependencies

### Path C: Developer's Template

Clone or copy the developer's specified template/boilerplate:
1. If URL: `git clone [url] .` or `degit [url]`
2. If local path: copy files
3. Install dependencies
4. Verify the structure looks reasonable

### Path D: Walking Skeleton

This path scaffolds ONLY one representative example of each architectural pattern — not a complete app. The goal is to give forge's AI-tooling phase (Phase 3) enough concrete patterns to derive project-specific CLAUDE.md, rules, and hooks from, without investing in full features yet.

**When Path D is used**: only when `scaffoldMode === "walking-skeleton"` (set in Phase 1 Step 3). Do NOT default to Path D for any stack.

**What "one representative of each" means** — the exact list depends on the stack and `appType`, but always include:

- Build/toolchain wiring (Gradle, `package.json`, `pyproject.toml`, `Cargo.toml`, etc.) — complete and buildable
- Dependency injection or module system wiring — minimal but real
- **One** entity / data model / schema type (not all entities the user described — just one representative one)
- **One** DAO / repository / data access layer file — wired to the single entity
- **One** service / use case / business logic file — using the single entity
- **One** route / screen / endpoint / command — the user-facing entry to the single feature
- **One** test file — showing the test pattern for this stack
- Empty stubs for all the other architectural directories that will be filled later (e.g., empty `entities/` directory with a README explaining its purpose), so the file system structure is visible to onboard's scanner
- A `README.md` at the project root that documents:
  - The intended full architecture (directories, layer responsibilities)
  - The fact that this is a walking skeleton and `TODO: expand in Phase 2b`
  - How to run the single demo feature end-to-end

**Walking-skeleton contract**: the resulting project must
1. Build successfully
2. Run the single demo feature end-to-end
3. Have one passing test
4. NOT have any features beyond the single demo

Anything more than the minimum defeats the purpose — onboard should derive rules from **patterns**, not from thirty concrete implementations that might be subtly inconsistent.

**Stack-specific guidance**:

- **Next.js App Router**: one route handler, one server component, one client component, one data fetcher, one test. Prisma: one model, one migration, one query wrapper.
- **FastAPI**: one Pydantic model, one SQLAlchemy model, one repository, one service, one route, one pytest.
- **Android Kotlin/Compose**: one Room entity, one DAO, one repository, one ViewModel, one Composable screen, one Hilt module, one instrumented test, one unit test. Gradle + Hilt + Room + Compose fully wired.
- **iOS SwiftUI**: one Model, one ViewModel, one View, one service, one unit test.
- **Go HTTP service**: one handler, one repository, one service, one test, `go.mod` complete.
- **Custom stack**: research the recommended architecture (via stack-researcher) and produce one of each layer identified in the research report.

If the stack isn't on this list and research doesn't give you clear guidance, ask the user: "I'm not sure what a walking skeleton looks like for [stack]. Can you describe the architectural layers your app will have (e.g., data, business, presentation)? I'll create one of each." Then capture the answer and proceed.

**After Path D completes**, return control to `/forge:init`. It will run Phase 3 (AI tooling) against the walking skeleton. Phase 3 will generate CLAUDE.md + rules + hooks from the observed patterns. Then the flow enters **Phase 2b: Expand scaffold under AI-tooling guidance** — a second pass through this skill that uses the generated rules to expand the walking skeleton into a fuller scaffold, with each expansion respecting the AI tooling's conventions.

## Step 3: Post-Scaffold Additions

Regardless of scaffold path, add these based on Phase 1 context:

1. **`.env.example`** — Placeholder keys for database, auth, storage, monitoring, API integrations. Each key has a comment explaining what it's for.
2. **`.env.local`** — Copy of .env.example (gitignored, developer fills in real values)
3. **`.gitignore`** — If not already present, create with standard patterns for the stack plus: `.env*` (except .env.example), `node_modules/`, build dirs, OS files, `.claude/settings.local.json`
4. **Docker** (if `dockerStrategy` ≠ "none"):
   - `Dockerfile` — Multi-stage build for the detected stack
   - `docker-compose.yml` — Dev services (app + database if selected)
   - `.dockerignore`
5. **Monorepo** (if `isMonorepo`): Configure workspace root (turborepo.json, pnpm-workspace.yaml, etc.)
6. **i18n** (if `i18n` ≠ "no"): Create locale directory structure and base config
7. **Code generation** (if `codegenTools` has entries): Install tools, add generate scripts
8. **Storage** (if `storageStrategy` ≠ "none"): Add storage utility module with placeholder config

## Step 4: Git Setup

1. **Initialize**: `git init` (if not already a git repo)
2. **Initial commit**: `git add -A && git commit -m "feat: scaffold [app name] with [stack]"`
3. **Create branches** based on `branchingStrategy`:
   - Simple: just `main` (already on it)
   - Gitflow-lite: `git checkout -b develop && git checkout main`
   - Trunk-based: just `main`
4. **Remote setup** (if developer wants):
   - Ask if they have a GitHub repo or want to create one
   - If creating: `gh repo create [name] --public/--private --source=. --push`
   - If existing: `git remote add origin [url] && git push -u origin main`
   - Push develop branch too if gitflow-lite
5. **Branch protection** (if remote exists):
   - Configure via `gh api` — require PR reviews, require CI checks to pass, prevent force-push
   - Adapt rules to branching strategy

## Step 5: Verify Hello World

1. Detect the dev server command from the scaffold output (npm run dev, python main.py, cargo run, etc.)
2. Start the dev server in the background
3. Wait for it to be ready (poll the port or health endpoint, timeout after 30s)
4. Report success: "Your app is running at http://localhost:[port]"
5. Stop the dev server
6. If it fails: report the error but don't block — continue to Phase 3

## Step 6: Save Metadata

Write `.claude/forge-meta.json`:

```json
{
  "version": "1.0.0",
  "createdAt": "[timestamp]",
  "context": {
    "appDescription": "...",
    "stack": { "framework": "...", "version": "...", ... },
    "scaffoldMethod": "...",
    "teamSize": "...",
    "deployTarget": "...",
    "branchingStrategy": "...",
    "testingPhilosophy": "...",
    "autonomyLevel": "...",
    "securitySensitivity": "...",
    "ciAuditAction": "...",
    "autoEvolutionMode": "..."
  },
  "generated": {
    "scaffold": ["list of files created"],
    "git": {
      "branches": ["main", "develop"],
      "remote": "github.com/...",
      "protectionConfigured": true
    }
  },
  "webResearch": {
    "stackVersion": "...",
    "researchedAt": "[timestamp]",
    "sources": ["url1", "url2"]
  }
}
```

## Checkpoint Protocol (for resume support)

This skill MUST write `.claude/forge-state.json` after each Step so `/forge:resume` can pick up mid-scaffold if the session is interrupted. See `skills/init/SKILL.md` for the full state schema.

### When to checkpoint

| After Step | Write to state file |
|---|---|
| Step 1 (Pre-Scaffold Validation) | `completedSteps: [..., "scaffold-validation"]`, `currentStep: "scaffold-execute"` |
| Step 2 (Execute Scaffold) | Add `"scaffold-execute"`, `currentStep: "scaffold-post"`, `generated.scaffold: [file list]` |
| Step 3 (Post-Scaffold Additions) | Add `"scaffold-post"`, `currentStep: "scaffold-git"` |
| Step 4 (Git Setup) | Add `"scaffold-git"`, `currentStep: "scaffold-verify"`, `generated.git: {...}` |
| Step 5 (Verify Hello World) | Add `"scaffold-verify"`, `currentStep: "scaffold-metadata"` |
| Step 6 (Save Metadata) | Add `"scaffold-metadata"`, `currentPhase: "phase-3a-plugin-discovery"`, `currentStep: "catalog-match"` (handoff to plugin-discovery) |

### Atomic write
Same protocol as context-gathering: write to `.claude/forge-state.json.tmp`, then `mv` to `.claude/forge-state.json`.

### Resume entry contract
When invoked via `/forge:resume`, check `completedSteps` and skip anything already done. **Critical**: Steps 2 and 4 are destructive (write files, init git). If they're already complete, do NOT re-run them — resume from the next step. If `completedSteps` says `scaffold-execute` is done but the scaffold directory is empty, abort with an error: the state file and filesystem have diverged, and the user must manually resolve before continuing.

### Interruption during destructive steps
If the session is killed mid-scaffold (e.g., during `npm install`), the next resume will see `scaffold-execute` as NOT complete. The user is told:

> The scaffold was interrupted mid-execution. Files may be in an inconsistent state. Options:
> 1. Inspect the files and decide whether to continue (fast-forward) or restart
> 2. Delete the partial scaffold and let me retry cleanly
> 3. Abort the whole forge session

Never auto-clean. Always ask.

## Key Rules

1. **Never guess CLI flags** — Use only flags confirmed by web research.
2. **Leave partial on failure** — Do not auto-clean partial scaffold. Let the developer inspect.
3. **Git safety** — Never force-push. Never delete branches. Ask before any destructive git operation.
4. **Verify before moving on** — Confirm Hello World runs (or acknowledge failure) before declaring Phase 2 complete.
5. **Research-informed defaults** — Every config file should use values from web research, not stale training data.
6. **Checkpoint after every Step** — Always write `forge-state.json` at Step boundaries so resume works.
