# UX / Accessibility / Performance Q-bank — Step 24 (P5.6)

> **Round:** 6 (Frontend phase — third of the 3 frontend phases P5/P5.3/P5.6)
> **Steps:** 24 (after designSystem at Step 23, before i18nL10n at Step 25)
> **Modes:** Heavy ~15 Qs / Light ~8 Qs
> **Auto-loop:** per-persona (UX.Q1 over `personas.primary`)
> **Coupling:** Reads `personas.primary[]`, `phases.frontendArchitecture.frameworkConfirmed`. Writes `phases.uxAccessibilityPerf.*` + `phases.uxAccessibilityPerf.concerns.{marketingEmail, pushNotifications, productAnalytics}`. CHECK-R6-5: `surfacesByPersona` maps every `personaId` to ≥1 surface.
> **See also:** `personas.q-bank.md`, `frontend-architecture.q-bank.md`, `design-system.q-bank.md`

## Q-bank

### UX.Q1 — Per-persona surfaces
- **type:** multi-select
- **options:** `["web-app", "mobile-web", "native", "admin-dashboard"]`
- **loopOver:** `personas.primary`
- **loopMode:** hybrid-only  <!-- collapses to flat in mode.coupling=hybrid -->
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which surfaces does {persona.name} use? (web-app = primary browser experience; mobile-web = responsive mobile site; native = iOS/Android app; admin-dashboard = back-office tools. Pick ≥1 — every persona must land on at least one surface.)"
- **Stores to:** `phases.uxAccessibilityPerf.surfacesByPersona[<personaId>]` (array of selected surfaces)
- **Default:** `["web-app"]` for end-user personas; `["admin-dashboard"]` for ops/internal personas. CHECK-R6-5 fails if any `personaId` resolves to `[]`.

### UX.Q2 — Responsiveness strategy
- **type:** single-select
- **options:** `["mobile-first", "desktop-first", "adaptive", "responsive"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Layout strategy? (mobile-first = design from 320px up; desktop-first = design from desktop down; adaptive = distinct layouts per breakpoint; responsive = one fluid layout across all sizes.)"
- **Stores to:** `phases.uxAccessibilityPerf.responsivenessStrategy`
- **Default:** `"mobile-first"` when `surfacesByPersona` includes `"mobile-web"` or `"native"`; `"responsive"` otherwise.

### UX.Q3 — Breakpoint system
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Breakpoint system? (e.g., 'Tailwind defaults sm/md/lg/xl/2xl', 'MUI theme.breakpoints xs/sm/md/lg/xl', 'custom 480/768/1024/1440'.)"
- **Stores to:** `phases.uxAccessibilityPerf.breakpointSystem`
- **Default:** `""` (use framework/library defaults).

### UX.Q4 — Accessibility target
- **type:** single-select
- **options:** `["wcag-a", "wcag-aa", "wcag-aaa", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "WCAG conformance target? (wcag-a = minimum; wcag-aa = industry standard, legally required in many jurisdictions; wcag-aaa = highest, often impractical for full coverage; none = no formal target.)"
- **Stores to:** `phases.uxAccessibilityPerf.a11yTarget`
- **Default:** `"wcag-aa"` for any consumer/regulated app; `"wcag-a"` for internal tools; `"none"` only for throwaway prototypes.

### UX.Q5 — Keyboard navigation coverage
- **type:** single-select
- **options:** `["full", "partial", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Keyboard navigation coverage? (full = every interactive control reachable + visible focus ring; partial = primary flows only; none = mouse/touch only — usually disqualifies WCAG-AA.)"
- **Stores to:** `phases.uxAccessibilityPerf.keyboardNavigation`
- **Default:** `"full"` when `a11yTarget ∈ {"wcag-aa", "wcag-aaa"}`; `"partial"` otherwise.

### UX.Q6 — Screen-reader / a11y testing
- **type:** single-select
- **options:** `["axe", "manual", "lighthouse", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "How will a11y be tested? (axe = automated axe-core in CI; manual = VoiceOver / NVDA / TalkBack walks; lighthouse = Chrome Lighthouse audits; none = no formal testing.)"
- **Stores to:** `phases.uxAccessibilityPerf.screenReaderTesting`
- **Default:** `"axe"` for any project targeting `wcag-aa`+; `"none"` otherwise.

### UX.Q7 — LCP budget (seconds)
- **type:** numeric
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Largest Contentful Paint budget in seconds? (Core Web Vitals: <2.5 = good, 2.5–4.0 = needs improvement, >4.0 = poor. Industry default is 2.5s on 4G mobile.)"
- **Stores to:** `phases.uxAccessibilityPerf.performanceBudgets.lcp`
- **Default:** `2.5` (Core Web Vitals "good" threshold).

### UX.Q8 — INP budget (ms)
- **type:** numeric
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Interaction to Next Paint budget in milliseconds? (Core Web Vitals: <200 = good, 200–500 = needs improvement, >500 = poor. INP replaced FID in March 2024.)"
- **Stores to:** `phases.uxAccessibilityPerf.performanceBudgets.inp`
- **Default:** `200` (Core Web Vitals "good" threshold).

### UX.Q9 — CLS budget
- **type:** numeric
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Cumulative Layout Shift budget? (Core Web Vitals: <0.1 = good, 0.1–0.25 = needs improvement, >0.25 = poor. Unitless — measures visual instability.)"
- **Stores to:** `phases.uxAccessibilityPerf.performanceBudgets.cls`
- **Default:** `0.1` (Core Web Vitals "good" threshold).

### UX.Q10 — Image optimization
- **type:** single-select
- **options:** `["next-image", "imgix", "cloudinary", "native", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Image optimization strategy? (next-image = `next/image` automatic AVIF/WebP + lazy-load; imgix = hosted URL-based transforms; cloudinary = full media DAM with transforms; native = HTML `<img loading=lazy srcset>`; none = unoptimized.)"
- **Stores to:** `phases.uxAccessibilityPerf.imageOptimization`
- **Default:** `"next-image"` when framework is Next.js; `"native"` otherwise.

### UX.Q11 — Font loading
- **type:** single-select
- **options:** `["next-font", "font-display-swap", "preload", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Web-font loading strategy? (next-font = `next/font` zero-CLS self-hosting; font-display-swap = `@font-face { font-display: swap }`; preload = `<link rel=preload as=font>`; none = system fonts only.)"
- **Stores to:** `phases.uxAccessibilityPerf.fontLoading`
- **Default:** `"next-font"` when framework is Next.js; `"font-display-swap"` otherwise.

### UX.Q12 — Error state UX
- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "How do error states surface? (e.g., 'toast + inline field error', 'error boundary fallback page', 'banner at top with retry button'.)"
- **Stores to:** `phases.uxAccessibilityPerf.stateUx.error`
- **Default:** `""` (component-library defaults).

### UX.Q13 — Empty state UX
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "How do empty states render? (e.g., 'illustration + CTA to create first item', 'plain text "No results yet"', 'dismissable onboarding card'.)"
- **Stores to:** `phases.uxAccessibilityPerf.stateUx.empty`
- **Default:** `""` (component-library defaults).

### UX.Q14 — Loading state UX
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "How do loading states render? (e.g., 'skeleton screens per route', 'spinner overlay', 'optimistic UI then reconcile', 'Suspense fallbacks'.)"
- **Stores to:** `phases.uxAccessibilityPerf.stateUx.loading`
- **Default:** `""` (component-library defaults).

### UX.Q15 — Offline support
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Support offline use? (yes = service worker + cache strategy + offline page; no = require network for all routes.)"
- **Stores to:** `phases.uxAccessibilityPerf.offlineSupport`
- **Default:** `false` for v1 unless `surfacesByPersona` includes `"native"` or the app is a PWA.

## Inline gates (R6)

This phase hosts 3 of the 6 R6 inline gates — quick yes/no + vendor-pick questions that decide whether downstream tooling needs to be wired in.

### Gate.MktEmail — Marketing email gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["customer-io", "loops", "resend-audiences", "mailchimp"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Will you send marketing email (drip campaigns, broadcasts)? If yes, which vendor? (customer-io = event-driven journeys; loops = simple lifecycle; resend-audiences = developer-friendly broadcasts; mailchimp = classic newsletter platform.)"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.marketingEmail = {needed, vendor?}`
- **Default:** `{needed: false}` — marketing email is not in scope for most v1 cuts.

### Gate.Push — Push notifications gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["fcm", "onesignal", "pusher-beams"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Will you send push notifications (mobile/web)? If yes, which vendor? (fcm = Firebase Cloud Messaging, free + native-friendly; onesignal = full delivery + segmentation UI; pusher-beams = developer-focused transactional pushes.)"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.pushNotifications = {needed, vendor?}`
- **Default:** `{needed: false}` unless `surfacesByPersona` includes `"native"`.

### Gate.Analytics — Product analytics gate
- **type:** yes/no, then vendor pick if yes
- **vendors:** `["posthog", "mixpanel", "amplitude", "plausible"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Will you instrument product analytics (funnels, retention)? If yes, which vendor? (posthog = open-source + session-replay; mixpanel = mature event analytics; amplitude = enterprise behavioral cohorts; plausible = privacy-friendly lightweight pageview tracking.)"
- **Stores to:** `phases.uxAccessibilityPerf.concerns.productAnalytics = {needed, vendor?}`
- **Default:** `{needed: false}` for v1 unless the personas/feature roadmap explicitly mention funnel/retention measurement.

## Risk capture

### UX.Q_RISK — UX/A11y/Perf risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **tagSuggestions:** ["a11y-regression", "perf-budget-miss", "lcp-mobile", "inp-interaction", "cls-shift", "keyboard-trap", "color-contrast", "offline-gap"]
- **Prompt:** "UX/A11y/Performance risks? (e.g., 'WCAG-AAA target missed for color contrast', 'LCP > 2.5s on mobile-web', 'admin dashboard not keyboard-navigable')."
- **Stores to:** `phases.uxAccessibilityPerf.qRisks[]` + appends to top-level `risks[]` with `phase: "uxAccessibilityPerf"`

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| UX.Q1 | ✓ | ✓ | Per-persona surfaces — fundamental (loops over `personas.primary`) |
| UX.Q2 | ✓ | ✓ | Responsiveness — fundamental |
| UX.Q3 | ✓ | — | Breakpoints — empty default in light |
| UX.Q4 | ✓ | ✓ | A11y target — fundamental |
| UX.Q5 | ✓ | ✓ | Keyboard nav — fundamental |
| UX.Q6 | ✓ | — | Screen-reader testing — default in light |
| UX.Q7 | ✓ | ✓ | LCP budget — fundamental |
| UX.Q8 | ✓ | — | INP budget — default in light |
| UX.Q9 | ✓ | — | CLS budget — default in light |
| UX.Q10 | ✓ | ✓ | Image optimization — fundamental |
| UX.Q11 | ✓ | — | Font loading — default in light |
| UX.Q12 | ✓ | ✓ | Error UX — fundamental |
| UX.Q13 | ✓ | — | Empty UX — empty default in light |
| UX.Q14 | ✓ | — | Loading UX — empty default in light |
| UX.Q15 | ✓ | ✓ | Offline support — fundamental |
| Gate.MktEmail | ✓ | ✓ | Inline gate — always fires |
| Gate.Push | ✓ | ✓ | Inline gate — always fires |
| Gate.Analytics | ✓ | ✓ | Inline gate — always fires |
| UX.Q_RISK | ✓ | ✓ | Always fires |

Heavy total: 15 + 3 gates + Q_RISK. Light total: 8 + 3 gates + Q_RISK.
