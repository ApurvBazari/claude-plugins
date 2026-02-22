# CLAUDE.md Best Practices Guide

CLAUDE.md is the primary way to give Claude persistent context about a project. It's loaded automatically when Claude works in a directory.

---

## File Hierarchy

```
project-root/
├── CLAUDE.md                    # Root — always loaded, project-wide context
├── src/
│   ├── frontend/
│   │   └── CLAUDE.md            # Loaded when working in src/frontend/
│   └── api/
│       └── CLAUDE.md            # Loaded when working in src/api/
└── packages/
    ├── core/
    │   └── CLAUDE.md            # Per-package context in monorepos
    └── web/
        └── CLAUDE.md
```

**Loading behavior**: Claude reads the CLAUDE.md in the current directory plus all parent CLAUDE.md files up to the project root. Subdirectory files add context; they don't replace parent context.

## Root CLAUDE.md Structure

### Recommended Sections (in order)

```markdown
# Project Name

Brief 1-2 sentence description of what this project does.

## Tech Stack

- Language: TypeScript 5.x
- Framework: Next.js 14 (App Router)
- Database: PostgreSQL via Prisma ORM
- Testing: Vitest + React Testing Library
- Styling: Tailwind CSS
- Deployment: Vercel

## Commands

### Development
- `npm run dev` — Start development server
- `npm run build` — Production build
- `npm run start` — Start production server

### Testing
- `npm test` — Run all tests
- `npm run test:watch` — Run tests in watch mode
- `npm run test:coverage` — Run tests with coverage
- `npm run test -- path/to/file` — Run a single test file

### Linting & Formatting
- `npm run lint` — ESLint check
- `npm run lint:fix` — ESLint auto-fix
- `npm run format` — Prettier format

### Database
- `npx prisma generate` — Generate Prisma client
- `npx prisma migrate dev` — Run migrations
- `npx prisma studio` — Open database browser

## Project Structure

```
src/
├── app/           # Next.js App Router pages and layouts
├── components/    # Shared React components
├── lib/           # Utility functions and shared logic
├── server/        # Server-side code (API routes, actions)
└── types/         # TypeScript type definitions
```

## Key Conventions

- Use functional React components with hooks (no class components)
- Prefer named exports over default exports
- Use absolute imports from `@/` prefix
- Error handling: use Result pattern for expected errors, throw for unexpected
- All API routes validate input with Zod schemas

## Critical Rules

- NEVER commit .env files or secrets
- Always run tests before pushing
- Database migrations must be reviewed before merging
- Do not modify generated Prisma client files
```

## Writing Guidelines

### Do
- **Be specific** — "Use Vitest for testing" not "Use the testing framework"
- **Include exact commands** — Developers and Claude both benefit from copy-pasteable commands
- **Document the "why"** — "We use barrel exports in components/ for cleaner imports"
- **List what NOT to do** — Negative rules prevent common mistakes
- **Keep it current** — Outdated CLAUDE.md is worse than no CLAUDE.md

### Don't
- **Don't duplicate README** — CLAUDE.md is for Claude's working context, not project documentation
- **Don't list every file** — Describe patterns, not inventories
- **Don't over-specify** — Trust Claude's judgment for standard patterns
- **Don't include boilerplate** — Every line should earn its place
- **Don't make it too long** — 100-200 lines for root. Claude reads this every session.

## @import Directive

Use `@import` to reference other files that Claude should read:

```markdown
@import src/frontend/CLAUDE.md
@import .claude/rules/testing.md
```

Use sparingly — only for files that should always be loaded with the root context.

## Subdirectory CLAUDE.md Guidelines

- **Only create when the directory has distinct conventions** not covered by root
- **Keep short** — 30-80 lines
- **Don't repeat root content** — Only add what's specific to this directory
- **Focus on patterns** — What files look like here, what conventions apply here

Example subdirectory CLAUDE.md:
```markdown
# Components Directory

Components follow this structure:
- One component per file, named `ComponentName.tsx`
- Co-located test file: `ComponentName.test.tsx`
- Co-located styles (if needed): `ComponentName.module.css`

## Conventions
- All components are functional with TypeScript props interface
- Props interface named `{ComponentName}Props`
- Use `forwardRef` for components that accept refs
- Accessibility: all interactive elements need aria labels
```

## Tone by Autonomy Level

### "Always Ask" Autonomy
```markdown
- Before modifying any shared utility, check with the developer
- When unsure about a pattern, ask before implementing
- Present options for architectural decisions rather than choosing
```

### "Balanced" Autonomy (default)
```markdown
- For small changes, follow established patterns and proceed
- For architectural decisions or changes affecting multiple files, discuss first
- Use judgment on when to ask vs. act
```

### "Autonomous" Autonomy
```markdown
- Follow established patterns and conventions proactively
- Make implementation decisions based on codebase conventions
- Only ask when genuinely ambiguous or potentially destructive
```
