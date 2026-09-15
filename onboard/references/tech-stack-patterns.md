# Tech Stack → Optimal Configuration Patterns

This reference maps commonly detected technology stacks to the optimal Claude tooling configuration for each. Use these patterns when generating artifacts in the generation phase.

---

## JavaScript / TypeScript (General)

**CLAUDE.md emphasis**: TypeScript strictness level, module system (ESM vs CJS), import conventions
**Rules**: Linting rules alignment, type safety rules
**Skills**: Refactoring skill if large codebase
**Hooks**: ESLint on Edit, Prettier on Write (if detected)

---

## React

**Indicators**: `react`, `react-dom` in dependencies
**CLAUDE.md emphasis**: Component patterns (functional only, no class components), hooks conventions, prop patterns
**Subdirectory CLAUDE.md**: `src/components/`, `src/hooks/`, `src/pages/` or `src/app/`
**Rules**:
- Component rules: naming conventions, file structure, prop types
- Hook rules: custom hook patterns, dependency arrays
- Testing rules: React Testing Library patterns, what to test
**Skills**: React component creation skill, hook creation skill
**Agents**: Component reviewer (checks accessibility, performance patterns)

### Next.js (extends React)
**Additional indicators**: `next` in dependencies, `next.config.*`
**CLAUDE.md additions**: App Router vs Pages Router, server components vs client components, data fetching patterns
**Subdirectory CLAUDE.md**: `app/` or `pages/`, `src/lib/`, `src/api/`
**Additional rules**: Server component rules, API route rules, middleware rules

### Remix (extends React)
**Additional indicators**: `@remix-run/*` in dependencies
**CLAUDE.md additions**: Loader/action patterns, nested routing, form handling

---

## Vue.js

**Indicators**: `vue` in dependencies
**CLAUDE.md emphasis**: Composition API vs Options API, component naming, single-file component structure
**Rules**: Component rules, composable rules, store rules (Pinia/Vuex)

### Nuxt (extends Vue)
**Additional indicators**: `nuxt` in dependencies
**CLAUDE.md additions**: Auto-imports, server routes, composables directory

---

## Svelte / SvelteKit

**Indicators**: `svelte`, `@sveltejs/kit` in dependencies
**CLAUDE.md emphasis**: Reactivity model, component structure, stores
**Rules**: Component rules, store rules, load function rules

---

## Angular

**Indicators**: `@angular/core` in dependencies
**CLAUDE.md emphasis**: Module structure, dependency injection, RxJS patterns, decorators
**Rules**: Module rules, service rules, component rules, pipe rules

---

## Express / Fastify / Koa (Node.js Backend)

**Indicators**: `express`, `fastify`, or `koa` in dependencies
**CLAUDE.md emphasis**: Middleware patterns, route organization, error handling middleware
**Subdirectory CLAUDE.md**: `src/routes/`, `src/middleware/`, `src/controllers/`, `src/services/`
**Rules**: API rules (request validation, response format), middleware rules, error handling rules
**Skills**: API endpoint creation skill, middleware creation skill
**Agents**: API reviewer (checks auth, validation, error handling)

---

## NestJS

**Indicators**: `@nestjs/core` in dependencies
**CLAUDE.md emphasis**: Module/controller/service pattern, decorators, dependency injection, DTOs
**Rules**: Module rules, DTO rules, guard rules, pipe rules
**Skills**: NestJS module creation skill

---

## Python / Django

**Indicators**: `django` in requirements
**CLAUDE.md emphasis**: MTV pattern, model conventions, template patterns, admin customization
**Subdirectory CLAUDE.md**: Per-app CLAUDE.md files
**Rules**: Model rules, view rules, serializer rules (if DRF), migration rules
**Skills**: Django app creation skill, model creation skill
**Hooks**: Black/Ruff on Write, isort on Write

---

## Python / FastAPI

**Indicators**: `fastapi` in requirements
**CLAUDE.md emphasis**: Pydantic models, dependency injection, async patterns, router organization
**Rules**: Schema rules, endpoint rules, dependency rules
**Skills**: FastAPI router creation skill

---

## Python / Flask

**Indicators**: `flask` in requirements
**CLAUDE.md emphasis**: Blueprint organization, extension patterns, request handling
**Rules**: Blueprint rules, template rules

---

## Go

**Indicators**: `go.mod` present
**CLAUDE.md emphasis**: Package organization, interface patterns, error handling (explicit returns), testing conventions
**Subdirectory CLAUDE.md**: `cmd/`, `internal/`, `pkg/`
**Rules**: Error handling rules, interface rules, package naming rules
**Skills**: Go package creation skill
**Hooks**: `go fmt` on Write, `go vet` on Edit

---

## Rust

**Indicators**: `Cargo.toml` present
**CLAUDE.md emphasis**: Module structure, error handling (Result/Option), ownership patterns, trait patterns
**Rules**: Error handling rules, unsafe usage rules, module rules
**Skills**: Rust module creation skill
**Hooks**: `cargo fmt` on Write, `cargo clippy` on Edit

---

## Ruby / Rails

**Indicators**: `Gemfile` with `rails`
**CLAUDE.md emphasis**: MVC conventions, ActiveRecord patterns, concerns, service objects
**Subdirectory CLAUDE.md**: `app/models/`, `app/controllers/`, `app/services/`
**Rules**: Model rules, controller rules, migration rules
**Hooks**: RuboCop on Write

---

## Monorepo Patterns

**Indicators**: workspaces config, turbo.json, nx.json, lerna.json
**CLAUDE.md emphasis**: Package boundaries, shared dependencies, workspace commands
**Structure**: Root CLAUDE.md + per-package CLAUDE.md files
**Rules**: Cross-package import rules, shared config rules
**Agents**: Cross-package impact reviewer

---

## Styling Patterns

### Tailwind CSS
**Rules**: Class ordering convention, custom utility rules, no arbitrary values (if strict)

### CSS Modules
**Rules**: Naming conventions, composition patterns

### styled-components / Emotion
**Rules**: Theme usage, component naming, style organization

---

## Database / ORM Patterns

### Prisma
**Rules**: Schema conventions, migration rules, query patterns
**Skills**: Prisma model creation skill

### Drizzle ORM
**Rules**: Schema file organization, migration patterns

### SQLAlchemy
**Rules**: Model conventions, session management, migration patterns (Alembic)

### TypeORM
**Rules**: Entity conventions, migration patterns, repository patterns

---

## Testing Patterns

### Jest / Vitest
**Rules**: Test file co-location, mock patterns, snapshot usage, coverage thresholds

### pytest
**Rules**: Fixture patterns, parametrize usage, conftest organization

### Playwright / Cypress (E2E)
**Rules**: Page object patterns, test data management, selector strategies
