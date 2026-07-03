#!/usr/bin/env bash
# shellcheck disable=SC1091  # lib.sh sourced at runtime
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"; source "$DIR/lib.sh"
FAILED=0
SKILL="$REPO_ROOT/.claude/skills/doc-audit/SKILL.md"
REF="$REPO_ROOT/.claude/skills/doc-audit/references/completeness-contract.md"

check() { if eval "$2"; then echo "  ok: $1"; else echo "  FAIL: $1"; FAILED=1; fi; }

check "SKILL.md exists"            "[[ -f '$SKILL' ]]"
check "reference exists"           "[[ -f '$REF' ]]"
check "frontmatter name doc-audit" "grep -qE '^name: doc-audit' '$SKILL'"
check "user-invoked only"          "grep -qE '^disable-model-invocation: true' '$SKILL'"
check "invokes the audit script"   "grep -q 'audit-docs.sh' '$SKILL'"
check "re-verify step present"     "grep -qiE 're-?run|re-?verify' '$SKILL'"
check "names surgical fix rule"    "grep -qi 'surgical' '$SKILL'"
check "names index idempotency"    "grep -qiE 'in place|idempotent' '$SKILL'"

exit "$FAILED"
