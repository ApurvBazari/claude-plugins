# Caching — CDN provider: {{caching.cdnProvider}}

## Layers
{{#each caching.layers}}- {{this}}
{{/each}}

## Invalidation
- Strategy: {{caching.invalidationStrategy}}
- Stale-while-revalidate: {{caching.staleWhileRevalidate}}
- Key design: {{caching.keyDesign}}

## Multi-tenant isolation
{{caching.multiTenantIsolation}}

## Observability
- Hit rates: {{caching.observability.hitRates}}
- Alert on drop: {{caching.observability.alertOnDrop}}

## Stampede protection
{{caching.stampedeProtection}}

## Risks
{{#each caching.qRisks}}- {{this}}
{{/each}}
