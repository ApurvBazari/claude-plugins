# Render module: `phases.fileUploads` → file upload infrastructure

## When to render

- `phases.fileUploads.skipped == true` → SKIP this module (no-op).
- `phases.fileUploads.storageBackend == "none"` → SKIP.
- Else → render the artifacts below.

## Output paths

| File | Condition | Content |
|---|---|---|
| `lib/uploads.ts` | always (when not skipped) | TS client for the chosen storage backend |
| `lib/uploads/iam-policy.json` | `storageBackend` ∈ `{"s3", "r2", "gcs"}` | least-privilege IAM template |
| `lib/uploads/mime-allowlist.ts` | always | typed allowlist derived from `acceptedMimeTypes[]` |

## lib/uploads.ts template

```typescript
// Upload client for ${phases.fileUploads.storageBackend}
// Strategy: ${phases.fileUploads.uploadStrategy}  // "direct-to-storage" | "via-app-server"
// Max size: ${phases.fileUploads.maxSizeMb} MB
// Virus scanning: ${phases.fileUploads.virusScanning ? "enabled" : "disabled"}

import { MIME_ALLOWLIST, type AllowedMime } from "./uploads/mime-allowlist";

export type UploadIntent = {
  filename: string;
  mime: AllowedMime;
  sizeBytes: number;
  ownerId?: string;
};

export async function createUploadUrl(intent: UploadIntent): Promise<{
  uploadUrl: string;
  publicUrl: string;
  key: string;
}> {
  // Presigned URL flow (direct-to-storage) OR multipart proxy (via-app-server)
  return { uploadUrl: "", publicUrl: "", key: "" };
}

export async function completeUpload(key: string): Promise<void> {
  // Optional post-upload hook (scan, transcode, persist metadata)
}
```

When `storageBackend` is `s3` / `r2` / `gcs` / `azure-blob` / `supabase-storage` / `vercel-blob`: emit the corresponding client init using the established SDK.

## lib/uploads/iam-policy.json template (S3 / R2)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPresignedPutForUploadsPrefix",
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:PutObjectAcl"],
      "Resource": "arn:aws:s3:::${phases.fileUploads.bucketName}/uploads/*"
    },
    {
      "Sid": "AllowReadForPublicAssets",
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::${phases.fileUploads.bucketName}/public/*"
    }
  ]
}
```

For `gcs`: emit the equivalent IAM Conditions / Workload Identity binding template.

## lib/uploads/mime-allowlist.ts template

```typescript
// Generated from phases.fileUploads.acceptedMimeTypes
export const MIME_ALLOWLIST = ${JSON.stringify(phases.fileUploads.acceptedMimeTypes)} as const;
export type AllowedMime = (typeof MIME_ALLOWLIST)[number];

export function isAllowed(mime: string): mime is AllowedMime {
  return (MIME_ALLOWLIST as readonly string[]).includes(mime);
}
```

## Backward compatibility

- `phases.fileUploads.skipped == true` → no files written; no error.
- `phases.fileUploads.storageBackend == "none"` → same as skipped.
- If `lib/uploads.ts` already exists, emit `lib/uploads.generated.ts` alongside and surface a merge note rather than clobbering.
