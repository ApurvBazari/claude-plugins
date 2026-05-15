# Design System Q-bank — Step 23 (P5.3)

> **Round:** 6 (Frontend phase — second of the 3 frontend phases P5/P5.3/P5.6)
> **Steps:** 23 (after frontendArchitecture at Step 22, before uxAccessibilityPerf at Step 24)
> **Modes:** Heavy ~12 Qs / Light ~6 Qs
> **Coupling:** Reads `phases.frontendArchitecture.frameworkConfirmed`. Writes `phases.designSystem.*`. Drives shadcn init / MUI theme / Mantine provider + `tailwind.config.ts` tokens + `.storybook/`.
> **See also:** `frontend-architecture.q-bank.md`

## Q-bank

### DS.Q1 — Component library
- **type:** single-select
- **options:** `["shadcn", "mui", "mantine", "chakra", "ant", "headless-ui", "custom", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Which component library will the app use? (shadcn = copy-in Radix-based components; mui/mantine/chakra/ant = full themed kits; headless-ui = unstyled primitives; custom = build your own; none = no library.)"
- **Stores to:** `phases.designSystem.componentLibrary`
- **Default:** `"shadcn"` for React + Tailwind stacks; `"mantine"` for non-Tailwind React; `"none"` otherwise.

### DS.Q2 — Theming approach
- **type:** single-select
- **options:** `["css-variables", "tokens", "css-in-js", "tailwind-config", "multiple-themes"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "How will theming be implemented? (css-variables = `:root { --color-* }`; tokens = design-token JSON pipeline; css-in-js = emotion/styled-components theme; tailwind-config = tokens in `tailwind.config.ts`; multiple-themes = brand/tenant theming.)"
- **Stores to:** `phases.designSystem.themingApproach`
- **Default:** `"tailwind-config"` if Tailwind detected; else `"css-variables"`.

### DS.Q3 — Primitives strategy
- **type:** single-select
- **options:** `["radix", "react-aria", "ariakit", "headless-ui", "custom", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Which a11y primitives layer? (radix = Radix UI; react-aria = Adobe React Aria; ariakit = Ariakit; headless-ui = Tailwind Labs; custom = roll your own; none = rely on the component library above.)"
- **Stores to:** `phases.designSystem.primitivesStrategy`
- **Default:** `"radix"` when `componentLibrary === "shadcn"`; `"none"` when a full kit (mui/mantine/chakra/ant) is selected.

### DS.Q4 — Variant system
- **type:** single-select
- **options:** `["cva", "tv", "stitches", "panda-recipes", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Variant authoring tool? (cva = class-variance-authority; tv = tailwind-variants; stitches = CSS-in-JS variants; panda-recipes = Panda CSS recipes; none = inline conditionals.)"
- **Stores to:** `phases.designSystem.variantSystem`
- **Default:** `"cva"` for shadcn + Tailwind; `"none"` otherwise.

### DS.Q5 — Icon system
- **type:** single-select
- **options:** `["lucide", "heroicons", "phosphor", "tabler", "iconify", "custom", "none"]`
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Icon set? (lucide = shadcn default; heroicons = Tailwind Labs; phosphor = broad coverage; tabler = stroke-based; iconify = aggregator across sets; custom = your own SVG library; none = no iconography.)"
- **Stores to:** `phases.designSystem.iconSystem`
- **Default:** `"lucide"` for shadcn; `"heroicons"` for plain Tailwind; library-default otherwise.

### DS.Q6 — Typography scale
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Typography scale? (e.g., 'Tailwind defaults', 'modular scale 1.25', 'Inter @ 14/16/20/24/32/48', or a token-set name.)"
- **Stores to:** `phases.designSystem.typographyScale`
- **Default:** `""` (use framework/library defaults).

### DS.Q7 — Color system
- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Color system? (e.g., 'shadcn neutrals + brand teal', 'Radix Colors scales 1–12', 'OKLCH custom palette', or paste primary/secondary hex values.)"
- **Stores to:** `phases.designSystem.colorSystem`
- **Default:** `""` (library defaults).

### DS.Q8 — Spacing tokens
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Spacing tokens? (e.g., 'Tailwind 4px scale', '8pt grid', 'custom 2/4/8/12/16/24/32/48/64'.)"
- **Stores to:** `phases.designSystem.spacingTokens`
- **Default:** `""` (Tailwind/library defaults).

### DS.Q9 — Design tool integration
- **type:** single-select
- **options:** `["figma", "penpot", "sketch", "none"]`
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Design tool the team designs in? (figma = Figma + tokens plugin; penpot = open-source alt; sketch = Mac-only; none = code-first / no design tool.)"
- **Stores to:** `phases.designSystem.designToolIntegration`
- **Default:** `"figma"` if any persona involves a designer; else `"none"`.

### DS.Q10 — Storybook adopted
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Adopt Storybook for component development and visual review?"
- **Stores to:** `phases.designSystem.storybookAdopted`
- **Default:** `true` for `componentLibrary ∈ {"shadcn", "custom"}`; `false` otherwise (full kits ship their own catalog).

### DS.Q11 — Dark mode
- **type:** yes/no (free-form note)
- **showInLight:** false
- **isRiskCapture:** false
- **schema-gap:** `phases.designSystem.darkMode` is NOT in the T1 schema for this phase — flag for follow-up schema patch
- **Prompt:** "Support dark mode? (yes/no + brief note — e.g., 'yes, system-pref toggle', 'yes, manual toggle only', 'no — light only for v1'.)"
- **Stores to:** `phases.designSystem.darkMode` — yes/no plus a free-form note
- **Default:** `"yes — system-pref + manual toggle"` when `themingApproach ∈ {"css-variables", "tailwind-config", "multiple-themes"}`; `"no"` otherwise.

### DS.Q12 — Brand guidelines link
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **schema-gap:** `phases.designSystem.brandGuidelinesLink` is NOT in the T1 schema for this phase — flag for follow-up schema patch
- **Prompt:** "Link to brand guidelines / design doc? (URL or repo path — leave empty if none yet.)"
- **Stores to:** `phases.designSystem.brandGuidelinesLink`
- **Default:** `""` (empty).

### DS.Q_RISK — Design-system risk
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **tagSuggestions:** ["theming-drift", "token-debt", "library-lock-in", "a11y-regression", "designer-dev-handoff"]
- **Prompt:** "What's the biggest design-system risk for THIS project? (e.g., 'shadcn copy-in drifts from upstream after 6 months', 'multi-tenant theming explodes token count', 'designers iterate in Figma faster than tokens land in code')."
- **Stores to:** `phases.designSystem.qRisks[]` + appends to top-level `risks[]` with `originatingPhase: "designSystem"`

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| DS.Q1 | ✓ | ✓ | Component library — fundamental |
| DS.Q2 | ✓ | ✓ | Theming approach — fundamental |
| DS.Q3 | ✓ | — | Primitives — default in light |
| DS.Q4 | ✓ | — | Variant system — default in light |
| DS.Q5 | ✓ | ✓ | Icon system — fundamental |
| DS.Q6 | ✓ | — | Typography — empty default in light |
| DS.Q7 | ✓ | ✓ | Color system — fundamental |
| DS.Q8 | ✓ | — | Spacing tokens — empty default in light |
| DS.Q9 | ✓ | — | Design tool — default in light |
| DS.Q10 | ✓ | ✓ | Storybook — fundamental |
| DS.Q11 | ✓ | — | Dark mode — default in light (schema gap) |
| DS.Q12 | ✓ | — | Brand guidelines — empty default in light (schema gap) |
| DS.Q_RISK | ✓ | ✓ | Always fires |

Heavy total: 12 + Q_RISK. Light total: 6 + Q_RISK.
