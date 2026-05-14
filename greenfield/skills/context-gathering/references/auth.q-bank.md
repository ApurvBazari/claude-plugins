# Auth Q-bank — Step 5

> **Round:** 4 (migrated from R3 consolidated `question-bank.md`)
> **Step:** 5 (Auth & Identity; preceded by Step 4 apiIntegration; gates Step 6 privacy via skip-cascade)
> **Modes:** Heavy ~12 Qs (Auth.Q1–Q12 + Q_RISK) / Light ~5 Qs (foundational subset + Q_RISK; depth Qs use defaults)
> **Coupling:** Auto-loop on the role/permission Q (`loopMode: always`) over `personas.primary` — fires in BOTH auto-loop and hybrid coupling modes. Followed by a non-looped catch-all for system/admin/service roles.
> **Source:** Q content migrated from `question-bank.md` § "Step 5: Auth" (lines 396–588); R4 added Q_RISK + showInLight + loopOver tags + format conversion.
> **See also:** `personas.q-bank.md`, `privacy.q-bank.md`, `security.q-bank.md`, `inline-risk.q-bank.md`, design spec § Distributed Risk + § Coupling matrix.

This phase gathers auth decisions: strategy, provider, sessions, roles (per persona), permissions, MFA, account recovery, cross-tenant rules. Synthesis review fires inline after Auth.Q_RISK. Auth strategy gates the Privacy phase via skip-cascade (`auth.strategy: "none"` → minimal Privacy or n/a).

## Q-bank

### Auth.Q1 — Auth strategy gate

- **type:** single-select
- **options:** ["None — no auth in scope", "Hosted (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito)", "Self-hosted OSS (Keycloak, Authentik, Ory)", "Built-in (framework session/JWT)"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** Always (gate for the rest of Step 5 / auth)
- **R3-updates-path:** `context.phases.auth.strategy`

**Prompt:** "How do you want to handle authentication?"

**Stores to:** `auth.strategy`

**Downstream effects:** Auth.Q2–Auth.Q12 all consume `auth.strategy`. Privacy phase reads `auth.strategy` for the skip-cascade gate. Security phase reads `auth.strategy` for threat surface sizing.

**Skip-cascade:** `none` → fires single-Q gate to Privacy ("Do you collect any user data?"). Yes → reduced Privacy; No → Privacy synthesisStatus='n/a' stub.

**Default:** `"Hosted (Clerk, Auth0, Supabase Auth, Firebase Auth, Cognito)"`
- If `stack.stack.framework: "next"` AND `deployTarget: "vercel"` → `"Hosted (Clerk)"` (greenfield opinion: Clerk is the idiomatic choice for Next on Vercel — drop-in middleware, edge-compatible session tokens, and the richest Next.js SDK on the market)
- If `stack.stack.framework: "django"` → `"Built-in (framework session/JWT)"` (Django auth is first-class and battle-tested; adding a third-party layer without a specific reason adds complexity)
- If `stack.stack.framework: "rails"` → `"Built-in (framework session/JWT)"` (Devise is idiomatic for Rails; the ecosystem assumes it)
- If `stack.stack.framework ∈ (fastapi, express, nestjs)` AND `architecturalFraming.scaleTarget ∈ (production-scale, enterprise)` → `"Hosted (Auth0)"` (greenfield opinion: managed auth eliminates security footguns at production scale — password storage, MFA, session fixation, token rotation are all off your plate)
- If `architecturalFraming.scaleTarget: "hobby"` → `"None — no auth in scope"` (hobby apps rarely need auth at launch; it can be added later)
- Else → `"Hosted (Clerk)"` (greenfield opinion: third-party hosted auth eliminates password/session/MFA security pitfalls and reduces meaningful implementation effort; Clerk has the best DX across the hosted providers)

### Auth.Q2 — Identity providers

- **type:** multi-select
- **options:** ["Email + password", "Google", "GitHub", "Apple", "Microsoft / Azure AD", "SAML SSO (enterprise IdP)", "Magic link (passwordless email)", "Passkeys / WebAuthn", "Phone / SMS OTP", "Anonymous / guest", "None — no IdPs yet"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.idps`

**Prompt:** "Which identity providers should users sign in with?"

**Stores to:** `auth.idps`

**Downstream effects:** Auth.Q10 (password policy) is skipped if `"Email + password"` not in `auth.idps[]`. Privacy.Q2 (PII inventory) auto-includes email when any IdP is selected. Security phase reads `auth.idps[]` for attack-surface sizing.

**Default:** `["Email + password", "Google"]`
- If `architecturalFraming.scaleTarget: "enterprise"` → `["Email + password", "SAML SSO (enterprise IdP)"]` (enterprise apps must support org-wide SSO for IT policy compliance)
- If `stack.stack.framework: "next"` AND `auth.strategy` includes `"Hosted (Clerk)"` → `["Email + password", "Google"]` (Clerk's most common starter combination; Google OAuth covers the majority of consumer sign-in patterns)
- If `appType: "mobile"` OR `architecturalFraming.deploymentShape: "mobile"` → `["Email + password", "Google", "Apple"]` (Apple requires Sign In with Apple for iOS apps that offer any social login; Google covers Android; email+pw for fallback)
- If `architecturalFraming.scaleTarget: "hobby"` → `["Email + password"]` (minimal IdP overhead for early-stage projects)
- If `auth.strategy: "Built-in (framework session/JWT)"` → `["Email + password"]` (built-in auth providers typically only natively manage email+pw; social providers require explicit OAuth library additions)
- Else → `["Email + password", "Google"]` (greenfield opinion: Google OAuth is low-friction to add and covers a large share of real-world users; email+pw as fallback ensures universal accessibility)

### Auth.Q3 — Session model

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.sessionModel`

**Prompt:** "What session model should the app use?"

**Stores to:** `auth.sessionModel`

**Sub-questions:**
- Model (single-select): "Cookie-based sessions (server-managed)" | "JWT (stateless, client-holds-token)" | "Hybrid (short-lived JWT + cookie-backed refresh token)" | "Provider-managed (hosted auth handles it)"
- `accessTokenTtl` (short-text): access token or session lifetime, e.g. `"15m"`
- `refreshTokenStrategy` (single-select): "rotating" | "absolute" | "none"
- `storage` (single-select): "httpOnly-cookie" | "localStorage" | "sessionStorage" | "provider-managed"

**Downstream effects:** Security phase reads `auth.sessionModel.storage` for XSS risk scoring. Auth.Q12 (enforcement point) is influenced by session model (stateless JWT shifts enforcement to the request boundary).

**Default:** Model: `"Hybrid (short-lived JWT + cookie-backed refresh token)"`, `accessTokenTtl: "15m"`, `refreshTokenStrategy: "rotating"`, `storage: "httpOnly-cookie"`
- If `auth.strategy` includes `"Hosted"` → `"Provider-managed (hosted auth handles it)"`, `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "rotating"` (hosted providers manage session complexity; defer to their defaults unless you have a specific override need)
- If `architecturalFraming.topology: "serverless"` → `"JWT (stateless, client-holds-token)"`, `accessTokenTtl: "15m"`, `refreshTokenStrategy: "rotating"`, `storage: "httpOnly-cookie"` (serverless functions can't maintain server-side session stores; JWT enables stateless validation at the edge)
- If `stack.stack.framework: "django"` → `"Cookie-based sessions (server-managed)"`, `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "absolute"` (Django's session engine is mature and handles cookie management correctly out of the box)
- If `stack.stack.framework: "rails"` → `"Cookie-based sessions (server-managed)"`, `storage: "httpOnly-cookie"`, `refreshTokenStrategy: "absolute"` (Rails' signed/encrypted cookie session store is battle-tested)
- If `architecturalFraming.topology: "microservices"` → `"Hybrid (short-lived JWT + cookie-backed refresh token)"`, `accessTokenTtl: "5m"`, `refreshTokenStrategy: "rotating"` (services validate JWTs independently without a shared session store; short TTL limits blast radius on token compromise)
- Else → `"Hybrid (short-lived JWT + cookie-backed refresh token)"`, `accessTokenTtl: "15m"`, `refreshTokenStrategy: "rotating"`, `storage: "httpOnly-cookie"` (greenfield opinion: hybrid is the safest default — short-lived access tokens limit exposure, httpOnly cookie storage prevents XSS token theft, rotating refresh tokens detect replay attacks)

### Auth.Q4 — MFA approach

- **type:** repeating structured
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.mfa`

**Prompt:** "What MFA approach do you want?"

**Stores to:** `auth.mfa`

**Sub-questions:**
- `enforcement` (single-select): "required" | "optional-encouraged" | "optional-silent" | "not-yet"
- `methods` (multi-select): "TOTP (Authenticator app)" | "SMS OTP" | "Email OTP" | "Passkeys / WebAuthn" | "Recovery codes" | "None"
- `gracePeriod` (short-text): days before MFA is enforced after sign-up (only relevant when `enforcement: "required"`)

**Downstream effects:** Security phase reads `auth.mfa.enforcement` for security-posture scoring. Privacy phase reads `auth.mfa.methods` to flag if SMS OTP implies phone PII collection.

**Default:** `enforcement: "optional-encouraged"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]`
- If `dataArchitecture.compliance ∈ (HIPAA, SOC2, PCI-DSS)` → `enforcement: "required"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]`, `gracePeriod: 7` (compliance mandates MFA; TOTP is preferred over SMS for HIPAA/SOC2 because SMS is vulnerable to SIM-swap attacks)
- If `architecturalFraming.scaleTarget: "enterprise"` → `enforcement: "required"`, `methods: ["TOTP (Authenticator app)", "Passkeys / WebAuthn", "Recovery codes"]`, `gracePeriod: 14` (enterprise orgs typically mandate MFA by policy; offer passkeys alongside TOTP for phishing-resistant option)
- If `architecturalFraming.scaleTarget: "production-scale"` → `enforcement: "optional-encouraged"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]` (offer MFA as a strong default for user accounts but don't block onboarding)
- If `architecturalFraming.scaleTarget: "hobby"` → `enforcement: "not-yet"`, `methods: ["None"]` (hobby apps don't justify the MFA implementation and UX cost at launch)
- Else → `enforcement: "optional-encouraged"`, `methods: ["TOTP (Authenticator app)", "Recovery codes"]` (greenfield opinion: offer MFA as an option from day one — retrofitting it later requires migrating active sessions and rebuilding enrollment flows; TOTP + recovery codes is the minimum viable secure combination)

### Auth.Q5 — Authorization model (per persona)

- **type:** single-select
- **options:** ["Flat roles (admin / user / guest)", "RBAC — Role-Based Access Control (roles have permission sets)", "ABAC — Attribute-Based Access Control (policies on user+resource attributes)", "DB-level RLS (Postgres Row-Level Security)", "Hybrid (RBAC + RLS)", "None — no authorization needed"]
- **showInLight:** true
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.authzModel`
- **loopOver:** personas.primary
- **loopMode:** always <!-- fires in both auto-loop and hybrid -->

**Prompt:** "For persona {persona.id} ({persona.name}, {persona.role}): What authorization model and permission set does this persona need?"

**Stores to:** `auth.authzModel`

**answerSchema:** `{ role: string, permissions: [string] }`

**Note:** `"DB-level RLS"` option only shown when `dataArchitecture.engine` includes PostgreSQL/Supabase.

**Downstream effects:** Auth.Q6 (tenant resolution) interacts with authz model when multi-tenant. Security phase reads `auth.authzModel` for privilege-escalation threat surface.

**Default:** `"RBAC — Role-Based Access Control"`
- If `dataArchitecture.multiTenancy ∈ (row-level, schema-per-tenant)` AND `dataArchitecture.engine` includes postgresql or supabase → `"Hybrid (RBAC + RLS)"` (multi-tenant apps need both role-level permission checks and row-level data isolation; RLS without RBAC leaves horizontal privilege escalation vectors open)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"RBAC — Role-Based Access Control"` (enterprise apps always have multiple distinct permission groups; flat roles break down quickly)
- If `dataArchitecture.engine` includes postgresql or supabase AND `dataArchitecture.multiTenancy: "row-level"` → `"DB-level RLS"` (Postgres RLS is the most reliable enforcement point for row-level isolation; defense-in-depth even if app-layer checks are bypassed)
- If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget ∈ (startup, production-scale)` → `"RBAC — Role-Based Access Control"` (most SaaS apps need at minimum admin/member/viewer roles; RBAC is straightforward to implement and reason about)
- If `architecturalFraming.scaleTarget: "hobby"` → `"Flat roles (admin / user / guest)"` (hobby apps rarely need fine-grained permissions; two roles are easier to maintain)
- Else → `"RBAC — Role-Based Access Control"` (greenfield opinion: flat roles collapse into RBAC as soon as a third role is needed; start with RBAC now to avoid a painful refactor when the product grows)

### Auth.Q5_tail — Additional roles (non-persona catch-all)

- **type:** repeating short-text
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"` (fires after Auth.Q5 loop completes)
- **Round 4 addition:** true

**Prompt:** "Any additional roles not bound to a primary persona? (e.g., system, admin, service-account.)"

**Stores to:** `auth.additionalRoles`

**Note:** This catch-all fires once after the Auth.Q5 persona loop completes. It captures system/admin/service-account roles that are infrastructure roles rather than product personas. Leave blank if all roles are covered by the persona loop.

### Auth.Q6 — Tenant resolution

- **type:** single-select
- **options:** ["Subdomain (tenant.app.com)", "Path prefix (/org/slug/...)", "JWT claim (tenant_id in token)", "Custom header (X-Tenant-ID)", "Hybrid (subdomain + claim)"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `dataArchitecture.multiTenancy ≠ "None — single-tenant"` — **SKIP this question entirely if `dataArchitecture.multiTenancy = "None — single-tenant"`**
- **R3-updates-path:** `context.phases.auth.tenantResolution`

**Prompt:** "How should the app resolve tenant identity from a request?"

**Stores to:** `auth.tenantResolution`

**Downstream effects:** Security phase reads `auth.tenantResolution` for tenant-boundary cross-contamination risk. Scaffolding generates middleware templates based on resolution strategy.

**Default:** `"Subdomain (tenant.app.com)"`
- If `architecturalFraming.scaleTarget: "enterprise"` AND `dataArchitecture.multiTenancy: "schema-per-tenant"` → `"Subdomain (tenant.app.com)"` (enterprise customers expect their own subdomain; it also enables per-tenant TLS certificates and CDN rules)
- If `apiIntegration.style: "trpc"` OR `apiIntegration.style: "graphql"` → `"JWT claim (tenant_id in token)"` (tRPC and GraphQL context objects make JWT-claim extraction ergonomic; subdomain routing requires framework-level middleware that's heavier to set up in these stacks)
- If `architecturalFraming.topology: "microservices"` → `"Custom header (X-Tenant-ID)"` (service mesh / API gateway can propagate a canonical tenant header; each service doesn't need to re-parse JWTs or inspect hostnames)
- If `dataArchitecture.multiTenancy: "row-level"` → `"JWT claim (tenant_id in token)"` (RLS policies reference the tenant claim set in the request context; extracting it from the JWT is the lowest-overhead path)
- Else → `"Subdomain (tenant.app.com)"` (greenfield opinion: subdomain-per-tenant is the most explicit isolation signal — it's visible in browser URLs, easy to audit in logs, and makes tenant-boundary violations obvious rather than subtle)

### Auth.Q7 — Service-to-service auth

- **type:** single-select
- **options:** ["API keys (long-lived, secret-manager stored)", "mTLS (mutual TLS client certificates)", "Signed JWTs (short-lived service tokens)", "OIDC workload identity (cloud-native)", "None — services are co-located / same process"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `architecturalFraming.topology = "microservices"` — **SKIP this question entirely if `architecturalFraming.topology ≠ "microservices"`**
- **R3-updates-path:** `context.phases.auth.serviceAuth`

**Prompt:** "How should services authenticate to each other?"

**Stores to:** `auth.serviceAuth`

**Downstream effects:** Security phase reads `auth.serviceAuth` for internal trust boundary threat model. Runtime Operations phase reads `auth.serviceAuth` for secret rotation frequency recommendations.

**Default:** `"Signed JWTs (short-lived service tokens)"`
- If `deployTarget` includes kubernetes OR `architecturalFraming.deploymentShape` includes k8s → `"OIDC workload identity (cloud-native)"` (Kubernetes workload identity via SPIFFE/SPIRE or cloud-provider IAM eliminates long-lived credentials entirely — it's the most secure option for k8s-hosted microservices)
- If `architecturalFraming.scaleTarget: "enterprise"` → `"mTLS (mutual TLS client certificates)"` (enterprise security policies often mandate mTLS for service-to-service; it's the standard in zero-trust network architectures)
- If `architecturalFraming.scaleTarget: "production-scale"` AND `apiIntegration.style: "grpc"` → `"mTLS (mutual TLS client certificates)"` (gRPC already terminates TLS; adding mutual auth is incremental effort with significant security gain)
- If `architecturalFraming.scaleTarget ∈ (startup, production-scale)` → `"Signed JWTs (short-lived service tokens)"` (short-lived JWTs are easier to implement than mTLS, limit blast radius on compromise, and are trivially rotated — a solid production default without the PKI overhead of mTLS)
- If `architecturalFraming.scaleTarget: "hobby"` → `"API keys (long-lived, secret-manager stored)"` (simple and sufficient for internal hobby-scale services; secret-manager storage mitigates the long-lived risk)
- Else → `"Signed JWTs (short-lived service tokens)"` (greenfield opinion: short-lived signed JWTs are the best balance of security and implementation effort for most microservice topologies; they're auditable, revocable via expiry, and require no shared-secret synchronization)

### Auth.Q8 — Account lifecycle

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.lifecycle`

**Prompt:** "How should account lifecycle events be handled?"

**Stores to:** `auth.lifecycle`

**Sub-questions:**
- `signupFlow` (single-select): "open" | "invite-only" | "waitlist" | "admin-approved"
- `emailVerification` (single-select): "required-before-use" | "required-within-grace-period" | "optional" | "n/a-no-email-idp"
- `passwordReset` (single-select): "email-link" | "email-otp" | "admin-only" | "n/a-no-password-idp"
- `accountDeletion` (single-select): "self-serve-immediate" | "self-serve-soft-delete" | "admin-initiated-only" | "support-ticket"
- `accountSuspension` (single-select): "supported" | "not-needed"

**Downstream effects:** Privacy phase reads `auth.lifecycle.accountDeletion` for right-to-erasure flow design. Security phase reads `auth.lifecycle.signupFlow` for account-enumeration attack surface.

**Default:** `signupFlow: "open"`, `emailVerification: "required-before-use"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-soft-delete"`, `accountSuspension: "supported"`
- If `architecturalFraming.scaleTarget: "enterprise"` → `signupFlow: "invite-only"`, `emailVerification: "required-before-use"`, `passwordReset: "email-link"`, `accountDeletion: "admin-initiated-only"`, `accountSuspension: "supported"` (enterprise apps are provisioned via admin workflows, not self-serve signup; account deletion is a compliance event that requires admin oversight)
- If `dataArchitecture.compliance ∈ (GDPR-aware, HIPAA)` → `accountDeletion: "self-serve-soft-delete"` (GDPR right-to-erasure requires user-initiated deletion; soft-delete + anonymization is preferred over hard-delete because it preserves audit trail integrity)
- If `architecturalFraming.scaleTarget: "hobby"` → `signupFlow: "open"`, `emailVerification: "optional"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-immediate"`, `accountSuspension: "not-needed"` (hobby apps prioritize zero-friction onboarding over security theater)
- If `appType ∈ (fullstack, web-app)` AND `architecturalFraming.scaleTarget: "startup"` → `signupFlow: "open"`, `emailVerification: "required-within-grace-period"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-soft-delete"`, `accountSuspension: "supported"` (startup apps need frictionless onboarding but should verify email within 72h to prevent spam accounts; soft-delete preserves data for potential account recovery within a grace window)
- Else → `signupFlow: "open"`, `emailVerification: "required-before-use"`, `passwordReset: "email-link"`, `accountDeletion: "self-serve-soft-delete"`, `accountSuspension: "supported"` (greenfield opinion: require email verification before granting access — it's a low-friction fraud signal; soft-delete is safer than hard-delete because deletion is often a misclick that users regret within 24 hours)

### Auth.Q9 — Account recovery

- **type:** single-select
- **options:** ["Email link only", "Email + phone (SMS)", "Email + recovery codes", "SSO-mediated (org admin resets via IdP)", "Recovery codes only (high-security)", "None — no recovery path"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.recovery`

**Prompt:** "What account recovery options should be available?"

**Stores to:** `auth.recovery`

**Downstream effects:** Privacy phase auto-flags phone number as a PII category if `auth.recovery` includes phone/SMS. Security phase uses recovery method to assess account-takeover surface area.

**Default:** `"Email + recovery codes"`
- If `architecturalFraming.scaleTarget: "enterprise"` AND `auth.idps[]` includes `"SAML SSO (enterprise IdP)"` → `"SSO-mediated (org admin resets via IdP)"` (enterprise accounts are managed by the org's IT admin; self-serve email recovery bypasses organizational access control policies)
- If `dataArchitecture.compliance ∈ (HIPAA, SOC2)` → `"Email + recovery codes"` (high-assurance recovery avoids SMS (SIM-swap risk) while still offering a fallback path; recovery codes are audit-logged events)
- If `auth.mfa.methods` includes `"SMS OTP"` → `"Email + phone (SMS)"` (if SMS is already in scope for MFA, phone recovery is marginal incremental cost and improves recovery success rate)
- If `architecturalFraming.scaleTarget: "hobby"` → `"Email link only"` (simplest path; phone recovery adds Twilio cost and a second PII surface for hobby projects)
- If `auth.idps[]` includes `"Passkeys / WebAuthn"` → `"Email + recovery codes"` (passkeys make device-loss recovery critical; recovery codes are the standard FIDO2 complement)
- Else → `"Email + recovery codes"` (greenfield opinion: email link covers the common case; recovery codes provide a fallback when email access is also lost — e.g., device-reset scenarios. Adding phone recovery should be an explicit opt-in because it introduces phone PII obligations)

### Auth.Q10 — Password policy

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.idps[]` includes `"Email + password"` — **SKIP this question entirely if `"Email + password"` is not in `auth.idps[]`**
- **R3-updates-path:** `context.phases.auth.passwordPolicy`

**Prompt:** "What password policy should be enforced?"

**Stores to:** `auth.passwordPolicy`

**Sub-questions:**
- `minLength` (short-text): integer — minimum password length
- `complexity` (single-select): "none" | "lowercase+uppercase" | "letters+numbers" | "letters+numbers+symbols"
- `breachCheck` (single-select): "hibp-on-signup" | "hibp-on-change" | "hibp-both" | "none"
- `maxAge` (short-text): days before forced password rotation, or `"none"` (most modern guidance discourages rotation unless breached)
- `history` (short-text): number of previous passwords to block re-use, or `"none"`

**Downstream effects:** Security phase reads `auth.passwordPolicy.breachCheck` for authentication security score. Synthesized ADR notes HIBP API dependency.

**Default:** `minLength: 12`, `complexity: "letters+numbers"`, `breachCheck: "hibp-on-signup"`, `maxAge: "none"`, `history: 5`
- If `dataArchitecture.compliance ∈ (HIPAA, SOC2, PCI-DSS)` → `minLength: 12`, `complexity: "letters+numbers+symbols"`, `breachCheck: "hibp-both"`, `maxAge: 90`, `history: 12` (NIST 800-63B + PCI-DSS v4 mandate minimum 12 characters; breached-password checks are explicitly recommended; history prevents cycling; 90-day rotation is still required by PCI-DSS v4 for privileged accounts)
- If `architecturalFraming.scaleTarget: "enterprise"` → `minLength: 12`, `complexity: "letters+numbers"`, `breachCheck: "hibp-both"`, `maxAge: "none"`, `history: 5` (NIST SP 800-63B guidance: long passwords beat complexity rules; breach checks are more effective than rotation; history prevents the "Password1!" / "Password2!" pattern)
- If `auth.strategy` includes `"Hosted"` → `minLength: 8`, `complexity: "none"`, `breachCheck: "hibp-on-signup"`, `maxAge: "none"`, `history: "none"` (hosted providers typically enforce their own password policies; defer to provider defaults; override only for compliance reasons)
- If `architecturalFraming.scaleTarget: "hobby"` → `minLength: 8`, `complexity: "none"`, `breachCheck: "none"`, `maxAge: "none"`, `history: "none"` (hobby apps prioritize frictionless login; full policy adds complexity without meaningful benefit at hobby scale)
- Else → `minLength: 12`, `complexity: "letters+numbers"`, `breachCheck: "hibp-on-signup"`, `maxAge: "none"`, `history: 5` (greenfield opinion: 12-char minimum aligns with NIST 800-63B; HIBP check on signup blocks the top-10K most-breached passwords at zero UX cost; no forced rotation — NIST guidance shows rotation leads to predictable increment patterns, not stronger passwords)

### Auth.Q11 — Auth audit log

- **type:** repeating structured
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.auditLog`

**Prompt:** "What should the auth audit log capture, and for how long?"

**Stores to:** `auth.auditLog`

**Sub-questions:**
- `events` (multi-select): "login-success" | "login-failure" | "logout" | "password-change" | "mfa-enrollment" | "mfa-challenge" | "token-refresh" | "account-created" | "account-deleted" | "role-change" | "permission-escalation" | "api-key-issued" | "api-key-revoked" | "admin-impersonation" | "None"
- `retention` (single-select): "30d" | "90d" | "1y" | "3y" | "7y" | "indefinite" | "none"
- `storage` (single-select): "app-db" | "separate-audit-db" | "log-aggregator (Datadog, Splunk)" | "provider-managed"
- `immutable` (single-select): "yes — append-only / tamper-evident" | "no"

**Downstream effects:** Security phase cross-references `auth.auditLog.retention` for compliance gap analysis. Runtime Operations phase reads `auth.auditLog.storage` for log pipeline configuration.

**Default:** `events: ["login-success", "login-failure", "logout", "password-change", "mfa-enrollment", "role-change", "account-created", "account-deleted"]`, `retention: "90d"`, `storage: "app-db"`, `immutable: false`
- If `dataArchitecture.compliance` includes `"HIPAA"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","admin-impersonation"]`, `retention: "7y"`, `storage: "separate-audit-db"`, `immutable: true` (HIPAA §164.312(b) requires audit controls; 6-year retention minimum rounded to 7y; tamper-evidence is a reasonable safeguard)
- If `dataArchitecture.compliance` includes `"SOC2"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","role-change","permission-escalation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: true` (SOC 2 CC6.x controls require access monitoring; 1y covers typical audit periods; log aggregator enables alerting and anomaly detection)
- If `dataArchitecture.compliance` includes `"PCI-DSS"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "separate-audit-db"`, `immutable: true` (PCI DSS Req 10 mandates comprehensive logging of all cardholder data access and authentication events; 12-month active retention required)
- If `architecturalFraming.scaleTarget: "enterprise"` → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","mfa-challenge","role-change","permission-escalation","admin-impersonation","api-key-issued","api-key-revoked"]`, `retention: "1y"`, `storage: "log-aggregator (Datadog, Splunk)"`, `immutable: true` (enterprise audit requirements even without formal compliance programs; log aggregator integrates with SIEM)
- If `architecturalFraming.scaleTarget: "hobby"` → `events: ["login-failure","account-created","account-deleted"]`, `retention: "30d"`, `storage: "app-db"`, `immutable: false` (minimal logging for hobby apps — login failures help debug auth issues; 30d is sufficient; no overhead of separate storage)
- Else → `events: ["login-success","login-failure","logout","password-change","mfa-enrollment","role-change","account-created","account-deleted"]`, `retention: "90d"`, `storage: "app-db"`, `immutable: false` (greenfield opinion: capture the eight highest-signal events as a baseline — login failures and role changes catch most account-takeover and insider threat patterns; 90d is long enough to investigate incidents without the cost of year-long retention)

### Auth.Q12 — Auth enforcement point

- **type:** multi-select
- **options:** ["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)", "DB-level RLS (Postgres policy)", "API gateway (upstream enforcement before app)", "Service mesh (sidecar policy)", "None — enforced inside handlers"]
- **showInLight:** false
- **isRiskCapture:** false
- **condition:** `auth.strategy ≠ "None — no auth in scope"`
- **R3-updates-path:** `context.phases.auth.enforcementPoint`

**Prompt:** "Where should authentication and authorization be enforced?"

**Stores to:** `auth.enforcementPoint`

**Downstream effects:** Security phase reads `auth.enforcementPoint[]` for defense-in-depth analysis. Scaffolding generates middleware stubs / RLS policy templates based on selected points.

**Default:** `["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)"]`
- If `architecturalFraming.topology: "microservices"` AND `architecturalFraming.scaleTarget: "enterprise"` → `["API gateway (upstream enforcement before app)", "Middleware (global request interceptor)", "Service mesh (sidecar policy)"]` (enterprise microservices require layered enforcement: gateway blocks unauthenticated traffic at the perimeter, middleware enforces per-service policies, sidecar handles lateral movement between services)
- If `architecturalFraming.topology: "microservices"` → `["API gateway (upstream enforcement before app)", "Middleware (global request interceptor)"]` (gateway handles perimeter auth; each service still validates tokens independently — defense-in-depth without the sidecar overhead at startup scale)
- If `dataArchitecture.multiTenancy ∈ (row-level, schema-per-tenant)` AND `dataArchitecture.engine` includes postgresql → `["Middleware (global request interceptor)", "DB-level RLS (Postgres policy)"]` (middleware checks token validity, RLS enforces tenant isolation at the data layer — belt-and-suspenders for multi-tenant data integrity)
- If `auth.sessionModel.storage: "httpOnly-cookie"` AND `architecturalFraming.topology ∈ (monolith, modular-monolith)` → `["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)"]` (monolith with cookie sessions: global middleware handles cookie validation and injects user context, route guards enforce per-endpoint permission rules)
- If `architecturalFraming.topology: "serverless"` → `["Middleware (global request interceptor)", "API gateway (upstream enforcement before app)"]` (serverless functions can't maintain long-lived middleware processes; API gateway offloads cold-start auth overhead; function-level middleware validates the gateway-issued token)
- Else → `["Middleware (global request interceptor)", "Route guards (per-route decorator/handler)"]` (greenfield opinion: middleware + route guards is the most universal combination — middleware handles token extraction and session injection globally, route guards handle permission checks at the resource level. DB-level RLS should be added as a second layer whenever the DB engine supports it)

### Auth.Q_RISK — Auth risk

- **type:** free-text
- **showInLight:** true
- **isRiskCapture:** true
- **required:** true
- **tagSuggestions:** ["security", "compliance"]

**Prompt:** "What's the biggest auth-related risk for THIS project? (e.g., 'JWT-only means revocation latency in compromised-token case', 'no MFA on admin paths', 'social login lock-in to single provider'.)"

**Stores to:** `risks[]` array (new entry with `originatingPhase = "auth"`, id auto-assigned `R-AUTH-1`)

## Mode behavior matrix

| Q ID | Heavy | Light | Notes |
|---|---|---|---|
| Auth.Q1 | ✓ | ✓ | Strategy gate — fundamental |
| Auth.Q2 | ✓ | ✓ | Identity providers — fundamental |
| Auth.Q3 | ✓ | ✓ | Session model — fundamental |
| Auth.Q4 | ✓ | ✓ | MFA approach — fundamental |
| Auth.Q5 | ✓ | ✓ | Authorization model — fundamental (loops per persona; role/permission Q, always mode) |
| Auth.Q5_tail | ✓ | — | Additional non-persona roles catch-all — depth, R4 addition |
| Auth.Q6 | ✓ | — | Tenant resolution — depth, condition-skipped for single-tenant |
| Auth.Q7 | ✓ | — | Service-to-service auth — depth, condition-skipped for non-microservices |
| Auth.Q8 | ✓ | — | Account lifecycle — depth, uses default in light |
| Auth.Q9 | ✓ | — | Account recovery — depth, uses default in light |
| Auth.Q10 | ✓ | — | Password policy — depth, condition-skipped if no email+pw IdP |
| Auth.Q11 | ✓ | — | Auth audit log — depth, uses default in light |
| Auth.Q12 | ✓ | — | Auth enforcement point — depth, uses default in light |
| Auth.Q_RISK | ✓ | ✓ | Always fires |
