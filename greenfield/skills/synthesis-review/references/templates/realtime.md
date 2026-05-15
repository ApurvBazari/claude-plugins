# Real-time — Transport: {{realtime.transport}}

## Use cases (per-persona union)
{{#each realtime.useCases}}- {{this}}
{{/each}}

## Backend
- Pub/sub: {{realtime.backend}}
- Client library: {{realtime.clientLib}}

## Scaling
- Sticky sessions: {{realtime.scaling.stickySessions}}
- Horizontal scaling: {{realtime.scaling.horizontal}}

## Reconnect & delivery
- Reconnect strategy: {{realtime.reconnectStrategy}}
- Message ordering: {{realtime.messageOrdering}}
- Dedup: {{realtime.dedup}}

## Risks
{{#each realtime.qRisks}}- {{this}}
{{/each}}
