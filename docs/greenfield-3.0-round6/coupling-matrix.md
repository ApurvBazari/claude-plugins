# Round 6 — Coupling Matrix (extends R5)

R6 adds 9 new top-level phases + 6 inline gates + CI Draft Review wiring on top of the R5 matrix. Each row below captures the new phase's input dependencies, output writes, and auto-loop posture in `auto-loop` mode. See `docs/greenfield-3.0-round5/coupling-matrix.md` for R5 rows and `docs/greenfield-3.0-round4/coupling-matrix.md` for R4.

## R6 additions

| Phase | Reads from | Writes to | Auto-loop |
|---|---|---|---|
| search | dataArchitecture.entities, dataArchitecture.engine | phases.search.* + lib/search.ts + (FTS) prisma migration | flat |
| caching | architecturalFraming.frontendFramework, dataArchitecture.engine | phases.caching.* + lib/cache.ts + CDN headers | flat |
| realtime | personas.primary, runtimeOperations.observability | phases.realtime.* + lib/realtime.ts + realtime API route | per-persona |
| fileUploads | personas.primary, privacy.piiFields | phases.fileUploads.* + lib/uploads.ts + IAM policy | per-persona |
| payments | personas.primary, privacy.pii.financial, security | phases.payments.* + lib/payments/<provider>.ts + webhook + portal | per-persona (customer vs admin) |
| frontendArchitecture | architecturalFraming.frontendFramework, personas.primary | phases.frontendArchitecture.* + package.json deps + lib skeletons | per-persona |
| designSystem | frontendArchitecture.frameworkConfirmed | phases.designSystem.* + shadcn/mui/mantine init + tailwind tokens | flat |
| uxAccessibilityPerf | personas.primary, frontendArchitecture.frameworkConfirmed | phases.uxAccessibilityPerf.* + 3 gates + Lighthouse CI + image optimizer | per-persona |
| i18nL10n | frontendArchitecture.frameworkConfirmed | phases.i18nL10n.* + lib/i18n.ts + messages/* + routing config | flat |
| cicdAndDelivery (CI Draft Review) | stack.language, architecturalFraming.frontendFramework, cicdAndDelivery.cicd, auth, payments | phases.cicdAndDelivery.{draftYaml, lockedYaml, adjustHistory, draftWarnings} | Approve / Adjust / Reject |

## Inline gates

Each gate records to `phases.<parent>.concerns.<gateName> = { needed: boolean, vendor?: string, notes?: string }`. Vendor enum is a soft pick (free-text fallback allowed when "other").

| Gate | Parent phase (step) | Vendor enum |
|---|---|---|
| **transactionalEmail** | Auth (Step 11) | Resend / Postmark / SES / SendGrid |
| **sms** | Auth (Step 11) | Twilio / Vonage / MessageBird |
| **marketingEmail** | P5.6 UX / Accessibility / Performance (Step 24) | Customer.io / Loops / Resend Audiences / Mailchimp |
| **pushNotifications** | P5.6 UX / Accessibility / Performance (Step 24) | FCM / OneSignal / Pusher Beams |
| **productAnalytics** | P5.6 UX / Accessibility / Performance (Step 24) | PostHog / Mixpanel / Amplitude / Plausible |
| **featureGating** | CI/CD & Auto-Evolution (Step 19) | PostHog feature flags / LaunchDarkly / Flagsmith / GrowthBook |

## R6 mode interactions

| `mode.depth` | `mode.coupling` | New-phase prompt count (rough) |
|---|---|---|
| heavy | auto-loop | ~120+ (9 phases × ~13 Qs avg; per-persona phases multiply by primary persona count) |
| heavy | hybrid | ~120 (9 phases × ~13 Qs, flat) |
| light | auto-loop | ~60 (9 phases × ~7 Qs avg; per-persona phases multiply) |
| light | hybrid | ~63 (9 phases × ~7 Qs, flat — lightest path) |

Plus ~9 gate Qs (6 yes/no + vendor follow-up averaging 1.5 Qs).

## R6 cross-phase dependency graph

```
Step 2 (Stack) ─────────────────┐
Step 3 (Personas) ──────────────┤
Step 4 (ArchFraming) ───────────┤
Step 5 (DomainModel) ───────────┤
Step 6 (DataArchitecture) ──────┤
                                 │
                                 ▼
                          ┌──────────────────────────────┐
                          │  9 new phases insert at      │
                          │  nearest-dependency boundary │
                          │  (Items 4 in locked spec)    │
                          └──────────────────────────────┘
                                 │
   ┌─────────────────────────────┼─────────────────────────────┐
   │                             │                             │
   ▼                             ▼                             ▼
Step 7 Search           Step 9 Caching             Step 10 Realtime
Step 13 FileUploads     Step 15 Payments           Step 22 P5 Frontend Arch
Step 23 DesignSystem    Step 24 P5.6 UX            Step 25 i18n/l10n


Step 2 (Stack) ─────────┐
Step 4 (ArchFraming) ───┤
Step 11 (Auth) ─────────┤
Step 15 (Payments) ─────┤
Step 19 (CI/CD) ────────┤
                         │
                         ▼
                  ┌─────────────────────────────┐
                  │  Step 20 — CI Draft Review  │
                  │  render-ci-drafts.sh        │
                  │  ↓                          │
                  │  draftYaml + draftWarnings  │
                  └─────────────────────────────┘
                         │
                         ▼
                  Approve / Adjust / Reject
                         │
                         ▼
                  lockedYaml captured;
                  onboard writes verbatim
                  to .github/workflows/*
                  (or vendor-specific path)
```

See also: `docs/greenfield-3.0-round5/coupling-matrix.md` for R5 rows (featureRoadmap + schemaDraftReview) and `docs/greenfield-3.0-round4/coupling-matrix.md` for R4 (personas + domainModel + distributedRisk).
