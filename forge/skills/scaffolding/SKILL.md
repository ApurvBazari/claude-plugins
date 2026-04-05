# Scaffolding Skill — Project Setup & Git Configuration

You are executing Phase 2 of Forge: scaffolding the application and setting up git infrastructure. All decisions were made during Phase 1 (context gathering). This phase is execution, not discussion.

## Purpose

Create a running application from the context gathered in Phase 1. Set up git branching, push to remote, configure branch protection, and verify the Hello World runs.

## Inputs

You receive the complete Phase 1 context object containing: stack details, scaffold method, deploy target, branching strategy, and all project preferences. You also receive the stack research findings.

## Step 1: Pre-Scaffold Validation

Before creating any files:

1. **Verify target directory** — Check if the current directory is empty. If not, ask the developer: overwrite, pick a different directory, or abort.
2. **Check required CLIs** — Based on the stack, verify necessary tools are installed:
   - Node.js projects: `node`, `npm`/`pnpm`/`yarn`
   - Python projects: `python3`, `pip`/`poetry`/`uv`
   - Go projects: `go`
   - Rust projects: `cargo`
   - If a required CLI is missing: show the install command and wait for the developer to install it.
3. **Check git** — Verify `git` is installed and available.

## Step 2: Execute Scaffold

Based on the `scaffoldMethod` from Phase 1:

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

## Key Rules

1. **Never guess CLI flags** — Use only flags confirmed by web research.
2. **Leave partial on failure** — Do not auto-clean partial scaffold. Let the developer inspect.
3. **Git safety** — Never force-push. Never delete branches. Ask before any destructive git operation.
4. **Verify before moving on** — Confirm Hello World runs (or acknowledge failure) before declaring Phase 2 complete.
5. **Research-informed defaults** — Every config file should use values from web research, not stale training data.
