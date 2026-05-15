# File Uploads — Storage backend: {{fileUploads.storageBackend}}

## Upload flow
- Upload flow: {{fileUploads.uploadFlow}}
- CDN provider: {{fileUploads.cdnProvider}}

## Image transforms
{{fileUploads.imageTransforms}}

## Limits
- Max file size: {{fileUploads.maxFileSize}}
- MIME allowlist:
{{#each fileUploads.mimeAllowlist}}  - {{this}}
{{/each}}

## Security & governance
- Virus scanning: {{fileUploads.virusScanning}}
- PII handling: {{fileUploads.piiHandling}}
- Retention policy: {{fileUploads.retentionPolicy}}
- Multi-tenant isolation: {{fileUploads.multiTenantIsolation}}

## Risks
{{#each fileUploads.qRisks}}- {{this}}
{{/each}}
