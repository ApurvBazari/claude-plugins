# Evolve Skill — Apply Pending Drift Updates

You are applying accumulated tooling drift updates. The FileChanged hooks have been logging changes to `.claude/forge-drift.json`, and now you apply the corresponding updates to CLAUDE.md, rules, and skills.

## Guard

Read `.claude/forge-drift.json` in the project root. If not found or empty:

> No pending drift detected. Your AI tooling is in sync with your codebase.

Stop and do not proceed.

## Step 1: Read Drift Entries

Parse `.claude/forge-drift.json` and categorize entries:

- **Dependency changes**: new packages added, packages removed, scripts added/removed
- **Config changes**: tsconfig, eslint, prettier settings changed
- **Structural changes**: new directories with source files, removed directories

Present a summary:

> **Pending tooling updates:**
>
> **Dependencies** ([N] changes)
> - Added: [package1], [package2]
> - Removed: [package3]
> - New scripts: [script1]
>
> **Config** ([N] changes)
> - tsconfig: strict mode enabled
> - eslint: added [rule]
>
> **Structure** ([N] changes)
> - New directory: src/services/ (3 files)
>
> I'll update your CLAUDE.md, rules, and skills to reflect these changes.

## Step 2: Apply Updates

For each category of drift:

### Dependency Changes
- **New packages**: Add to CLAUDE.md dependencies section. If the package is a major tool (testing framework, ORM, auth library), consider adding a corresponding rule or updating existing rules.
- **Removed packages**: Remove from CLAUDE.md. Remove any rules that reference the removed package.
- **New scripts**: Add to CLAUDE.md commands section with a description.
- **Removed scripts**: Remove from CLAUDE.md commands section.

### Config Changes
- **tsconfig changes**: Update TypeScript-related rules to match new settings.
- **ESLint changes**: Update code style rules to match new linting config.
- **Prettier changes**: Update formatting conventions in CLAUDE.md.

### Structural Changes
- **New directories**: If the directory has >5 source files and represents an architectural boundary, suggest creating a subdirectory CLAUDE.md. Ask the developer before creating it.
- **Removed directories**: Remove any subdirectory CLAUDE.md that references a deleted directory. Update path-scoped rules.

## Step 3: Show Diff

After applying updates, show what changed:

> **Updates applied:**
>
> - CLAUDE.md: Added `zod` to dependencies, added `npm run e2e` to commands
> - .claude/rules/typescript.md: Updated for strict mode
> - Suggested: Create src/services/CLAUDE.md for new service layer
>
> **Not auto-applied** (needs your input):
> - New directory src/services/ — want me to create a CLAUDE.md for it?

## Step 4: Clear Processed Entries

After updates are applied:
1. Update `lastAuditedAt` in forge-drift.json to current timestamp
2. Clear the processed entries from the `entries` array
3. Keep any entries that were NOT processed (e.g., structural changes that need developer input)

## Key Rules

1. **Read before writing** — Always read the current state of CLAUDE.md and rules before making changes.
2. **Surgical updates** — Only change the specific sections affected by the drift. Don't rewrite entire files.
3. **Ask for structural** — Dependency and config changes can be auto-applied. Structural changes (new CLAUDE.md files) require developer confirmation.
4. **Preserve manual edits** — If the developer has customized CLAUDE.md beyond what onboard generated, preserve those customizations.
5. **Show the diff** — Always show what was changed so the developer can verify.
