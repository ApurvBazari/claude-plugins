# Payments Q-bank — Step 15

> **Round:** 6 (Concern phase — between File Uploads and Security)
> **Steps:** 15 (after fileUploads at Step 13, before security at Step 16)
> **Modes:** Heavy ~14 Qs / Light ~7 Qs
> **Auto-loop:** per-persona (P.Q13 over `personas.primary`, with customer-vs-admin surface split)
> **Coupling:** Reads `personas.primary[]`, `privacy.piiFields[]` (PCI scope). Writes `phases.payments.*`. CHECK-R6-3: payments populated ⟹ `privacy.pii.financial=true`.
> **See also:** `personas.q-bank.md`, `privacy.q-bank.md`, `security.q-bank.md`

## Q-bank

### P.Q1 — Payment provider
- **type:** single-select
- **options:** ["stripe", "lemon-squeezy", "paddle", "razorpay", "braintree", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Payment provider? (stripe = global card/wallet leader, dev-first APIs; lemon-squeezy = merchant-of-record for digital goods, handles VAT/sales-tax; paddle = MoR alternative, EU/UK strong; razorpay = India-first with UPI/netbanking; braintree = PayPal-owned, mature for marketplaces; none = no payments in MVP.)"
- **Stores to:** `phases.payments.provider`

### P.Q2 — Billing model
- **type:** single-select
- **options:** ["one-time", "subscription", "usage-based", "marketplace", "hybrid"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Billing model? (one-time = single charge per purchase; subscription = recurring fixed-price plans; usage-based = metered billing on consumption; marketplace = split payments between platform and sellers (Stripe Connect-style); hybrid = mix, e.g. base subscription + usage overage.)"
- **Stores to:** `phases.payments.billingModel`

### P.Q3 — Customer portal
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Expose a self-serve customer portal for billing? (yes = users manage their own payment method, invoices, plan upgrades/cancellations via provider-hosted portal (e.g., Stripe Customer Portal); no = all billing changes go through your support team or custom UI.)"
- **Stores to:** `phases.payments.customerPortal`

### P.Q4 — Tax handling
- **type:** single-select
- **options:** ["provider-managed", "self-managed", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Tax handling? (provider-managed = Stripe Tax / Paddle / Lemon-Squeezy compute and remit VAT/sales-tax for you; self-managed = you calculate rates and file returns yourself (Avalara, TaxJar, or in-house); none = no tax collection in MVP — flag risk if shipping to EU/UK/IN.)"
- **Stores to:** `phases.payments.taxHandling`

### P.Q5 — Dunning strategy
- **type:** single-select
- **options:** ["provider", "custom", "none"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Dunning strategy for failed recurring charges? (provider = use Stripe Smart Retries / provider-native dunning emails; custom = your own retry schedule + email/SMS sequence; none = single attempt, then cancel — bleeds revenue, flag if subscription-heavy.)"
- **Stores to:** `phases.payments.dunning`

### P.Q6 — Webhook strategy
- **type:** single-select
- **options:** ["per-event", "fanout", "queue", "none"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "How will you process provider webhooks? (per-event = handle each webhook inline in the HTTP handler — simple but blocks on slow logic; fanout = HTTP handler validates + dispatches to multiple consumers (audit log, fulfillment, analytics); queue = enqueue to SQS/Redis and ACK fast — recommended for reliability and idempotency; none = no webhook handling, poll provider APIs instead.)"
- **Stores to:** `phases.payments.webhookStrategy`

### P.Q7 — Fraud prevention
- **type:** single-select
- **options:** ["provider-builtin", "sift", "stripe-radar", "custom", "none"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Fraud prevention layer? (provider-builtin = default rules from your PSP, no extra config; sift = third-party ML fraud scoring; stripe-radar = Stripe's tuned ML, often Radar for Teams for custom rules; custom = your own velocity/blocklist rules; none = no explicit fraud layer — high-risk for marketplaces or digital goods.)"
- **Stores to:** `phases.payments.fraudPrevention`

### P.Q8 — Refund flow
- **type:** single-select
- **options:** ["self-serve", "admin-approval", "manual", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Refund flow? (self-serve = customer triggers refund from their portal within a window; admin-approval = customer requests, admin/support approves in dashboard; manual = support runs refunds directly via provider dashboard, no in-app flow; none = no refunds — flag legal risk in many jurisdictions.)"
- **Stores to:** `phases.payments.refundFlow`

### P.Q9 — Currencies & locales
- **type:** multi-select free-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Currencies + locales to support at launch? (e.g., 'USD/en-US', 'EUR/de-DE', 'GBP/en-GB', 'INR/en-IN' — drives provider currency config, price-display formatting, and tax registration scope. Bullet one per line.)"
- **Stores to:** `phases.payments.currencyLocale[]`

### P.Q10 — PCI scope
- **type:** single-select
- **options:** ["saq-a", "saq-a-ep", "saq-d", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "PCI DSS scope? (saq-a = fully outsourced to PSP-hosted pages/iframes, lowest scope; saq-a-ep = e-commerce site redirects/iframes but page is yours — most Stripe Elements / Checkout setups; saq-d = card data touches your servers (you almost never want this); none = no card data at all, e.g., crypto-only or invoice-only. Couples to privacy.pii.financial.)"
- **Stores to:** `phases.payments.compliance.pciScope`

### P.Q11 — SCA / 3DS
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Strong Customer Authentication (SCA / 3D Secure) required? (yes = EU/UK PSD2 in scope, must integrate 3DS challenge flow — provider-managed if using Stripe PaymentIntents / Checkout; no = US-only or B2B exemption applies. When in doubt, yes.)"
- **Stores to:** `phases.payments.compliance.sca`

### P.Q12 — Other regulatory regimes
- **type:** multi-select free-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Other regulatory regimes that apply? (e.g., 'RBI guidelines for India recurring mandates', 'CFPB for US consumer credit', 'MAS for Singapore e-money', 'FinCEN for US money transmission' — bullet one per line; blank if none.)"
- **Stores to:** `phases.payments.compliance.regulatory[]`

### P.Q13 — Payment surfaces (per-persona, customer vs admin)
- **type:** per-persona surface (customer vs admin)
- **showInLight:** true
- **loopOver:** `personas.primary`
- **loopMode:** per-persona
- **isRiskCapture:** false
- **Prompt:** "For persona `{{this.id}}`, what payment surfaces does this persona see? Split by side: **customer surfaces** (e.g., 'checkout page', 'subscription upgrade', 'invoice history', 'add payment method') vs **admin surfaces** (e.g., 'issue refund', 'comp account', 'view MRR', 'manage failed-charge queue'). Leave a side blank if it doesn't apply to this persona."
- **Stores to:** `phases.payments.surfacesByPersona` (free-form per-persona map with `{customer: string[], admin: string[]}` — flag the schema gap; not in T1's schema)

### P.Q14 — Trial duration
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Free trial / introductory period for paid plans? (e.g., '14 days no card', '30 days with card', 'first month $1', 'none' — drives provider trial config + dunning timing for trial-end. Leave blank or 'none' if no trial.)"
- **Stores to:** `phases.payments.trialDuration` (free-form short text — flag the schema gap; not in T1's schema)

### P.Q_RISK — Payments risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "Payments risks? (e.g., 'webhook signature not verified — attacker forges payment_succeeded events', 'idempotency key missing on charge create — double-billing on retry', 'tax handling deferred but EU customers at launch — VAT liability accrues', 'refund window mismatch between provider and product T&Cs', 'PII in payment metadata leaks into logs / analytics', 'subscription cancellation race — user charged after they cancelled')"
- **Stores to:** `phases.payments.qRisks[]` + appends to top-level `risks[]` with `phase: "payments"`
