# Round 6 — Migration Notes (alpha.6 → alpha.7)

## What's new

Round 6 lands 9 new top-level wizard phases, 6 inline gates, a CI Draft Review step, a shared renderer library, a plugin reshuffle, and a generic migration runner. The wizard step count grows from 20 to **30 named steps**. All additions are deterministic-by-default: onboard generation writes the corresponding artifacts (lib skeletons, package deps, CI YAML, schema modules, IAM policy hints, etc.) verbatim from the captured phase state.

- **9 new phases**
  - Step 7 — **Search** (FTS / dedicated engine; emits `lib/search.ts` + optional Prisma FTS migration)
  - Step 9 — **Caching** (CDN + runtime cache; emits `lib/cache.ts` + CDN header hints)
  - Step 10 — **Real-time** (websockets / SSE / polling; emits `lib/realtime.ts` + realtime API route)
  - Step 13 — **File Uploads & CDN** (provider + IAM; emits `lib/uploads.ts` + IAM policy hint)
  - Step 15 — **Payments** (provider + portal + webhooks; emits `lib/payments/<provider>.ts` + webhook route + portal scaffold)
  - Step 22 — **P5 Frontend Architecture** (framework confirm + state mgmt + data layer; emits `package.json` deps + lib skeletons)
  - Step 23 — **P5.3 Design System** (UI lib + tokens; emits shadcn/mui/mantine init + tailwind tokens)
  - Step 24 — **P5.6 UX / Accessibility / Performance** (per-persona surface map + WCAG + Core Web Vitals; emits 3 gates + Lighthouse CI + image optimizer)
  - Step 25 — **i18n / l10n** (locales + routing + translation provider; emits `lib/i18n.ts` + `messages/*` + routing config)

- **6 inline gates** (each: 1 yes/no Q + optional vendor-pick when "yes"; recorded to `phases.<parent>.concerns.<gateName> = { needed, vendor?, notes? }`)
  - Transactional email (Step 11 Auth) — Resend / Postmark / SES / SendGrid
  - SMS (Step 11 Auth) — Twilio / Vonage / MessageBird
  - Marketing email (Step 24 P5.6 UX) — Customer.io / Loops / Resend Audiences / Mailchimp
  - Push notifications (Step 24 P5.6 UX) — FCM / OneSignal / Pusher Beams
  - Product analytics (Step 24 P5.6 UX) — PostHog / Mixpanel / Amplitude / Plausible
  - Feature gating (Step 19 CI/CD) — PostHog feature flags / LaunchDarkly / Flagsmith / GrowthBook

- **CI Draft Review (Step 20)** — auto-renders CI YAML from `stack.language`, `architecturalFraming.frontendFramework`, `cicdAndDelivery.cicd`, `auth.*`, `payments.*` via 3 vetted renderer modules (GHA, GitLab, CircleCI) + LLM fallback for any other provider. User Approve / Adjust / Reject per draft; locked YAML captured in `phases.cicdAndDelivery.lockedYaml`.

- **`render-common.sh`** — shared helper library used by all 16 renderer modules (11 schema + 5 CI). 6 helpers: `_emit_warning`, `_check_pii_encryption`, `_atomic_write`, `_render_handlebars`, `_emit_dependency`, `_validate_jq_path`.

- **5 new schema renderers** (closes R5 O-R5-3) — Mongoose, Drizzle, tRPC, Hasura, Avro.

- **Plugin reshuffle** — P7.5 Plugin Recommendation (Step 21) split from old P10; new P10 Plugin Install (Step 30) moves to wizard end. The shim copies `phases.pluginDiscovery.installed` verbatim into `phases.pluginInstall.installed` for migrating alpha.6 sessions; new sessions initialize to `[]`.

- **`run-migrations.sh`** — generic, table-driven migration runner. Replaces the inline cascade in `/greenfield:pickup`. Supports `--dry-run` (shows diff), `--from`, `--to`, `--state-file`.

- **Pickup `schemaVersion` gate hardening** — reads `.meta.schemaVersion // .schemaVersion // "unknown"` so both nested (canonical since alpha.6) and top-level (legacy) locations work.

## In-flight session migration

Sessions started on alpha.6 (greenfield 3.0.0-alpha.6) auto-migrate to alpha.7 on the next `/greenfield:pickup`:

1. Pickup detects `meta.schemaVersion < "3.0.0-alpha.7"` (accepting both nested + top-level legacy form).
2. Invokes `run-migrations.sh --from alpha.6 --to alpha.7 --state-file <path> --dry-run` first, showing the diff.
3. Prompts user to confirm; on Approve, re-runs without `--dry-run`.
4. Injects `{skipped: true, deferredReason: "session predates Round 6"}` for the 9 new phases.
5. Copies `phases.pluginDiscovery.installed` verbatim into `phases.pluginInstall.installed`.
6. Bumps `meta.schemaVersion` to `"3.0.0-alpha.7"`.
7. Surfaces a notice: "Session migrated. Steps 7, 9, 10, 13, 15, 20, 22, 23, 24, 25, 30 are available via Adjust mode. Inline gates default to `needed: false` and can be revisited in their parent phase."

The migration is **additive and safe** — existing alpha.6 phase data (personas, domainModel, featureRoadmap, schemaDraftReview, etc.) is preserved unchanged. Onboard generation no-ops on skipped phases.

## Generic runner usage

```bash
# Dry-run a migration (shows diff, no writes)
./scripts/run-migrations.sh --from alpha.6 --to alpha.7 --state-file .greenfield/state.json --dry-run

# Apply migration
./scripts/run-migrations.sh --from alpha.6 --to alpha.7 --state-file .greenfield/state.json

# Long chain (auto-walks intermediate versions if --from is older)
./scripts/run-migrations.sh --from alpha.3 --to alpha.7 --state-file .greenfield/state.json --dry-run
```

The runner is table-driven — each `from → to` step lives in a registered migration function. Adding a future alpha.7 → alpha.8 step requires only appending one entry; no `/greenfield:pickup` change.

## Breaking changes

**None.** The bump is purely additive.

- Pre-R6 (alpha.6) projects continue to work — onboard's interactive handoff flow remains the fallback for any artifact whose source phase is `skipped: true`.
- Pre-R6 projects do NOT receive frontend/concern lib skeletons or CI lockedYaml (onboard writes nothing when those phases stay skipped).
- All R1-R5 phases and mechanics remain unchanged.

## Rollback path

If alpha.7 needs reverting:

1. `git revert <merge-commit>` on `develop` reverts code.
2. Released alpha.7 plugin versions on the marketplace stay published (alpha policy) — no recall.
3. In-flight alpha.7 sessions can't auto-downgrade; user can manually edit `state.meta.schemaVersion = "alpha.6"` and re-walk affected phases, or accept the partial state.
4. The 9 new phases are isolated — removing them doesn't affect R1-R5 phases.
5. `render-common.sh` refactor lands as a separate revertable commit; reverting it leaves the R5 + R6 renderers using the previous inline logic (each renderer's helper functions inlined back via the revert).

## Risks captured

| ID | Risk | Mitigation |
|---|---|---|
| R-R6-1 | LLM-fallback CI renderer output quality varies by provider | Hard-required user ack gate before lockedYaml capture; explicit "this is a draft, edit freely" framing in CI Draft Review |
| R-R6-2 | Frontend trio adds ~40+ prompts in heavy/auto-loop mode | Per-phase Q-bank tuned for ~15 Qs heavy / ~8 light; `mode.depth = light` bypasses ~half |
| R-R6-3 | Migration runner mid-chain failure leaves state partially mutated | `--dry-run` default in pickup + atomic per-step write via `.tmp + rename`; failure surfaces error + retry/abort before next step |
| R-R6-4 | Renderer refactor introduces regression in R5 renderers | Refactor commit gated by re-running R5 smoke tests; isolated revertable commit boundary |
| R-R6-5 | Inline gate vendor-list goes stale | Vendor enums versioned in skill files; v3.1 follow-up to add telemetry for promotion gating |
