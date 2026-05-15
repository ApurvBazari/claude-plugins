# File Uploads & CDN Q-bank — Step 13

> **Round:** 6 (Concern phase — between Auth and Privacy)
> **Steps:** 13 (after auth at Step 11/12, before privacy at Step 14)
> **Modes:** Heavy ~13 Qs / Light ~7 Qs
> **Auto-loop:** per-persona (FU.Q11 over `personas.primary`)
> **Coupling:** Reads `personas.primary[]`, `privacy.piiFields[]`. Writes `phases.fileUploads.*`. Drives `lib/uploads.ts` + S3/R2 IAM policy + MIME allowlist.
> **See also:** `personas.q-bank.md`, `privacy.q-bank.md`

## Q-bank

### FU.Q1 — Storage backend
- **type:** single-select
- **options:** ["s3", "r2", "gcs", "azure-blob", "local", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Object storage backend? (s3 = AWS; r2 = Cloudflare egress-free; gcs = Google Cloud Storage; azure-blob = Azure; local = filesystem for dev/single-node; none = skip file uploads.)"
- **Stores to:** `phases.fileUploads.storageBackend`

### FU.Q2 — Upload flow
- **type:** single-select
- **options:** ["signed-url", "direct", "server-proxied", "multipart-resumable"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Upload flow? (signed-url = backend issues pre-signed PUT, client uploads direct to bucket; direct = client has bucket credentials (rare); server-proxied = bytes flow through your API server; multipart-resumable = chunked + resumable for large files.)"
- **Stores to:** `phases.fileUploads.uploadFlow`

### FU.Q3 — CDN provider
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "CDN provider in front of storage? (e.g., 'cloudfront', 'cloudflare', 'fastly', 'bunny', 'none' — leave blank for bucket-direct.)"
- **Stores to:** `phases.fileUploads.cdnProvider`

### FU.Q4 — Image transforms
- **type:** single-select
- **options:** ["imgix", "cloudinary", "native", "none"]
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Image transformation pipeline? (imgix/cloudinary = managed URL-based transforms; native = roll your own with sharp/libvips; none = serve originals as-is.)"
- **Stores to:** `phases.fileUploads.imageTransforms`

### FU.Q5 — Max file size
- **type:** short-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Max upload size per file? (e.g., '5MB' for avatars, '100MB' for documents, '5GB' for video — drives multipart threshold and bucket policy.)"
- **Stores to:** `phases.fileUploads.maxFileSize`

### FU.Q6 — MIME allowlist
- **type:** multi-select free-text
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "MIME types to allow? (e.g., 'image/jpeg', 'image/png', 'application/pdf' — server-side validation, not just client hints. Bullet one per line.)"
- **Stores to:** `phases.fileUploads.mimeAllowlist[]`

### FU.Q7 — Virus scanning
- **type:** yes/no
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Virus / malware scanning on upload? (e.g., ClamAV sidecar, Lambda trigger, or managed service — recommended whenever users share files with each other.)"
- **Stores to:** `phases.fileUploads.virusScanning`

### FU.Q8 — PII handling
- **type:** single-select
- **options:** ["encrypted-at-rest", "field-level-encryption", "kms-keys", "none"]
- **showInLight:** true
- **isRiskCapture:** false
- **Prompt:** "Encryption for uploads containing PII (reads `privacy.piiFields[]`)? (encrypted-at-rest = bucket-default SSE; field-level-encryption = per-object client-side encryption; kms-keys = customer-managed KMS; none = no encryption beyond TLS in transit.)"
- **Stores to:** `phases.fileUploads.piiHandling`

### FU.Q9 — Retention policy
- **type:** short-text
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Retention policy? (e.g., '30 days then delete', '7 years for compliance', 'indefinite', 'lifecycle: hot→glacier after 90 days' — drives bucket lifecycle rules.)"
- **Stores to:** `phases.fileUploads.retentionPolicy`

### FU.Q10 — Multi-tenant isolation
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Multi-tenant isolation at the storage layer? (separate bucket per tenant, or path-prefix + IAM conditions — prevents cross-tenant object access via guessed URLs.)"
- **Stores to:** `phases.fileUploads.multiTenantIsolation`

### FU.Q11 — Upload surfaces (per-persona)
- **type:** short-text
- **showInLight:** true
- **loopOver:** `personas.primary`
- **loopMode:** per-persona
- **isRiskCapture:** false
- **Prompt:** "For persona `{{this.id}}`, what does this persona upload? (e.g., 'profile avatar', 'support ticket attachments', 'bulk CSV imports', 'product photos' — drives UI surfaces + per-persona size/type policies.)"
- **Stores to:** `phases.fileUploads.uploadSurfacesByPersona` (free-form per-persona map — flag the schema gap; not in T1's schema)

### FU.Q12 — Signed URL expiry
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Use short-lived signed URL expiry for reads/writes? (yes = default 5min TTL on signed URLs to limit replay window; no = longer-lived or unsigned URLs.)"
- **Stores to:** `phases.fileUploads.signedUrlExpiry` (default 5min — free-form; flag the schema gap, not in T1's schema)

### FU.Q13 — Allow overwrite
- **type:** yes/no
- **showInLight:** false
- **isRiskCapture:** false
- **Prompt:** "Allow overwriting existing objects at the same key? (yes = PUT replaces in place; no = bucket versioning or unique-key-per-upload required — prevents accidental data loss but increases storage cost.)"
- **Stores to:** `phases.fileUploads.allowOverwrite` (free-form — flag the schema gap, not in T1's schema)

### FU.Q_RISK — File-upload risks
- **type:** bulleted free-text
- **isRiskCapture:** true
- **showInLight:** true
- **Prompt:** "File-upload & CDN risks? (e.g., 'signed URL leaked via referrer header allows public access', 'MIME-type spoofing bypasses image-only filter', 'CDN cache poisoning serves attacker-uploaded HTML', 'multipart upload abandonment fills bucket with orphan chunks')"
- **Stores to:** `phases.fileUploads.qRisks[]` + appends to top-level `risks[]` with `phase: "fileUploads"`
