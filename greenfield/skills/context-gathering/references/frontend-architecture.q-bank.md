# Frontend Architecture Q-bank — Step 22 (P5)

> **Round:** 6 (Frontend phase — first of the 3 frontend phases P5/P5.3/P5.6)
> **Steps:** 22 (after stack/architectural framing; before design-system at Step 23)
> **Modes:** Heavy ~13 Qs / Light ~7 Qs
> **Auto-loop:** per-persona (FA.Q13 over `personas.primary`)
> **Coupling:** Reads `architecturalFraming.frontendFramework` (CHECK-R6-4 = framework must match). Writes `phases.frontendArchitecture.*`. Drives `package.json` deps + `lib/store.ts` + `lib/queries.ts`.
> **See also:** `architectural-framing.q-bank.md`, `personas.q-bank.md`

## Q-bank

### FA.Q1 — Frontend framework (cross-ref confirmation)

- **type:** confirm (cross-ref)
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (gate question — must run first)
- **cross-ref:** Reads `context.phases.architecturalFraming.frontendFramework`
- **invariant:** CHECK-R6-4 = stored value MUST equal the cross-ref source
- **R3-updates-path:** `context.phases.frontendArchitecture.frameworkConfirmed`

**Prompt:** "Earlier in Architectural Framing you said your frontend framework is `<architecturalFraming.frontendFramework>`. Confirm this is still the framework we'll architect against — or correct it now if it's changed."

**Stores to:** `phases.frontendArchitecture.frameworkConfirmed`

**Behavior:**
- Wizard shows the user the current `architecturalFraming.frontendFramework` value.
- User answers Confirm (default) or Correct.
- On Correct → wizard updates BOTH `architecturalFraming.frontendFramework` AND `phases.frontendArchitecture.frameworkConfirmed` to the new value, then re-runs CHECK-R6-4 to verify they match.

**Downstream effects:** Drives `package.json` framework deps (Next.js / Remix / Vite-React / Vue / Svelte / etc.), the routing question (FA.Q3) option set, and the bundler default (FA.Q9). Every subsequent FA.Q* assumes this value is locked.

**Default:** Whatever `architecturalFraming.frontendFramework` currently holds (no override).

### FA.Q2 — State management

- **type:** single-select
- **options:** `["builtin-only", "redux", "zustand", "jotai", "mobx", "recoil", "valtio", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.frontendArchitecture.stateManagement`

**Prompt:** "What state-management library will you use for client-side state beyond what the framework provides?"

**Stores to:** `phases.frontendArchitecture.stateManagement`

**Options (with descriptions):**
- "builtin-only (React context / Vue reactive / Svelte stores — no external lib)"
- "redux (Redux Toolkit — predictable global state, larger surface area)"
- "zustand (small, hook-based store — popular default in greenfield React projects)"
- "jotai (atomic state — fine-grained reactivity)"
- "mobx (observable-based, OO-friendly)"
- "recoil (atom/selector graph — Meta-originated, less active maintenance)"
- "valtio (proxy-based, mutation-friendly)"
- "none (you'll prop-drill / lift state — only for the simplest apps)"

**Downstream effects:** Drives `package.json` deps and `lib/store.ts` shape. `redux` adds `@reduxjs/toolkit` + `react-redux`. `zustand`/`jotai`/`valtio` add a single dep. `builtin-only` writes no store file.

**Recommend:** Lead with `zustand` for new React projects (smallest surface, hook-based, no provider boilerplate). `builtin-only` is fine for apps with <5 globally-shared values. `redux` only when the team already knows it or the app has heavy time-travel / devtools needs.

**Default:** `"zustand"` for React frameworks; `"builtin-only"` for Vue/Svelte/Solid (their builtin stores are already idiomatic).

### FA.Q3 — Routing strategy

- **type:** single-select
- **options:** `["app-router", "pages-router", "react-router", "tanstack-router", "remix", "vue-router", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.frontendArchitecture.routingStrategy`

**Prompt:** "Which router will the app use?"

**Stores to:** `phases.frontendArchitecture.routingStrategy`

**Options (with descriptions):**
- "app-router (Next.js App Router — file-system routing, RSC-aware)"
- "pages-router (Next.js Pages Router — legacy, getServerSideProps/getStaticProps)"
- "react-router (React Router v6+ — SPA-style)"
- "tanstack-router (TanStack Router — type-safe, search-param-first)"
- "remix (Remix loaders + actions — nested-route data flow)"
- "vue-router (Vue Router — official Vue routing)"
- "none (single-screen / native app shell / no client routing)"

**Downstream effects:** Drives the `app/` vs `pages/` vs `src/routes/` directory shape during scaffold. Constrains the data-fetching options in FA.Q4 (e.g., `app-router` + RSC pairs naturally with `fetch`; `react-router` SPA pairs better with `tanstack-query`/`swr`).

**Recommend:** `app-router` for new Next.js projects; `react-router` for Vite-React SPAs; `tanstack-router` if the user values type-safe route params; `remix` if they're explicitly using Remix.

**Default:** Derived from `frameworkConfirmed` — Next.js → `app-router`, Vite-React → `react-router`, Vue → `vue-router`, Svelte → `none` (SvelteKit's routing is implicit), Remix → `remix`.

### FA.Q4 — Data fetching

- **type:** single-select
- **options:** `["fetch", "tanstack-query", "swr", "rtk-query", "apollo", "urql", "trpc-client", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.frontendArchitecture.dataFetching`

**Prompt:** "How will the client fetch data from your API?"

**Stores to:** `phases.frontendArchitecture.dataFetching`

**Options (with descriptions):**
- "fetch (native fetch / framework-provided fetch — minimal, no cache layer)"
- "tanstack-query (formerly React Query — caching, retries, mutations, devtools)"
- "swr (Vercel's stale-while-revalidate hook — simpler API than tanstack-query)"
- "rtk-query (Redux Toolkit Query — integrated with Redux store)"
- "apollo (Apollo Client — GraphQL-first)"
- "urql (urql — lightweight GraphQL client)"
- "trpc-client (tRPC client — end-to-end type-safe RPC)"
- "none (you'll fetch inside RSC / server actions only, no client fetching)"

**Downstream effects:** Drives `lib/queries.ts` shape and `package.json` deps. `tanstack-query`/`swr` need provider setup in the root layout. `apollo`/`urql` only valid if the API layer is GraphQL (cross-checks `apiIntegration.apiStyle`).

**Recommend:** `tanstack-query` for any non-trivial client-side fetching (best devtools, broadest community). `fetch` for App Router projects doing 90% RSC. `trpc-client` if the backend is tRPC. `apollo`/`urql` only if `apiIntegration.apiStyle = "graphql"`.

**Default:** Derived from `apiIntegration.apiStyle` + `routingStrategy` — GraphQL API → `apollo`, tRPC API → `trpc-client`, REST + `app-router` → `fetch`, REST + SPA router → `tanstack-query`.

### FA.Q5 — Form handling

- **type:** single-select
- **options:** `["react-hook-form", "formik", "tanstack-form", "uncontrolled", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **R3-updates-path:** `context.phases.frontendArchitecture.formHandling`

**Prompt:** "How will forms and validation be handled?"

**Stores to:** `phases.frontendArchitecture.formHandling`

**Options (with descriptions):**
- "react-hook-form (uncontrolled-by-default, minimal re-renders, zod adapter)"
- "formik (controlled-by-default, declarative validation schema)"
- "tanstack-form (TanStack Form — framework-agnostic, type-safe)"
- "uncontrolled (raw `<form>` + FormData — no library)"
- "none (no forms in this app)"

**Downstream effects:** Drives `package.json` deps and the form-component patterns generated in `components/forms/`. `react-hook-form` pairs cleanly with `zod` for schema validation.

**Recommend:** `react-hook-form` for React projects — best DX, performance, and zod integration. `uncontrolled` is fine for 1–2 forms total. `formik` only if the team already uses it.

**Default:** `"react-hook-form"` for React; `"uncontrolled"` for Svelte/Vue (their built-in form bindings are idiomatic).

### FA.Q6 — Animation library

- **type:** single-select
- **options:** `["framer-motion", "react-spring", "auto-animate", "css-only", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **R3-updates-path:** `context.phases.frontendArchitecture.animationLibrary`

**Prompt:** "What animation approach will the UI use?"

**Stores to:** `phases.frontendArchitecture.animationLibrary`

**Options (with descriptions):**
- "framer-motion (declarative React motion library — broad coverage, ~50kb)"
- "react-spring (physics-based animations — smaller, more low-level)"
- "auto-animate (FormKit AutoAnimate — drop-in list/transition animations, ~2kb)"
- "css-only (Tailwind/vanilla CSS transitions + keyframes — zero JS cost)"
- "none (no animations beyond what shadcn/MUI provides out-of-box)"

**Downstream effects:** Drives `package.json` deps. `framer-motion` adds a non-trivial bundle cost. `css-only` is the default for production-scale apps.

**Recommend:** `css-only` for greenfield projects — animations rarely justify a runtime library cost up-front. Add `framer-motion` later if the UX team demands choreographed motion.

**Default:** `"css-only"` (always — greenfield opinion: ship without animation libs; add one when a real use case lands).

### FA.Q7 — Error boundaries

- **type:** single-select
- **options:** `["per-route", "per-feature", "global-only", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **R3-updates-path:** `context.phases.frontendArchitecture.errorBoundaries`

**Prompt:** "How will the app structure error boundaries?"

**Stores to:** `phases.frontendArchitecture.errorBoundaries`

**Options (with descriptions):**
- "per-route (each route segment has its own error boundary — App Router `error.tsx` pattern)"
- "per-feature (feature folders contain their own boundary — coarser than per-route)"
- "global-only (single top-level boundary — simplest, but errors take down the whole tree)"
- "none (rely on framework defaults / browser error UI)"

**Downstream effects:** Drives the scaffold's `app/error.tsx` / `app/<route>/error.tsx` placement and the feature-folder template shape.

**Recommend:** `per-route` for App Router projects (the framework already supports it). `per-feature` for SPAs where routes don't map cleanly to features. `global-only` is acceptable for very small apps.

**Default:** `per-route` for `routingStrategy: app-router`; `per-feature` for `react-router`/`tanstack-router`; `global-only` for everything else.

### FA.Q8 — Code splitting

- **type:** single-select
- **options:** `["route-level", "component-lazy", "manual", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **R3-updates-path:** `context.phases.frontendArchitecture.codeSplitting`

**Prompt:** "What's the code-splitting strategy?"

**Stores to:** `phases.frontendArchitecture.codeSplitting`

**Options (with descriptions):**
- "route-level (framework auto-splits per route — Next.js / Remix default)"
- "component-lazy (`React.lazy` / dynamic imports for heavy components)"
- "manual (explicit chunk hints to the bundler — only for unusual layouts)"
- "none (single bundle — only viable for very small apps)"

**Downstream effects:** Drives the bundler config (FA.Q9) and informs whether dynamic-import patterns appear in generated code.

**Recommend:** `route-level` for framework projects (it's free). Add `component-lazy` for heavy editor/chart/map components. `manual` is rarely worth the maintenance cost.

**Default:** `"route-level"` for any framework with a router; `"component-lazy"` for SPAs; `"none"` only for `appType: cli` or trivially-small apps.

### FA.Q9 — Bundler

- **type:** single-select
- **options:** `["turbopack", "vite", "webpack", "rspack", "esbuild", "rollup", "parcel", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **R3-updates-path:** `context.phases.frontendArchitecture.bundler`

**Prompt:** "Which bundler will the project use?"

**Stores to:** `phases.frontendArchitecture.bundler`

**Options (with descriptions):**
- "turbopack (Next.js 15+ default — Rust-based, fastest dev HMR)"
- "vite (Vite — esbuild-dev + rollup-prod, the SPA default)"
- "webpack (Webpack 5 — Next.js legacy, mature ecosystem)"
- "rspack (Rust port of Webpack — drop-in replacement)"
- "esbuild (raw esbuild — fast, simpler than vite for libraries)"
- "rollup (Rollup — best for library output, less ideal for apps)"
- "parcel (Parcel — zero-config, less common for greenfield)"
- "none (framework hides the bundler entirely — e.g., SvelteKit, Astro)"

**Downstream effects:** Drives `package.json` scripts (`dev`, `build`) and the bundler config file shape. Pairs with `frameworkConfirmed`.

**Recommend:** `turbopack` for Next.js 15+ (it's the default and fastest). `vite` for Vite-React / Vue / Svelte SPAs. `webpack` only if a specific Webpack-only plugin is required.

**Default:** Derived from `frameworkConfirmed` — Next.js → `turbopack`, Vite-React/Vue/Svelte → `vite`, Remix → `vite`, SvelteKit/Astro → `none`.

### FA.Q10 — Dev server preferences

- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **R3-updates-path:** `context.phases.frontendArchitecture.devServer`

**Prompt:** "Any specific dev-server preferences? (port, HMR overlay, HTTPS in dev, host binding)"

**Stores to:** `phases.frontendArchitecture.devServer`

**Suggested prompts:**
- "Non-default port (e.g., 3001 because 3000 is taken)?"
- "HTTPS in dev (mkcert / certs path)?"
- "Bind to `0.0.0.0` for LAN device testing?"
- "Custom HMR overlay or proxy config?"

**Downstream effects:** Captured as free-form notes; if non-empty, the scaffold renders the relevant config into `next.config.ts` / `vite.config.ts` / etc.

**If no preferences:** capture as `""` (empty string) or `"defaults"`. Do not leave null.

**Default:** `""` (empty — use framework defaults). Greenfield opinion: defaults are right for 95% of new projects.

### FA.Q11 — Server-side rendering (SSR)

- **type:** yes/no (free-form note)
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **schema-gap:** `phases.frontendArchitecture.ssr` is NOT in the T1 schema for this phase — flag for follow-up schema patch
- **R3-updates-path:** `context.phases.frontendArchitecture.ssr`

**Prompt:** "Will the app render pages on the server (SSR) for the first paint?"

**Stores to:** `phases.frontendArchitecture.ssr` — yes/no plus a free-form note explaining the choice (e.g., "yes, all routes" / "no, fully SPA" / "yes for marketing pages, no for the app shell").

**Downstream effects:** Pairs with `routingStrategy` and FA.Q12 (static generation). App Router defaults to SSR per route; SPA routers are CSR-only.

**Recommend:** `yes` for `app-router`/`remix` (it's the framework default). `no` for `react-router`/`tanstack-router` SPAs.

**Default:** `"yes"` for `app-router`/`remix`/`vue-router`-with-Nuxt; `"no"` for `react-router`/`tanstack-router`/`none`.

### FA.Q12 — Static generation (SSG / ISR)

- **type:** yes/no (free-form note)
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** Always (uses default in light mode)
- **schema-gap:** `phases.frontendArchitecture.staticGeneration` is NOT in the T1 schema for this phase — flag for follow-up schema patch
- **R3-updates-path:** `context.phases.frontendArchitecture.staticGeneration`

**Prompt:** "Will any routes be pre-rendered at build time (SSG) or incrementally regenerated (ISR)?"

**Stores to:** `phases.frontendArchitecture.staticGeneration` — yes/no plus a free-form note (e.g., "yes — marketing pages SSG, blog ISR with 1h revalidate" / "no — all dynamic").

**Downstream effects:** Drives `generateStaticParams` patterns in App Router scaffolds and informs the build pipeline (CI caches, deploy strategy in `cicdAndDelivery`).

**Recommend:** `yes` if the app has marketing / docs / blog routes — pre-rendering them is a free perf win. `no` for app-shell-only products (dashboards, B2B SaaS).

**Default:** `"no"` (greenfield opinion: start dynamic, opt routes into SSG/ISR when traffic patterns justify it).

### FA.Q13 — Feature surfaces by persona (per-persona loop)

- **type:** per-persona feature surfaces
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always
- **loopOver:** `personas.primary`
- **loopMode:** auto
- **schema-gap:** `phases.frontendArchitecture.featureSurfacesByPersona` is NOT in the T1 schema for this phase — flag for follow-up schema patch
- **R3-updates-path:** `context.phases.frontendArchitecture.featureSurfacesByPersona[<persona.id>]`

**Prompt (per persona):** "For persona **<persona.name>** (`<persona.id>`) — which feature surfaces will they primarily use? List the routes / screens / shell areas. (e.g., 'admin dashboard at /admin', 'public landing at /', 'settings drawer in app shell')"

**Stores to:** `phases.frontendArchitecture.featureSurfacesByPersona` — object keyed by persona id, value is array of `{ surface: string, route?: string, notes?: string }`.

**Loop behavior:**
- Wizard iterates over `personas.primary[]` and asks once per persona.
- Iteration index is tracked in `phases.frontendArchitecture.loopIterations.featureSurfacesByPersona`.
- If `personas.primary` is empty, the question is skipped and `featureSurfacesByPersona` is set to `{}`.

**Downstream effects:** Drives the feature-folder layout in `app/` or `src/features/`, and feeds into `docs/feature-list.json` cross-referencing (Round 5 featureRoadmap reads persona → feature mapping for surface-area justification).

**Recommend:** Be concrete — name the routes. "Admin uses /admin" is more useful than "Admin uses admin features."

**Default:** Empty per persona (`[]`) if the user skips — but recommend not skipping in heavy mode, since persona-surface mapping is the spine of the App Router file tree.

### FA.Q_RISK — Frontend architecture risk

- **type:** free-text (bulleted)
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["bundle-size", "ssr-hydration", "state-leakage", "router-lock-in", "framework-churn"]

**Prompt:** "What's the biggest frontend-architecture risk for THIS project? (e.g., 'Next.js App Router + heavy client state may hit hydration mismatches', 'bundle size will balloon if we add framer-motion + apollo + rtk-query', 'vendor lock-in via Next.js-specific server actions', 'routing strategy may not survive the move to mobile')."

**Stores to:** `risks[]` array (new entry with `originatingPhase = "frontendArchitecture"`, id auto-assigned `R-FRONTENDARCHITECTURE-1`).

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| FA.Q1 | ✓ | ✓ | Framework confirmation — CHECK-R6-4 gate |
| FA.Q2 | ✓ | ✓ | State management — fundamental |
| FA.Q3 | ✓ | ✓ | Routing — fundamental |
| FA.Q4 | ✓ | ✓ | Data fetching — fundamental |
| FA.Q5 | ✓ | — | Form handling — uses default in light |
| FA.Q6 | ✓ | — | Animation library — uses default in light (`css-only`) |
| FA.Q7 | ✓ | — | Error boundaries — uses default in light |
| FA.Q8 | ✓ | — | Code splitting — uses default in light |
| FA.Q9 | ✓ | ✓ | Bundler — fundamental |
| FA.Q10 | ✓ | — | Dev server — empty default in light |
| FA.Q11 | ✓ | — | SSR — default in light (schema gap) |
| FA.Q12 | ✓ | — | Static generation — default in light (schema gap) |
| FA.Q13 | ✓ | ✓ | Per-persona feature surfaces — loops over `personas.primary` (schema gap) |
| FA.Q_RISK | ✓ | ✓ | Always fires |

Heavy total: 13 + Q_RISK. Light total: 7 + Q_RISK.

## Schema gaps (flag for follow-up)

T1's schema for `phases.frontendArchitecture.*` declares the following keys:

- `frameworkConfirmed` ✓ (FA.Q1)
- `stateManagement` ✓ (FA.Q2)
- `routingStrategy` ✓ (FA.Q3)
- `dataFetching` ✓ (FA.Q4)
- `formHandling` ✓ (FA.Q5)
- `animationLibrary` ✓ (FA.Q6)
- `errorBoundaries` ✓ (FA.Q7)
- `codeSplitting` ✓ (FA.Q8)
- `bundler` ✓ (FA.Q9)
- `devServer` ✓ (FA.Q10)
- `qRisks` ✓ (FA.Q_RISK collector)
- `skipped`, `deferredReason`, `loopIterations` ✓ (phase metadata)

**Missing from T1 schema — must be patched before this Q-bank is usable end-to-end:**

- `ssr` — referenced by FA.Q11 (yes/no + free-form note)
- `staticGeneration` — referenced by FA.Q12 (yes/no + free-form note)
- `featureSurfacesByPersona` — referenced by FA.Q13 (object keyed by persona id, array of surface entries)

File a follow-up task against T1 to extend the schema with these three keys before T26 lands in production. Until the schema is patched, wizard runs that hit FA.Q11/Q12/Q13 in heavy mode will write to unknown paths and fail validation.

## Cross-phase invariants

- **CHECK-R6-4** — `phases.frontendArchitecture.frameworkConfirmed === phases.architecturalFraming.frontendFramework`. Enforced inline after FA.Q1 and re-checked at grill-spec.
- **CHECK-FA-DATA** — `phases.frontendArchitecture.dataFetching ∈ {apollo, urql}` implies `phases.apiIntegration.apiStyle === "graphql"`. Enforced at grill-spec.
- **CHECK-FA-TRPC** — `phases.frontendArchitecture.dataFetching === "trpc-client"` implies `phases.apiIntegration.apiStyle === "trpc"`. Enforced at grill-spec.
- **CHECK-FA-BUNDLER** — `phases.frontendArchitecture.bundler` must be valid for `frameworkConfirmed` (e.g., `turbopack` requires Next.js 15+). Enforced at grill-spec.
