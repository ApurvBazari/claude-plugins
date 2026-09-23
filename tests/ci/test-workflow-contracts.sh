#!/usr/bin/env bash
# test-workflow-contracts.sh — structural contracts for workflow behaviour CI cannot exercise on a
# PR: claude-code-action v1 inputs, the completion guard, the fork/bot/permission gates on
# review jobs, the audit's no-push shape, and the Dependabot config. Requires python3 + PyYAML.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$ROOT" <<'PY'
import pathlib, sys
import yaml

root = pathlib.Path(sys.argv[1])
wf_dir = root / ".github" / "workflows"
failures = []

def fail(msg):
    failures.append(msg)

def load(path):
    return yaml.safe_load(path.read_text())

CCA = "anthropics/claude-code-action@"
GUARD = ".github/scripts/assert-claude-run-complete.sh"
BETA_ONLY = {"direct_prompt", "model", "max_turns", "timeout_minutes", "mode",
             "custom_instructions", "override_prompt", "anthropic_model",
             "fallback_model", "allowed_tools", "disallowed_tools"}
SAME_REPO = "github.event.pull_request.head.repo.full_name == github.repository"
NOT_BOT_ACTOR = "!endsWith(github.actor, '[bot]')"
NOT_BOT_COMMENT = "github.event.comment.user.type != 'Bot'"
TRUSTED_COMMENTER = "contains(fromJSON('[\"OWNER\",\"MEMBER\",\"COLLABORATOR\"]'), github.event.comment.author_association)"

# Workflows whose claude-code-action use is under contract. Task 4 appends tooling-gap-audit.yml.
CONTRACT_FILES = ["claude.yml", "security-review.yml", "tooling-gap-audit.yml"]

def cca_steps(job):
    return [s for s in job.get("steps", []) if str(s.get("uses", "")).startswith(CCA)]

def guarded(job):
    steps = job.get("steps", [])
    for i, step in enumerate(steps):
        if step.get("id") == "claude" and str(step.get("uses", "")).startswith(CCA):
            for later in steps[i + 1:]:
                env = later.get("env", {}) or {}
                if (GUARD in str(later.get("run", ""))
                        and str(later.get("if", "")).strip() == "always()"
                        and "steps.claude.outputs.conclusion" in str(env.get("CLAUDE_CONCLUSION", ""))
                        and "steps.claude.outputs.execution_file" in str(env.get("CLAUDE_EXECUTION_FILE", ""))):
                    return True
    return False

def claude_args(step):
    return str((step.get("with") or {}).get("claude_args", ""))

# --- every contracted claude-code-action use: v1 inputs only, job has a timeout ---
for name in CONTRACT_FILES:
    wf = load(wf_dir / name)
    for job_id, job in wf["jobs"].items():
        steps = cca_steps(job)
        for step in steps:
            stale = BETA_ONLY & set((step.get("with") or {}).keys())
            if stale:
                fail(f"{name}:{job_id} passes beta-only inputs v1 silently ignores: {sorted(stale)}")
        if steps and "timeout-minutes" not in job:
            fail(f"{name}:{job_id} runs claude-code-action without a job timeout-minutes (v1 dropped timeout_minutes)")

claude = load(wf_dir / "claude.yml")["jobs"]
security = load(wf_dir / "security-review.yml")["jobs"]

# --- automatic PR reviews: tag mode, guard, fork + bot gates ---
for wf_name, jobs, job_id, turns in (("claude.yml", claude, "pr-review", "--max-turns 40"),
                                     ("security-review.yml", security, "auto-security-review", "--max-turns 100")):
    job = jobs[job_id]
    cond = str(job.get("if", ""))
    for needle in ("github.event_name == 'pull_request'", SAME_REPO, NOT_BOT_ACTOR):
        if needle not in cond:
            fail(f"{wf_name}:{job_id} if: is missing `{needle}`")
    if not guarded(job):
        fail(f"{wf_name}:{job_id} has no completion guard after its claude step")
    step = cca_steps(job)[0]
    if (step.get("with") or {}).get("track_progress") is not True:
        fail(f"{wf_name}:{job_id} must set track_progress: true (tag mode keeps one tracking comment)")
    if turns not in claude_args(step):
        fail(f"{wf_name}:{job_id} claude_args must contain `{turns}`")
    if "PR NUMBER:" not in str((step.get("with") or {}).get("prompt", "")):
        fail(f"{wf_name}:{job_id} prompt must name the PR NUMBER")

# --- comment-triggered jobs: trusted humans only ---
for wf_name, jobs, job_id in (("claude.yml", claude, "claude-sonnet"),
                              ("claude.yml", claude, "claude-opus"),
                              ("security-review.yml", security, "security-review")):
    cond = str(jobs[job_id].get("if", ""))
    for needle in (NOT_BOT_COMMENT, TRUSTED_COMMENTER):
        if needle not in cond:
            fail(f"{wf_name}:{job_id} if: is missing `{needle}`")

# --- interactive jobs: trigger phrase, no prompt (tag mode) ---
for job_id, phrase in (("claude-sonnet", "@claude"), ("claude-opus", "@claude-opus")):
    w = cca_steps(claude[job_id])[0].get("with") or {}
    if w.get("trigger_phrase") != phrase:
        fail(f"claude.yml:{job_id} trigger_phrase must be {phrase!r}")
    if "prompt" in w:
        fail(f"claude.yml:{job_id} must not set prompt (a prompt switches a comment job to agent mode)")

# --- @claude security-review: agent mode on PRs only, posts one gh pr comment, guarded ---
job = security["security-review"]
cond = str(job.get("if", ""))
if "github.event.issue.pull_request" not in cond:
    fail("security-review.yml:security-review must only run on PR comments (github.event.issue.pull_request)")
if not guarded(job):
    fail("security-review.yml:security-review has no completion guard after its claude step")
w = cca_steps(job)[0].get("with") or {}
if "track_progress" in w:
    fail("security-review.yml:security-review must not set track_progress (agent mode is the documented path)")
if "Bash(gh pr comment:*)" not in str(w.get("claude_args", "")):
    fail("security-review.yml:security-review must allow Bash(gh pr comment:*) to post its report")

# --- tooling-gap audit: one guarded agent-mode pass, report filed as an issue, never pushes ---
audit_wf = load(wf_dir / "tooling-gap-audit.yml")
audit_on = audit_wf.get("on", audit_wf.get(True, {}))
audit = audit_wf["jobs"]["audit"]
if "schedule" not in audit_on:
    fail("tooling-gap-audit.yml must keep its schedule trigger")
if "ref" not in ((audit_on.get("workflow_dispatch") or {}).get("inputs") or {}):
    fail("tooling-gap-audit.yml workflow_dispatch must accept a `ref` input (branch verification runs)")
if audit_wf.get("permissions") != {"contents": "read", "issues": "write"}:
    fail(f"tooling-gap-audit.yml permissions must be exactly contents: read, issues: write — got {audit_wf.get('permissions')}")
audit_cca = cca_steps(audit)
if len(audit_cca) != 1:
    fail(f"tooling-gap-audit.yml must run exactly one Claude step (two steps overwrite one execution file) — found {len(audit_cca)}")
elif "github_token" not in (audit_cca[0].get("with") or {}):
    fail("tooling-gap-audit.yml Claude step must pass github_token (skips the App-token exchange that rejects branch runs)")
if not guarded(audit):
    fail("tooling-gap-audit.yml has no completion guard after its claude step")
runs = "\n".join(str(s.get("run", "")) for s in audit.get("steps", []))
if "git push" in runs or "git commit" in runs:
    fail("tooling-gap-audit.yml must not commit or push — the report lives in an issue")
for needle in ("onboard/scripts/audit-tooling.sh", ".github/scripts/open-gap-audit-issue.sh"):
    if needle not in runs:
        fail(f"tooling-gap-audit.yml must run {needle}")

if failures:
    print("FAIL: workflow contracts")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)
print("PASS: workflow contracts")
PY
