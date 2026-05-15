# UX, Accessibility & Performance — A11y target: {{uxAccessibilityPerf.a11yTarget}}

## Surfaces by persona
{{#each uxAccessibilityPerf.surfacesByPersona}}- {{@key}}: {{this}}
{{/each}}

## Responsiveness & breakpoints
- Responsiveness strategy: {{uxAccessibilityPerf.responsivenessStrategy}}
- Breakpoint system: {{uxAccessibilityPerf.breakpointSystem}}

## Accessibility
- A11y target: {{uxAccessibilityPerf.a11yTarget}}
- Keyboard navigation: {{uxAccessibilityPerf.keyboardNavigation}}
- Screen-reader testing: {{uxAccessibilityPerf.screenReaderTesting}}

## Performance budgets
- LCP: {{uxAccessibilityPerf.performanceBudgets.lcp}}
- INP: {{uxAccessibilityPerf.performanceBudgets.inp}}
- CLS: {{uxAccessibilityPerf.performanceBudgets.cls}}

## Asset optimization
- Image optimization: {{uxAccessibilityPerf.imageOptimization}}
- Font loading: {{uxAccessibilityPerf.fontLoading}}

## State UX
- Error state: {{uxAccessibilityPerf.stateUx.error}}
- Empty state: {{uxAccessibilityPerf.stateUx.empty}}
- Loading state: {{uxAccessibilityPerf.stateUx.loading}}

## Offline support
- Offline support: {{uxAccessibilityPerf.offlineSupport}}

## Inline gates panel
- Marketing email — needed: {{uxAccessibilityPerf.concerns.marketingEmail.needed}}, vendor: {{uxAccessibilityPerf.concerns.marketingEmail.vendor}}
- Push notifications — needed: {{uxAccessibilityPerf.concerns.pushNotifications.needed}}, vendor: {{uxAccessibilityPerf.concerns.pushNotifications.vendor}}
- Product analytics — needed: {{uxAccessibilityPerf.concerns.productAnalytics.needed}}, vendor: {{uxAccessibilityPerf.concerns.productAnalytics.vendor}}

## Risks
{{#each uxAccessibilityPerf.qRisks}}- {{this}}
{{/each}}
