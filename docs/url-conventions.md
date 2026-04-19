# Documentation URL Conventions

When referencing Claude Code documentation in any plugin file (skills, agents, READMEs, internal references, hook prompts), use the **current home** at `https://code.claude.com/docs/en/*`.

## Why this matters

The legacy URLs at `https://docs.anthropic.com/en/docs/claude-code/*` 301-redirect to the new `code.claude.com` domain. Some `WebFetch` implementations don't follow redirects automatically — when a skill (e.g., `onboard:update`) tries to fetch the legacy URL, it gets the redirect response and either retries (wasting turns) or fails entirely. The 2026-04-16 release-gate Phase 4 test (finding A6) hit this: `onboard:update` wasted 4 turns on the redirect chain before settling on the canonical URL.

## Mapping

| Legacy (do not use) | Current (use this) |
|---|---|
| `https://docs.anthropic.com/en/docs/claude-code` | `https://code.claude.com/docs/en` |
| `https://docs.anthropic.com/en/docs/claude-code/overview` | `https://code.claude.com/docs/en/overview` |
| `https://docs.anthropic.com/en/docs/claude-code/hooks` | `https://code.claude.com/docs/en/hooks` |
| `https://docs.anthropic.com/en/docs/claude-code/skills` | `https://code.claude.com/docs/en/skills` |
| `https://docs.anthropic.com/en/docs/claude-code/sub-agents` | `https://code.claude.com/docs/en/sub-agents` |
| `https://docs.anthropic.com/en/docs/claude-code/mcp` | `https://code.claude.com/docs/en/mcp` |
| `https://docs.anthropic.com/en/docs/claude-code/plugins` | `https://code.claude.com/docs/en/plugins` |
| `https://docs.anthropic.com/en/docs/claude-code/settings` | `https://code.claude.com/docs/en/settings` |
| `https://docs.anthropic.com/en/docs/claude-code/output-styles` | `https://code.claude.com/docs/en/output-styles` |
| `https://docs.anthropic.com/en/docs/claude-code/headless` | `https://code.claude.com/docs/en/headless` |
| `https://docs.anthropic.com/en/docs/claude-code/github-actions` | `https://code.claude.com/docs/en/github-actions` |

The path suffix is preserved unchanged — only the domain + `/en/docs/claude-code` prefix changes to `code.claude.com/docs/en`.

## Enforcement

A repo-wide grep for the legacy prefix should return zero matches:

```bash
grep -rnE "docs\\.anthropic\\.com/en/docs/claude-code" .
```

If the grep finds a match, replace it with the `code.claude.com` equivalent. If you spot a legacy URL during PR review, flag it as a blocker — the redirect costs real turns when fetched programmatically.

If a new doc page lands at `code.claude.com` that didn't exist at the legacy URL, just use the new URL directly — there's no migration concern for new content.

## Verification before commit

After any URL replacement, list unique URLs in the repo and verify each resolves with HTTP 200 (no 4xx/5xx):

```bash
grep -rhoE "https://code\\.claude\\.com/docs/en[^[:space:]\")]+" . \
  | sort -u \
  | while read u; do
      curl -s -o /dev/null -w "%{http_code} %{url_effective}\n" -L "$u"
    done
```

All entries should print `200`. Any other status code is a typo in the path or a real broken link to fix before commit.
