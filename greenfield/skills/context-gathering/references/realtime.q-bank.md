# Real-time Q-bank — Step 10

> **Round:** 6 (Concern phase — between Caching and Auth)
> **Steps:** 10 (after caching at Step 9, before auth at Step 11)
> **Modes:** Heavy ~12 Qs / Light ~6 Qs
> **Auto-loop:** per-persona (`loopOver: personas.primary`, `loopMode: per-persona`); CHECK-R6-9 caps iterations at `min(personas.length, 4)`.
> **Coupling:** Reads `personas.primary[]`. Writes `phases.realtime.*` (and `loopIterations`). Drives `lib/realtime.ts` + `app/api/realtime/route.ts` + reconnect helper.
> **See also:** `personas.q-bank.md`, design spec § Phase content / Real-time

## Q-bank

### RT.Q1 — Transport
- **type:** single-select
- **options:** ["sse", "websocket", "long-poll", "push", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Real-time transport? (SSE = server push over HTTP; WebSocket = full duplex; long-poll = HTTP fallback; push = mobile/web push; none = skip phase.)"
- **Stores to:** `phases.realtime.transport`

### RT.Q2 — Use cases (per-persona)
- **type:** multi-select
- **options:** ["notifications", "presence", "collaboration", "live-data", "chat", "telemetry"]
- **showInLight:** true
- **loopOver:** `personas.primary`
- **loopMode:** per-persona
- **isRiskCapture:** false
- **Prompt:** "For persona `{{this.id}}`, what real-time use cases are needed?"
- **Stores to:** `phases.realtime.useCases[]` (per-persona — flattens to union across iterations; CHECK-R6-9 caps iterations at `min(personas.length, 4)`)

### RT.Q3 — Backend pub/sub
- **type:** single-select
- **options:** ["redis-pubsub", "dedicated-service", "channels", "broker", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Backend pub/sub? (redis-pubsub = simple; dedicated-service = e.g. NATS/Kafka; channels = Django-style; broker = managed; none = direct.)"
- **Stores to:** `phases.realtime.backend`

### RT.Q4 — Client library
- **type:** single-select
- **options:** ["pusher", "ably", "soketi", "centrifugo", "native", "none"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Client library? (pusher/ably/soketi/centrifugo are managed; native = raw WS; none = build adapter.)"
- **Stores to:** `phases.realtime.clientLib`

### RT.Q5 — Sticky sessions
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Sticky sessions for WebSocket? (load balancer routes a client to the same server across reconnects.)"
- **Stores to:** `phases.realtime.scaling.stickySessions`

### RT.Q6 — Horizontal scaling
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Horizontal scaling for real-time tier? (multiple connection servers behind a pub/sub bus.)"
- **Stores to:** `phases.realtime.scaling.horizontal`

### RT.Q7 — Reconnect strategy
- **type:** single-select
- **options:** ["exponential-backoff", "fixed-interval", "manual", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Reconnect strategy? (exponential-backoff = jitter-based; fixed-interval = constant; manual = user-driven; none = drop on disconnect.)"
- **Stores to:** `phases.realtime.reconnectStrategy`

### RT.Q8 — Message ordering
- **type:** single-select
- **options:** ["per-channel", "global", "best-effort"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Message ordering guarantee? (per-channel = ordered within a topic; global = total order; best-effort = no guarantee.)"
- **Stores to:** `phases.realtime.messageOrdering`

### RT.Q9 — Dedup
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Dedupe duplicate messages on client? (e.g., idempotency keys.)"
- **Stores to:** `phases.realtime.dedup`

### RT.Q10 — Heartbeat interval
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Heartbeat interval? (e.g., '30s', '60s' — keepalive for stale-connection detection.)"
- **Stores to:** `phases.realtime.heartbeatInterval` (free-form — flag the schema gap)

### RT.Q11 — Graceful degradation
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Graceful degradation when real-time unavailable? (fallback to polling, banner state, etc.)"
- **Stores to:** `phases.realtime.gracefulDegradation` (free-form — flag the schema gap)

### RT.Q_RISK — Real-time risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "Real-time risks? (e.g., 'WebSocket reconnection storms after backend restart', 'message ordering breaks for cross-channel events')"
- **Stores to:** `phases.realtime.qRisks[]` + appends to top-level `risks[]` with `phase: "realtime"`
