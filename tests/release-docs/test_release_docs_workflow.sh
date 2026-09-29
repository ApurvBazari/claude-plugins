#!/usr/bin/env bash
# test_release_docs_workflow.sh — static contracts for .github/workflows/release-docs.yml and the
# "Docs Obligations" gate in validate.yml (release-docs spec § 7 and § 13 A3; SDD rulings R22, R24,
# R26, R27).
#
# The workflow can't be exercised before it merges, so this belt pins the safety properties the
# probes and reviews established:
# - the model runs only on workflow_dispatch; the pull_request path only detects and dispatches;
# - untrusted build, trusted publish: the model's job (sync) is read-only and never names the PAT;
#   its one product is a bundle (a binary patch against the start commit); a fresh publish job that
#   runs no model checks out the commit detect saw, snapshots and copies its scripts before applying
#   the patch, re-runs the full post-checks with --expect-clean, and alone holds DOCS_BOT_TOKEN;
# - in sync: the snapshot, a read-only copy of the scripts and the before-report are made in
#   $RUNNER_TEMP before the model runs, sealed, and verified afterwards with git's state; its
#   post-checks run from that copy with --expect-clean;
# - a tree moves on only with post-checks exit 0 or 1 and a report that opens with the write fence's
#   result; no force-add; --verifier is always passed; the action pin, model, token and tool
#   allowlist are the probed ones.
#
# The workflow is read with a small indentation-based reader, so the belt runs without PyYAML.
# When PyYAML is importable (CI installs it), the reader is also checked against it, and the
# YAML-only checks run. RELEASE_DOCS_BELT_NO_YAML=1 forces the reader-only mode.
#
# Every check is proved able to fail on its own target: a self-test applies one mutation per check
# to a scratch copy and requires that check, by id, to report it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$ROOT" <<'PY'
import os
import re
import shutil
import sys
import tempfile

ROOT = sys.argv[1]
try:
    if os.environ.get("RELEASE_DOCS_BELT_NO_YAML"):
        raise ImportError("forced off")
    import yaml
except ImportError:
    yaml = None

WF = ".github/workflows/release-docs.yml"
VAL = ".github/workflows/validate.yml"
FENCE = ".claude/skills/release-docs/scripts/docs-lib/fence.py"
POST = ".claude/skills/release-docs/scripts/post-checks.sh"
FILES = (WF, VAL, FENCE, POST)
CCA = "anthropics/claude-code-action@756cc22e19660d20e8cc9496b4f242475a7f7790"
RD = ".claude/skills/release-docs/scripts/"
SCRIPT_RULES = ["Bash(bash %s%s:*)" % (RD, s)
                for s in ("docs-detect.sh", "post-checks.sh", "render-check.sh", "og-regen.sh")]
OTHER_BASH = ["Bash(node --check:*)", "Bash(git diff:*)", "Bash(git status:*)"]
TOOLS = ["Read", "Edit", "Write", "Glob", "Grep", "Agent", "Task", "Skill"]
STEP = r"(?:      - |        )"
BLOCK = re.compile(r"^[|>][-+]?$")


# ---------------------------------------------------------------- the reader
def field(raw, key, lead):
    """The value of `key:` on a line starting with `lead` (a regex), block scalars included."""
    m = re.search(r"^%s%s:[ \t]*(.*)$" % (lead, re.escape(key)), raw, re.M)
    if not m:
        return None
    v = m.group(1).strip()
    if not BLOCK.match(v):
        return v
    out, ind = [], None
    for ln in raw[m.end():].split("\n")[1:]:
        if not ln.strip():
            if ind is not None:
                out.append("")
            continue
        cur = len(ln) - len(ln.lstrip(" "))
        if ind is None:
            ind = cur
        if cur < ind:
            break
        out.append(ln[ind:])
    while out and out[-1] == "":
        out.pop()
    return " ".join(out) if v.startswith(">") else "\n".join(out) + "\n"


def jobs_of(text):
    m = re.search(r"^jobs:[ \t]*$", text, re.M)
    body = text[m.end():] if m else ""
    parts = re.split(r"^  ([A-Za-z0-9_-]+):[ \t]*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts), 2)}


def steps_of(job_raw):
    m = re.search(r"^    steps:[ \t]*$", job_raw, re.M)
    if not m:
        return []
    return ["      - " + c for c in re.split(r"^      - ", job_raw[m.end():], flags=re.M)[1:]]


def unwrap(expr):
    s = " ".join(str(expr or "").split())
    if s.startswith("${{") and s.endswith("}}"):
        s = s[3:-2].strip()
    return s


def joined(run):
    """A run with backslash continuations joined, and "$T/" read as "$RUNNER_TEMP/" when the run
    sets T="$RUNNER_TEMP"."""
    run = run or ""
    if re.search(r'^T="\$RUNNER_TEMP"$', run, re.M):
        run = run.replace('"$T/', '"$RUNNER_TEMP/').replace('"$T"', '"$RUNNER_TEMP"')
    return re.sub(r"[ \t]*\\\n\s*", " ", run)


def model(text):
    jobs = {}
    for jid, raw in jobs_of(text).items():
        head = raw.split("\n    steps:")[0]
        steps = []
        for sraw in steps_of(raw):
            get = lambda k, s=sraw: field(s, k, STEP)
            uses = get("uses")
            steps.append({"raw": sraw, "id": get("id"), "name": get("name"), "if": get("if"),
                          "uses": uses.split(" #")[0].strip() if uses else None,
                          "run": get("run"), "j": joined(get("run"))})
        jobs[jid] = {"raw": raw, "head": head, "if": field(head, "if", "    "),
                     "name": field(head, "name", "    "), "steps": steps}
    return jobs


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


class Ctx:
    def __init__(self, root):
        self.text = read(root, WF)
        self.wf = model(self.text)
        self.vtext = read(root, VAL)
        self.val = model(self.vtext)
        self.fence = read(root, FENCE)
        self.post_sh = read(root, POST)
        self.y = yaml.safe_load(self.text) if yaml else None
        self.yval = yaml.safe_load(self.vtext) if yaml else None
        empty = {"steps": [], "raw": "", "head": "", "if": None, "name": None}
        self.sync = self.wf.get("sync", empty)
        self.publish = self.wf.get("publish", empty)

    def step(self, sid, job="sync"):
        return next((s for s in (self.sync if job == "sync" else self.publish)["steps"] if s["id"] == sid), None)

    def index(self, pred):
        return next((i for i, s in enumerate(self.sync["steps"]) if pred(s)), None)

    def claude_index(self):
        return self.index(lambda s: (s["uses"] or "").startswith("anthropics/claude-code-action@"))

    def claude(self):
        i = self.claude_index()
        return None if i is None else self.sync["steps"][i]

    def claude_args(self):
        c = self.claude()
        return field(c["raw"], "claude_args", "          ") if c else ""

    def allowed(self):
        m = re.search(r'--allowedTools\s+"([^"]*)"', self.claude_args() or "")
        return re.findall(r"(?:[^,(]|\([^)]*\))+", m.group(1)) if m else []

    def after_claude(self):
        i = self.claude_index()
        return [] if i is None else self.sync["steps"][i + 1:]


def pos(steps, pattern):
    """(step index, line index) of the first run line matching pattern."""
    for i, s in enumerate(steps):
        for k, ln in enumerate((s["j"] or "").split("\n")):
            if re.search(pattern, ln):
                return (i, k)
    return None


def code(raw):
    """raw without its comment lines."""
    return "\n".join(ln for ln in (raw or "").split("\n") if not ln.lstrip().startswith("#"))


GITC = r"\bgit\b((?:\s+-c\s+(?:[^\s\"]|\"[^\"]*\")+)*)\s+"


def perms_of(text, ind):
    """The `permissions:` map at indentation `ind` in text (a job head, or the workflow's top)."""
    m = re.search(r"^%spermissions:[ \t]*(.*)$" % ind, text, re.M)
    if not m:
        return None
    if m.group(1).strip():
        return m.group(1).strip()
    out = {}
    for ln in text[m.end():].split("\n")[1:]:
        mm = re.match(r"^%s  ([a-z-]+):[ \t]*(\S+)[ \t]*$" % ind, ln)
        if not mm:
            break
        out[mm.group(1)] = mm.group(2)
    return out


def fn_text(run, name):
    m = re.search(r"^%s\(\) [({]\n.*?^[)}]$" % re.escape(name), run or "", re.M | re.S)
    return m.group(0) if m else None


# ---------------------------------------------------------------- the checks
CHECKS = []


def check(cid, desc, yaml_only=False):
    def deco(fn):
        CHECKS.append((cid, desc, yaml_only, fn))
        return fn
    return deco


def lines_of(steps, needle):
    return [ln for s in steps for ln in (s["j"] or "").split("\n") if needle in ln]


def gate_checks(g, report, who):
    """The fence-line gate, shared by sync's and publish's gate steps."""
    gj = (g or {}).get("j") or ""
    f = []
    for need in ('report="$RUNNER_TEMP/%s"' % report, 'fence_line="$(head -n 1 "$report")"',
                 '"- ok: write fence") ;;', '"- FAIL: "*|"- FENCE: "*) [ "$POST_RC" = 1 ] || refuse'):
        if need not in gj:
            f.append("%s's gate step lacks %r" % (who, need))
    if not re.search(r"^\s*\*\) refuse ", gj[max(gj.find('case "$fence_line"'), 0):], re.M):
        f.append("%s's gate step does not refuse a report that opens with anything else" % who)
    if '[ -f "$report" ] && [ ! -L "$report" ] || refuse' not in gj:
        f.append("%s's gate step does not refuse a missing report" % who)
    if not re.search(r'case "\$POST_RC" in\s+0\|1\) ;;\s+\*\) refuse ', gj):
        f.append("%s's gate step does not refuse a post-checks exit other than 0 or 1" % who)
    return f


@check("A1", "sync runs only on workflow_dispatch")
def a1(c):
    want = "github.event_name == 'workflow_dispatch' && needs.detect.outputs.open != '0'"
    got = unwrap(c.sync.get("if"))
    return [] if got == want else ["sync if: is %r, want %r" % (got, want)]


@check("A2", "the pull_request path only detects and dispatches")
def a2(c):
    f = []
    if set(c.wf) != {"detect", "dispatch", "sync", "publish"}:
        f.append("jobs are %s, want exactly detect, dispatch, sync, publish" % sorted(c.wf))
    on = c.text[c.text.find("\non:"):c.text.find("\npermissions:")]
    for need in ("  pull_request:\n    types: [opened, reopened, synchronize]\n    branches: [main]\n",
                 "  workflow_dispatch:\n", "      dry_run:\n", "      release_pr:\n"):
        if need not in on:
            f.append("the on: block lacks %r" % need.strip())
    for bad in ("pull_request_target", "push:", "issue_comment", "workflow_run", "repository_dispatch",
                "schedule"):
        if bad in on:
            f.append("the on: block has %s" % bad)
    dif = unwrap(c.wf.get("detect", {}).get("if"))
    for need in ("github.event_name == 'workflow_dispatch' ||", "github.head_ref == 'develop' &&",
                 "github.event.pull_request.head.repo.full_name == github.repository"):
        if need not in dif:
            f.append("detect if: lacks %r" % need)
    dis = c.wf.get("dispatch", {"steps": [], "raw": ""})
    want = "github.event_name == 'pull_request' && needs.detect.outputs.open != '0'"
    if unwrap(dis.get("if")) != want:
        f.append("dispatch if: is %r, want %r" % (unwrap(dis.get("if")), want))
    if any(s["uses"] for s in dis["steps"]):
        f.append("the dispatch job uses an action (it must only run gh workflow run)")
    runs = " ".join(s["j"] or "" for s in dis["steps"])
    for need in ("gh workflow run release-docs.yml", "--ref develop", "-f dry_run=false",
                 '-f release_pr="$RELEASE_PR"'):
        if need not in runs:
            f.append("the dispatch job does not run %r" % need)
    for jid in ("detect", "dispatch"):
        if "secrets." in c.wf.get(jid, {}).get("raw", ""):
            f.append("%s reads a secret" % jid)
    for jid, job in c.wf.items():
        if jid not in ("detect", "dispatch") and \
                not unwrap(job.get("if")).startswith("github.event_name == 'workflow_dispatch' &&"):
            f.append("%s can run outside workflow_dispatch" % jid)
    return f


@check("A3", "sync's snapshot goes to $RUNNER_TEMP first, before the branch and before the model")
def a3(c):
    f, steps = [], c.sync["steps"]
    snap = pos(steps, r'^bash \.claude/skills/release-docs/scripts/post-checks\.sh --snapshot "\$RUNNER_TEMP/before\.snap"$')
    if snap is None:
        return ['no `post-checks.sh --snapshot "$RUNNER_TEMP/before.snap"` line in the sync job']
    for what, pat in (("git switch -c", r"\bgit switch -c "), ("the run dir", r"mkdir -p \.release-docs/run"),
                      ("the scripts copy", r"^cp -R .* \"\$RUNNER_TEMP/rd\"$")):
        p = pos(steps, pat)
        if p is None or not snap < p:
            f.append("the snapshot is not taken before %s" % what)
    ci = c.claude_index()
    if ci is None or not snap[0] < ci:
        f.append("the snapshot is not taken before the Claude step")
    lines = (steps[snap[0]]["j"] or "").split("\n")[:snap[1]]
    if any(ln.strip() and not re.match(r"^(set -|shopt -s|T=\"\$RUNNER_TEMP\"$)", ln) for ln in lines):
        f.append("the snapshot is not the first command of its step")
    for s in steps[:snap[0]]:
        if re.search(r"\bgit (switch|checkout|add|commit)\b|mkdir|\bcp\b|\.release-docs", s["j"] or ""):
            f.append("a step before the snapshot writes to the checkout: %s" % (s["name"] or s["uses"]))
    if len(lines_of(steps, "--snapshot")) != 1:
        f.append("sync takes %d snapshots, want 1" % len(lines_of(steps, "--snapshot")))
    return f


@check("A4", "sync's post-checks use --expect-clean against the sealed snapshot")
def a4(c):
    p = c.step("post")
    want = 'post-checks.sh" --before "$RUNNER_TEMP/before.snap" --expect-clean'
    return [] if p and want in (p["j"] or "") else ["the post step does not run %r" % want]


@check("A5", "sync's report and shots are written under $RUNNER_TEMP, to paths cleared first")
def a5(c):
    j = (c.step("post") or {}).get("j") or ""
    f = []
    for need in ('--report "$RUNNER_TEMP/post-checks.md"', '--shots "$RUNNER_TEMP/shots"'):
        if need not in j:
            f.append("the post step lacks %s" % need)
    clear = j.find('rm -rf "$RUNNER_TEMP/post-checks.md" "$RUNNER_TEMP/shots"')
    if clear < 0 or clear > j.find("post-checks.sh"):
        f.append("the post step does not clear the report and shots paths before post-checks runs")
    return f


@check("A6", "publish pushes only when its gate passed and its post-checks exited 0 or 1")
def a6(c):
    f = []
    pushers = [(jid, s) for jid, j in c.wf.items() for s in j["steps"]
               if re.search(r"\bgit\b[^\n]*\bpush\b", s["j"] or "")]
    if len(pushers) != 1 or pushers[0][0] != "publish":
        return ["the steps that push are %s, want exactly one, in publish" % [(j, s["name"]) for j, s in pushers]]
    ps = pushers[0][1]
    want = ("!cancelled() && steps.gate.outputs.publish == 'true' && steps.stage.outcome == 'success' && "
            "(steps.post.outputs.rc == '0' || steps.post.outputs.rc == '1')")
    if unwrap(ps["if"]) != want:
        f.append("the push step's if: is %r, want %r" % (unwrap(ps["if"]), want))
    if not re.search(r'^case "\$POST_RC" in 0\|1\) ;; \*\) .*exit 1 ;; esac$', ps["j"] or "", re.M):
        f.append("the push step does not refuse a post-checks exit other than 0 or 1")
    for jid, j in c.wf.items():
        for s in j["steps"]:
            if s is not ps and re.search(GITC + r"commit\b|\bgh pr (create|edit)\b", s["j"] or ""):
                f.append("%s/%r commits or opens a PR outside the push step" % (jid, s["name"] or s["id"]))
            if re.search(r"\bgh pr (close|comment)\b", s["j"] or "") and \
                    (jid != "publish" or "steps.push.outputs.url != ''" not in unwrap(s["if"])):
                f.append("%s/%r closes or comments on PRs without a pushed docs PR" % (jid, s["name"] or s["id"]))
    gj = (c.step("gate", "publish") or {}).get("j") or ""
    if 'echo "publish=true"' not in gj or gj.find('echo "publish=true"') < gj.find('case "$POST_RC"'):
        f.append("publish's gate step can set publish=true before checking the post-checks exit")
    f += gate_checks(c.step("gate", "publish"), "pc.md", "publish")[-1:]
    return f


@check("A7", "no force-add anywhere in release-docs.yml")
def a7(c):
    f = []
    for ln in joined(c.text).split("\n"):
        for m in re.finditer(GITC + r"add\b(.*)", ln):
            args = re.split(r"\s*(?:;|&&|\|\||\|)\s*", m.group(2))[0].split()
            if any(a == "--force" or re.match(r"^-[A-Za-z]*f[A-Za-z]*$", a) for a in args):
                f.append("force-add: %s" % ln.strip())
    return f


@check("A8", "the PR body always passes --verifier")
def a8(c):
    lines = [ln for j in c.wf.values() for ln in lines_of(j["steps"], "--pr-body")]
    f = []
    if len(lines) != 1 or not lines_of(c.publish["steps"], "--pr-body"):
        f.append("%d --pr-body commands, want 1, in publish" % len(lines))
    elif not re.search(r'--verifier "\$RUNNER_TEMP/sync/verifier\.json"', lines[0]):
        f.append("the --pr-body command does not pass the bundle's --verifier unconditionally")
    elif re.match(r"^\s*(if|\[|\[\[|test)\b", lines[0]) or "&&" in lines[0].split("--pr-body")[0]:
        f.append("the --pr-body command is conditional")
    if re.search(r"\w+\+=\(", c.text):
        f.append("arguments are assembled conditionally (+=)")
    return f


@check("A9", "the Claude step passes github_token")
def a9(c):
    cl = c.claude()
    v = field(cl["raw"], "github_token", "          ") if cl else None
    return [] if v == "${{ github.token }}" else ["the Claude step's github_token is %r" % v]


@check("A10", "claude-code-action is pinned to v1.0.235")
def a10(c):
    uses = [s for s in c.sync["steps"] if (s["uses"] or "").startswith("anthropics/claude-code-action@")]
    if len(uses) != 1:
        return ["%d Claude steps in sync, want 1" % len(uses)]
    ok = uses[0]["uses"] == CCA and re.search(r"uses: %s # v1\.0\.235$" % re.escape(CCA), uses[0]["raw"], re.M)
    return [] if ok else ["the Claude step is not %s # v1.0.235" % CCA]


@check("A11", "the model is claude-opus-5-5")
def a11(c):
    ok = re.findall(r"--model\s+(\S+)", c.claude_args() or "") == ["claude-opus-5-5"]
    return [] if ok else ["claude_args --model is not exactly claude-opus-5-5"]


@check("A12", "both Agent and Task are allowed")
def a12(c):
    have = c.allowed()
    return [] if "Agent" in have and "Task" in have else ["--allowedTools lacks Agent or Task: %s" % have]


@check("A13", "validate.yml has the Docs Obligations job, gated on PRs to main")
def a13(c):
    jobs = [j for j in c.val.values() if j["name"] == "Docs Obligations"]
    if len(jobs) != 1:
        return ["%d Docs Obligations jobs in validate.yml, want 1" % len(jobs)]
    j, f = jobs[0], []
    want = "github.event_name == 'pull_request' && github.base_ref == 'main'"
    if unwrap(j["if"]) != want:
        f.append("Docs Obligations if: is %r, want %r" % (unwrap(j["if"]), want))
    runs = [s["j"].strip() for s in j["steps"] if s["j"]]
    if runs != ["bash .claude/skills/release-docs/scripts/docs-detect.sh --range origin/main..HEAD --gate"]:
        f.append("Docs Obligations does not run exactly the detector's --gate: %s" % runs)
    if "fetch-depth: 0" not in j["raw"]:
        f.append("Docs Obligations checks out without fetch-depth: 0 (origin/main would be missing)")
    return f


@check("A14", "after the model, sync runs only its sealed copies: post-checks from $RUNNER_TEMP/rd")
def a14(c):
    f = []
    if 'bash "$RUNNER_TEMP/rd/post-checks.sh"' not in ((c.step("post") or {}).get("j") or ""):
        f.append("sync's post-checks do not run from $RUNNER_TEMP/rd")
    for s in c.after_claude():
        if re.search(r"\.claude/skills/release-docs/scripts/|\.github/scripts/", s["j"] or ""):
            f.append("%r runs a script from the checkout after the model" % (s["name"] or s["id"]))
    if 'cp -R .claude/skills/release-docs/scripts "$RUNNER_TEMP/rd"' not in ((c.step("prepare") or {}).get("j") or ""):
        f.append("sync's prepare step does not copy the scripts to $RUNNER_TEMP/rd")
    return f


@check("A15", "sync's sealed copies are made read-only before the model runs")
def a15(c):
    pj = (c.step("prepare") or {}).get("j") or ""
    m = re.search(r"^chmod -R a-w (.*)$", pj, re.M)
    if not m:
        return ["sync's prepare step has no chmod -R a-w"]
    f = []
    for need in ('"$RUNNER_TEMP/rd"', '"$RUNNER_TEMP/before.snap"', '"$RUNNER_TEMP/obligations.before.json"',
                 '"$RUNNER_TEMP/assert-claude-run-complete.sh"'):
        if need not in m.group(1):
            f.append("chmod -R a-w does not cover %s" % need)
    at = m.start()
    for last in ('--out "$RUNNER_TEMP/obligations.before.json"', ".release-docs/run/"):
        if pj.find(last) > at:
            f.append("chmod -R a-w runs before %s is written" % last)
    if pj.find('s="$(seal') < at:
        f.append("the seal digest is taken before chmod -R a-w")
    pi, ci = c.index(lambda s: s["id"] == "prepare"), c.claude_index()
    if pi is None or ci is None or not pi < ci:
        f.append("the prepare step does not come before the Claude step")
    return f


@check("A16", "the seal is verified after the model; post-checks and the patch need it")
def a16(c):
    f = []
    ids = [s["id"] for s in c.sync["steps"]]
    ci = c.claude_index()
    if "seal" not in ids or "post" not in ids or ci is None or not ci < ids.index("seal") < ids.index("post"):
        return ["the seal step does not sit between the Claude step and post-checks"]
    seal, prep = c.step("seal"), c.step("prepare")
    if unwrap(seal["if"]) != "!cancelled() && steps.prepare.outcome == 'success'":
        f.append("the seal step's if: is %r" % unwrap(seal["if"]))
    for need in ("SEAL: ${{ steps.prepare.outputs.seal }}", "GITSTATE: ${{ steps.prepare.outputs.git }}"):
        if need not in seal["raw"]:
            f.append("the seal step's env lacks %s" % need)
    if not re.search(r'\[ -n "\$SEAL" \] && \[ "\$s" = "\$SEAL" \] \|\| \{', seal["j"] or ""):
        f.append("the seal step does not fail closed on a seal mismatch")
    for name in ("seal", "gitstate"):
        a, b = fn_text(prep["j"], name), fn_text(seal["j"], name)
        if not a or a != b:
            f.append("%s() differs between the prepare and seal steps" % name)
    if "set -- rd assert-claude-run-complete.sh before.snap obligations.before.json" not in (fn_text(prep["j"], "seal") or ""):
        f.append("seal() does not cover rd, the guard copy, the snapshot and the before-report")
    for need in ('echo "seal=$s"', 'echo "git=$g"'):
        if need not in prep["j"]:
            f.append("the prepare step does not output %s" % need)
    if unwrap(c.step("post")["if"]) != "!cancelled() && steps.seal.outcome == 'success'":
        f.append("the post step runs without a verified seal")
    b = c.step("bundle") or {}
    bj = b.get("j") or ""
    stop = re.search(r'^if \[ "\$GATE" != success \]; then\n.*\n\s*exit 0\nfi$', bj, re.M)
    if "GATE: ${{ steps.gate.outcome }}" not in b.get("raw", "") or not stop or stop.start() > bj.find("git read-tree"):
        f.append("the bundle can carry a patch without a passing gate")
    return f


@check("A17", "git's config, hooks, global config and refs are hashed before and verified after the model")
def a17(c):
    f = []
    g = fn_text((c.step("prepare") or {}).get("j"), "gitstate") or ""
    for need in ("git config --file .git/config --list", "find .git/hooks -printf",
                 "find .git/hooks -type f", '"$HOME/.gitconfig"', "git for-each-ref", "git rev-parse HEAD"):
        if need not in g:
            f.append("gitstate() does not hash %s" % need)
    ex = "grep -vE '^(user\\.(name|email)|remote\\.origin\\.url|http\\..*\\.extraheader)='"
    if ex not in g:
        f.append("gitstate() ignores other keys than the four claude-code-action rewrites")
    if not re.search(r'\[ -n "\$GITSTATE" \] && \[ "\$g" = "\$GITSTATE" \] \|\| \{', (c.step("seal") or {}).get("j") or ""):
        f.append("the seal step does not fail closed on a git-state mismatch")
    gate = c.step("gate") or {}
    if "SEALED: ${{ steps.seal.outcome }}" not in gate.get("raw", "") or \
            '[ "$SEALED" = success ] || refuse' not in (gate.get("j") or ""):
        f.append("sync's gate step does not refuse when the seal step did not succeed")
    return f


@check("A18", "every git add, commit, push, apply and the patch diff run with hooks and fsmonitor off")
def a18(c):
    f, n = [], 0
    for jid, j in c.wf.items():
        for s in j["steps"]:
            for ln in (s["j"] or "").split("\n"):
                for m in re.finditer(GITC + r"(add|commit|push|apply|diff\b[^\n]*--binary)\b", ln):
                    n += 1
                    if "-c core.hooksPath=/dev/null" not in m.group(1) or "-c core.fsmonitor=false" not in m.group(1):
                        f.append("%s: git %s without core.hooksPath=/dev/null and core.fsmonitor=false: %s"
                                 % (jid, m.group(2).split()[0], ln.strip()))
    return f + ([] if n >= 6 else ["found %d git add/commit/push/apply/diff --binary commands, want at least 6" % n])


@check("A19", "a tree moves on only with a report that opens with the write fence's result")
def a19(c):
    f = gate_checks(c.step("gate"), "post-checks.md", "sync")
    f += gate_checks(c.step("gate", "publish"), "pc.md", "publish")
    # The strings the gates trust are the ones the fence and post-checks write.
    if '["- ok: write fence"], "ok"' not in c.fence:
        f.append('fence.py no longer reports a clean fence as "- ok: write fence"')
    if not re.search(r'"- FENCE: ', c.fence) or not re.search(r'"- FAIL: ', c.fence):
        f.append("fence.py no longer opens its lines with - FENCE: / - FAIL:")
    fi = c.post_sh.find('fence_out="$(bash "$HERE/docs-detect.sh" --fence')
    if fi < 0 or re.search(r"^\s*say\s+\"", c.post_sh[:fi], re.M) or 'say "$body"' not in c.post_sh[fi:]:
        f.append("post-checks.sh no longer writes the fence's lines first in its report")
    return f


@check("A20", "the scripts are allowed one by one, plus node --check: no directory-prefix rule, no run-all")
def a20(c):
    have = c.allowed()
    f = []
    bash = [t for t in have if t.startswith("Bash(")]
    if sorted(bash) != sorted(SCRIPT_RULES + OTHER_BASH):
        f.append("the Bash rules are %s, want %s" % (bash, SCRIPT_RULES + OTHER_BASH))
    if any(t.endswith("/:*)") for t in have):
        f.append("a directory-prefix rule is allowed")
    if "Bash(node --check:*)" not in have:
        f.append("node --check is not allowed: walkthrough:document's render contract (page-missing) runs it")
    if any("run-all" in t for t in have):
        f.append("tests/run-all.sh is allowed: an edited belt would run code of the model's choosing")
    if sorted(t for t in have if not t.startswith("Bash(")) != sorted(TOOLS):
        f.append("the non-Bash tools are %s, want %s" % ([t for t in have if not t.startswith("Bash(")], TOOLS))
    return f


@check("A21", "only github-actions[bot] may start the Claude step as a bot")
def a21(c):
    cl = c.claude()
    v = (field(cl["raw"], "allowed_bots", "          ") or "").strip("'\"") if cl else None
    return [] if v == "github-actions[bot]" else ["allowed_bots is %r" % v]


@check("A22", "DOCS_BOT_TOKEN exists only in publish's push step, never in a job the model runs in")
def a22(c):
    f = []
    refs = re.findall(r"secrets\.([A-Z_]+)", c.text)
    if sorted(refs) != ["CLAUDE_CODE_OAUTH_TOKEN", "DOCS_BOT_TOKEN"]:
        f.append("secrets read: %s, want CLAUDE_CODE_OAUTH_TOKEN and DOCS_BOT_TOKEN once each" % refs)
    for jid, j in c.wf.items():
        model_job = any((s["uses"] or "").startswith("anthropics/claude-code-action@") for s in j["steps"])
        if model_job and "DOCS_BOT_TOKEN" in code(j["raw"]):
            f.append("%s runs the model and names DOCS_BOT_TOKEN" % jid)
        for s in j["steps"]:
            if "secrets.DOCS_BOT_TOKEN" in s["raw"] and (jid != "publish" or s["id"] != "push"
                                                         or not re.search(r"\bgit\b[^\n]*\bpush\b", s["j"] or "")):
                f.append("%s/%r reads DOCS_BOT_TOKEN; only publish's push step may" % (jid, s["name"] or s["id"]))
            if "secrets.CLAUDE_CODE_OAUTH_TOKEN" in s["raw"] and s is not c.claude():
                f.append("%s/%r reads the OAuth secret; only the Claude step may" % (jid, s["name"] or s["id"]))
    return f


@check("A23", "no ${{ }} expression inside any run block")
def a23(c):
    return ["%s/%s interpolates ${{ }} into run:" % (jid, s["name"] or s["id"])
            for jid, j in c.wf.items() for s in j["steps"] if "${{" in (s["run"] or "")]


@check("A24", "every checkout sets persist-credentials: false")
def a24(c):
    steps = [s for j in c.wf.values() for s in j["steps"]]
    steps += [s for j in c.val.values() if j["name"] == "Docs Obligations" for s in j["steps"]]
    return ["a checkout keeps its credentials: %s" % s["raw"].split("\n")[0].strip()
            for s in steps if (s["uses"] or "").startswith("actions/checkout@")
            and not re.search(r"^          persist-credentials: false$", s["raw"], re.M)]


@check("A25", "the completion guard runs always() from its sealed copy; an incomplete or failed sync publishes a draft")
def a25(c):
    ci = c.claude_index()
    call = re.compile(r"^\s*(bash\s+)?\"?[^\s\"]*assert-claude-run-complete\.sh\"?\s*$", re.M)
    g = next((s for s in c.after_claude() if call.search(s["j"] or "")), None)
    if ci is None or not g:
        return ["no completion guard after the Claude step"]
    f = []
    if unwrap(g["if"]) != "always()":
        f.append("the guard's if: is %r, want always()" % unwrap(g["if"]))
    if 'bash "$RUNNER_TEMP/assert-claude-run-complete.sh"' not in g["j"]:
        f.append("the guard does not run its sealed copy")
    if not re.search(r'if \[ "\$SEALED" != success \]; then\n.*\n\s*exit 1', g["j"]):
        f.append("the guard runs its copy without a verified seal")
    for need in ("CLAUDE_CONCLUSION: ${{ steps.claude.outputs.conclusion }}",
                 "CLAUDE_EXECUTION_FILE: ${{ steps.claude.outputs.execution_file }}"):
        if need not in g["raw"]:
            f.append("the guard's env lacks %s" % need)
    if 'cp .github/scripts/assert-claude-run-complete.sh "$RUNNER_TEMP/assert-claude-run-complete.sh"' \
            not in ((c.step("prepare") or {}).get("j") or ""):
        f.append("the prepare step does not copy the guard into $RUNNER_TEMP")
    # An incomplete run still bundles (neither the Claude step nor the guard stops the job), publish
    # drafts it, and with nothing to publish sync's last step fails on it.
    for what, s in (("the guard", g), ("the Claude step", c.claude())):
        if not re.search(r"^        continue-on-error: true$", s["raw"], re.M):
            f.append("an incomplete run stops the bundle: %s lacks continue-on-error: true" % what)
    v = next((s for s in c.sync["steps"] if (s["name"] or "").startswith("Fail unless the sync passed")), {})
    if unwrap(v.get("if")) != ("!cancelled() && steps.gate.outcome == 'success' && "
                               "(inputs.dry_run != false || steps.bundle.outputs.changed != 'true')") or \
            '[ "$CLAUDE_CONCLUSION" = success ] || {' not in (v.get("j") or "") or \
            '[ "$POST_RC" = 0 ] || {' not in (v.get("j") or ""):
        f.append("with nothing to publish, sync does not end red on a failed or incomplete run")
    pg = (c.step("gate", "publish") or {}).get("j") or ""
    if 'if [ "$POST_RC" != 0 ] || [ "$SYNC_RC" != 0 ] || [ "$SYNC_CLAUDE" != success ]; then draft=true; fi' not in pg:
        f.append("publish does not draft the PR when either post-checks run failed or the model's run is incomplete")
    return f


@check("A26", "permissions: read-only everywhere, sync exactly contents: read, publish adds pull-requests: write")
def a26(c):
    want = {None: {"contents": "read"}, "detect": {"contents": "read"},
            "dispatch": {"actions": "write", "contents": "read"}, "sync": {"contents": "read"},
            "publish": {"contents": "read", "pull-requests": "write"}}
    f = []
    for jid, perms in want.items():
        got = perms_of(c.text.split("\njobs:")[0], "") if jid is None else \
            perms_of(c.wf.get(jid, {}).get("head", ""), "    ")
        if got != perms:
            f.append("%s permissions are %s, want %s" % (jid or "workflow", got, perms))
        if yaml:
            y = c.y.get("permissions") if jid is None else (c.y["jobs"].get(jid) or {}).get("permissions")
            if y != perms:
                f.append("%s permissions (PyYAML) are %s, want %s" % (jid or "workflow", y, perms))
    return f


@check("A27", "publish never runs the model: no Claude step, no Claude install, no OAuth secret")
def a27(c):
    f = []
    for s in c.publish["steps"]:
        if (s["uses"] or "").startswith("anthropics/"):
            f.append("publish uses %s" % s["uses"])
        if re.search(r"(^|[\s;&|(])(claude|npx\s+\S*claude\S*)(\s|$)|@anthropic-ai/claude-code|claude\.ai/install",
                     s["j"] or "", re.M):
            f.append("publish runs or installs Claude: %r" % (s["name"] or s["id"]))
    if "CLAUDE_CODE_OAUTH_TOKEN" in code(c.publish["raw"]):
        f.append("publish names the Claude OAuth secret")
    if not c.publish["steps"]:
        f.append("there is no publish job")
    return f


@check("A28", "publish snapshots and copies its scripts before the patch, and checks only from that copy")
def a28(c):
    f, steps = [], c.publish["steps"]
    snap = pos(steps, r'^bash \.claude/skills/release-docs/scripts/post-checks\.sh --snapshot "\$RUNNER_TEMP/p\.snap"$')
    copy = pos(steps, r'^cp -R \.claude/skills/release-docs/scripts "\$RUNNER_TEMP/rd"$')
    before = pos(steps, r'^bash "\$RUNNER_TEMP/rd/docs-detect\.sh" --range origin/main\.\.HEAD --out "\$RUNNER_TEMP/before\.json"$')
    apply_ = pos(steps, GITC + r"apply\b")
    if apply_ is None:
        return ["publish never applies the patch"]
    for what, p in (("the snapshot", snap), ("the scripts copy", copy), ("the before-report", before)):
        if p is None or not p < apply_:
            f.append("%s is not taken before the patch is applied" % what)
    if snap and copy and not snap < copy:
        f.append("the snapshot is not taken before the scripts are copied")
    for s in steps[apply_[0]:]:
        j = s["j"] or ""
        if re.search(r"\.claude/skills/release-docs/scripts/|\.github/scripts/", j.split("apply", 1)[-1] if s is steps[apply_[0]] else j):
            f.append("%r runs a checkout script after the patch is applied" % (s["name"] or s["id"]))
    body = lines_of(steps, "--pr-body")
    if not body or not body[0].strip().startswith('bash "$RUNNER_TEMP/rd/docs-detect.sh"'):
        f.append("publish's --pr-body does not run from the pre-apply copy")
    return f


@check("A29", "publish runs its own full post-checks with --expect-clean, after the patch")
def a29(c):
    steps = c.publish["steps"]
    want = ('bash "$RUNNER_TEMP/rd/post-checks.sh" --before "$RUNNER_TEMP/p.snap" --expect-clean '
            '--report "$RUNNER_TEMP/pc.md" --shots "$RUNNER_TEMP/shots"')
    p, a = pos(steps, re.escape(want)), pos(steps, GITC + r"apply\b")
    f = []
    if p is None:
        f.append("publish does not run %r" % want)
    elif a is None or not a < p:
        f.append("publish's post-checks do not run after the patch is applied")
    ps = c.step("post", "publish") or {}
    if ps.get("if") is not None or "RELEASE_DOCS_SKIP" in code(c.publish["raw"]):
        f.append("publish's post-checks can run on a failed apply, or skip checks")
    return f


@check("A30", "START_SHA reaches publish only through env, from detect, and is checked as 40-hex")
def a30(c):
    f, steps = [], c.publish["steps"]
    co = next((s for s in steps if (s["uses"] or "").startswith("actions/checkout@")), None)
    if not co or not re.search(r"^          ref: \$\{\{ needs\.detect\.outputs\.sha \}\}$", co["raw"], re.M):
        f.append("publish does not check out the commit detect saw")
    pr = c.step("prepare", "publish") or {}
    pj = pr.get("j") or ""
    if "START: ${{ needs.detect.outputs.sha }}" not in pr.get("raw", ""):
        f.append("publish's prepare step does not take START from detect through env")
    for need in ('[[ "$START" =~ ^[0-9a-f]{40}$ ]] || refuse', '[ "$(git rev-parse HEAD)" = "$START" ] || refuse',
                 'git merge-base --is-ancestor "$START" origin/develop || refuse',
                 '[[ "$start" =~ ^[0-9a-f]{40}$ ]] && [ "$start" = "$START" ] || refuse'):
        if need not in pj:
            f.append("publish's prepare step lacks %r" % need)
    ps = next((s for s in steps if s["id"] == "push"), {})
    if "START: ${{ needs.detect.outputs.sha }}" not in ps.get("raw", "") or \
            '[[ "$START" =~ ^[0-9a-f]{40}$ ]] ||' not in (ps.get("j") or ""):
        f.append("the push step does not re-check START as 40-hex")
    return f


@check("A31", "publish runs only after a successful sync, never on a dry run or an empty patch")
def a31(c):
    f = []
    want = ("github.event_name == 'workflow_dispatch' && needs.sync.result == 'success' && "
            "inputs.dry_run == false && needs.sync.outputs.changed == 'true'")
    if unwrap(c.publish.get("if")) != want:
        f.append("publish if: is %r, want %r" % (unwrap(c.publish.get("if")), want))
    if not re.search(r"^    needs: \[detect, sync\]$", c.publish.get("head", ""), re.M):
        f.append("publish does not need detect and sync")
    if not re.search(r"^      changed: \$\{\{ steps\.bundle\.outputs\.changed \}\}$", c.sync.get("head", ""), re.M):
        f.append("sync's changed output is not the bundle step's")
    return f


@check("A32", "the one hand-off: a binary patch of the fenced tree against START, applied whole")
def a32(c):
    f = []
    b = c.step("bundle") or {}
    bj = b.get("j") or ""
    for need in ('export GIT_INDEX_FILE="$RUNNER_TEMP/bundle.index"', 'git read-tree "$START"',
                 "git -c core.hooksPath=/dev/null -c core.fsmonitor=false add -A",
                 'diff --cached --binary --no-renames --no-ext-diff --no-textconv "$START" > "$B/sync.patch"'):
        if need not in bj:
            f.append("the bundle step lacks %r" % need)
    if "START: ${{ steps.prepare.outputs.start }}" not in b.get("raw", ""):
        f.append("the bundle's START is not the prepare step's")
    up = [s for s in c.sync["steps"] if (s["uses"] or "").startswith("actions/upload-artifact@")]
    if len(up) != 1 or "name: ${{ steps.prepare.outputs.artifact }}" not in up[0]["raw"] or \
            not re.search(r"^          path: \$\{\{ runner\.temp \}\}/bundle$", up[0]["raw"], re.M):
        f.append("sync does not upload exactly the bundle directory under the artifact name")
    if not re.search(r"^      artifact: \$\{\{ steps\.prepare\.outputs\.artifact \}\}$", c.sync.get("head", ""), re.M):
        f.append("sync does not output the artifact name")
    dl = [s for s in c.publish["steps"] if (s["uses"] or "").startswith("actions/download-artifact@")]
    if len(dl) != 1 or "name: ${{ needs.sync.outputs.artifact }}" not in dl[0]["raw"] or \
            "path: ${{ runner.temp }}/sync" not in dl[0]["raw"]:
        f.append("publish does not download the sync bundle into $RUNNER_TEMP/sync")
    if not lines_of(c.publish["steps"], 'false apply --binary "$patch"') or \
            'patch="$RUNNER_TEMP/sync/sync.patch"' not in "".join(s["j"] or "" for s in c.publish["steps"]):
        f.append("publish does not apply the bundle's patch with apply --binary")
    if any(re.search(GITC + r"apply\b[^\n]*--(index|cached)\b", ln) for ln in joined(c.text).split("\n")):
        f.append("an apply stages the patch (--index/--cached): a gitlink in it would be staged")
    return f


@check("A33", "publish commits only what a staged-set check passed: plain files at allowlisted paths")
def a33(c):
    f, steps = [], c.publish["steps"]
    ids = [s["id"] for s in steps]
    if "stage" not in ids or "push" not in ids or not ids.index("stage") < ids.index("push"):
        return ["there is no stage step before the push step"]
    st, ps, pr = c.step("stage", "publish"), c.step("push", "publish"), c.step("prepare", "publish") or {}
    sj = st.get("j") or ""
    order = [sj.find(x) for x in ("git -c core.hooksPath=/dev/null -c core.fsmonitor=false add -A",
                                  'bash "$RUNNER_TEMP/rd/docs-detect.sh" --allowed-paths > "$RUNNER_TEMP/allowed.now.txt"',
                                  'diff --cached --raw -z --no-renames HEAD > "$RUNNER_TEMP/staged.raw"',
                                  'python3 - "$RUNNER_TEMP/staged.raw" "$RUNNER_TEMP/allowed.start.txt" "$RUNNER_TEMP/allowed.now.txt"',
                                  'echo "tree=$(git write-tree)" >> "$GITHUB_OUTPUT"')]
    if -1 in order or order != sorted(order):
        f.append("the stage step does not stage, list the allowlist, read the staged set, check it, then output its tree")
    for need in ('elif meta[1] not in ("100644", "000000"):', 'elif path not in allowed:',
                 'if len(meta) != 5 or not meta[0].startswith(":"):', "sys.exit(1 if bad else 0)"):
        if need not in sj:
            f.append("the staged-set check lacks %r" % need)
    pj = pr.get("j") or ""
    at, ap = pj.find('--allowed-paths > "$RUNNER_TEMP/allowed.start.txt"'), \
        pos(steps, GITC + r"apply\b")
    if at < 0 or ap is None or not ids.index("prepare") < ap[0]:
        f.append("START's allowlist is not listed before the patch is applied")
    aj = next((s["j"] for s in steps if re.search(GITC + r"apply --binary", s["j"] or "")), "")
    summ = aj.find("odd=\"$(git -c core.hooksPath=/dev/null -c core.fsmonitor=false apply --summary \"$patch\" | "
                   "grep -vE '^ (create|delete) mode 100644 ' || true)\"")
    if summ < 0 or not re.search(r'if \[ -n "\$odd" \]; then\n(.*\n){2}\s*exit 1\n', aj) or summ > aj.find("apply --binary"):
        f.append("publish applies a patch without first refusing non-plain files and mode changes in it")
    pjj = ps.get("j") or ""
    if re.search(GITC + r"add\b", pjj):
        f.append("the push step stages on its own, after the check")
    chk = pjj.find('[ -n "$TREE" ] && [ "$(git write-tree)" = "$TREE" ] || {')
    if "TREE: ${{ steps.stage.outputs.tree }}" not in ps.get("raw", "") or chk < 0 or \
            chk > pjj.find("commit -q -F"):
        f.append("the push step does not commit exactly the tree the stage step checked")
    if "secrets." in st.get("raw", ""):
        f.append("the stage step reads a secret")
    return f


@check("PARSE", "the belt's reader agrees with PyYAML on every job and step", yaml_only=True)
def parse(c):
    f = []
    for text_model, data, name in ((c.wf, c.y, "release-docs.yml"), (c.val, c.yval, "validate.yml")):
        if sorted(text_model) != sorted(data["jobs"]):
            f.append("%s: jobs %s vs %s" % (name, sorted(text_model), sorted(data["jobs"])))
            continue
        for jid, job in data["jobs"].items():
            tj = text_model[jid]
            if unwrap(tj["if"]) != unwrap(job.get("if")) or tj["name"] != job.get("name"):
                f.append("%s:%s if/name differ" % (name, jid))
            ys = job.get("steps") or []
            if len(ys) != len(tj["steps"]):
                f.append("%s:%s has %d steps, the reader saw %d" % (name, jid, len(ys), len(tj["steps"])))
                continue
            for k, (a, b) in enumerate(zip(tj["steps"], ys)):
                pairs = (("run", a["run"], b.get("run")), ("if", unwrap(a["if"]), unwrap(b.get("if"))),
                         ("id", a["id"], b.get("id")),
                         ("uses", a["uses"], b.get("uses")))
                for key, x, y in pairs:
                    if key == "run":
                        x, y = (x or "").rstrip("\n"), (y or "").rstrip("\n")
                    if (x or None) != (y or None):
                        f.append("%s:%s step %d: the reader's %s differs from PyYAML's" % (name, jid, k, key))
    return f


def run_checks(root):
    try:
        c = Ctx(root)
    except (OSError, ValueError) as e:  # a missing or unparsable file: every contract is unproven
        return ["[SETUP] cannot read the workflows: %s: %s" % (type(e).__name__, e)]
    out = []
    for cid, desc, yaml_only, fn in CHECKS:
        if yaml_only and yaml is None:
            continue
        try:
            fails = fn(c)
        except Exception as e:  # a crash is a failure of that check, never a pass
            fails = ["crashed: %s: %s" % (type(e).__name__, e)]
        out += ["[%s] %s" % (cid, x) for x in fails]
    return out


# ---------------------------------------------------------------- self-test mutants
# (check id, [(file, old, new, count)], label). Each must make its own check report.
S = "          "
PUB_IF = ("      github.event_name == 'workflow_dispatch' && needs.sync.result == 'success' &&\n"
          "      inputs.dry_run == false && needs.sync.outputs.changed == 'true'\n")
PUB_SNAP = S + 'bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot "$T/p.snap"\n'
PUB_APPLY = S + 'git -c core.hooksPath=/dev/null -c core.fsmonitor=false apply --binary "$patch"\n'
MUTANTS = [
    ("A1", [(WF, "    if: github.event_name == 'workflow_dispatch' && needs.detect.outputs.open != '0'\n",
             "    if: needs.detect.outputs.open != '0'\n", 1)], "sync also runs on pull_request"),
    ("A2", [(WF, "    if: github.event_name == 'pull_request' && needs.detect.outputs.open != '0'\n",
             "    if: needs.detect.outputs.open != '0'\n", 1)], "dispatch also runs on workflow_dispatch"),
    ("A2", [(WF, " && github.event.pull_request.head.repo.full_name == github.repository)", ")", 1)],
     "detect drops the same-repo check"),
    ("A2", [(WF, PUB_IF, "      needs.sync.result == 'success' &&\n"
             "      inputs.dry_run == false && needs.sync.outputs.changed == 'true'\n", 1)],
     "publish can run outside workflow_dispatch"),
    ("A3", [(WF, S + 'bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot "$T/before.snap"\n', "", 1),
            (WF, S + 'git switch -c "$branch"\n',
             S + 'git switch -c "$branch"\n' + S + 'bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot "$T/before.snap"\n', 1)],
     "sync's snapshot taken after the branch"),
    ("A4", [(WF, '--before "$RUNNER_TEMP/before.snap" --expect-clean \\\n', '--before "$RUNNER_TEMP/before.snap" \\\n', 1)],
     "sync's post-checks without --expect-clean"),
    ("A5", [(WF, '--report "$RUNNER_TEMP/post-checks.md"', '--report .release-docs/run/post-checks.md', 1)],
     "sync's report inside the checkout"),
    ("A6", [(WF, "steps.stage.outcome == 'success' && (steps.post.outputs.rc == '0' || steps.post.outputs.rc == '1') }}",
             "steps.stage.outcome == 'success' && (steps.post.outputs.rc == '0' || steps.post.outputs.rc == '2') }}", 1)],
     "push on rc 2"),
    ("A6", [(WF, "if: ${{ !cancelled() && steps.gate.outputs.publish == 'true' && steps.stage.outcome",
             "if: ${{ !cancelled() && steps.stage.outcome", 1)], "push without the gate"),
    ("A6", [(WF, " && steps.stage.outcome == 'success' && (steps.post", " && (steps.post", 1)],
     "push without the staged-set check"),
    ("A6", [(WF, "        if: ${{ !cancelled() && steps.push.outputs.url != '' }}\n",
             "        if: ${{ !cancelled() }}\n", 1)], "PR comments without a pushed docs PR"),
    ("A7", [(WF, S + "if git diff --cached --quiet; then\n",
             S + "git -c core.hooksPath=/dev/null -c core.fsmonitor=false add -f .github/docs-surfaces.json\n"
             + S + "if git diff --cached --quiet; then\n", 1)], "force-add"),
    ("A7", [(WF, S + "if git diff --cached --quiet; then\n",
             S + 'git -c user.name="a b" add --force site\n' + S + "if git diff --cached --quiet; then\n", 1)],
     "force-add behind a quoted -c value"),
    ("A8", [(WF, '--before "$T/before.json" --verifier "$T/sync/verifier.json" \\\n',
             '--before "$T/before.json" \\\n', 1)], "PR body without --verifier"),
    ("A9", [(WF, S + "github_token: ${{ github.token }}\n", "", 1)], "no github_token"),
    ("A10", [(WF, "756cc22e19660d20e8cc9496b4f242475a7f7790 # v1.0.235",
              "0000000000000000000000000000000000000000 # v1.0.231", 1)], "another action pin"),
    ("A11", [(WF, "--model claude-opus-5-5", "--model claude-sonnet-5", 1)], "another model"),
    ("A12", [(WF, "Agent,Task,", "Agent,", 1)], "Task not allowed"),
    ("A13", [(VAL, "    if: github.event_name == 'pull_request' && github.base_ref == 'main'\n",
              "    if: github.event_name == 'pull_request'\n", 1)], "gate on every PR"),
    ("A14", [(WF, 'bash "$RUNNER_TEMP/rd/post-checks.sh" --before "$RUNNER_TEMP/before.snap"',
              'bash .claude/skills/release-docs/scripts/post-checks.sh --before "$RUNNER_TEMP/before.snap"', 1)],
     "sync's post-checks from the checkout"),
    ("A15", [(WF, S + 'chmod -R a-w "$T/rd" "$T/assert-claude-run-complete.sh" "$T/before.snap" "$T/obligations.before.json"\n',
              "", 1)], "no chmod"),
    ("A16", [(WF, '[ -n "$SEAL" ] && [ "$s" = "$SEAL" ] || {', '[ -n "$s" ] || {', 1)], "seal compared to nothing"),
    ("A16", [(WF, "if: ${{ !cancelled() && steps.seal.outcome == 'success' }}\n        run: |\n          set +e\n",
              "if: ${{ !cancelled() && steps.claude.outcome != 'skipped' }}\n        run: |\n          set +e\n", 1)],
     "post-checks without a verified seal"),
    ("A16", [(WF, S + 'if [ "$GATE" != success ]; then\n', S + 'if false; then\n', 1)],
     "a patch without a passing gate"),
    ("A17", [(WF, 'for f in "$HOME/.gitconfig" "$HOME/.config/git/config"; do',
              'for f in "$HOME/.config/git/config"; do', 2)], "global .gitconfig not hashed"),
    ("A18", [(WF, "git -c core.hooksPath=/dev/null -c core.fsmonitor=false \\\n            push -q",
              "git -c core.fsmonitor=false \\\n            push -q", 1)], "push with hooks on"),
    ("A18", [(WF, PUB_APPLY, S + 'git apply --binary "$patch"\n', 1)],
     "apply with hooks on"),
    ("A19", [(WF, "*) refuse \"the post-checks report does not open with the write fence's result\" ;;\n"
              "          esac\n          echo \"The fenced tree", "*) ;;\n          esac\n          echo \"The fenced tree", 1)],
     "sync's gate accepts any report"),
    ("A19", [(WF, "*) refuse \"the post-checks report does not open with the write fence's result\" ;;\n"
              "          esac\n          draft=false", "*) ;;\n          esac\n          draft=false", 1)],
     "publish's gate accepts any report"),
    ("A20", [(WF, ",".join(SCRIPT_RULES), "Bash(bash .claude/skills/release-docs/scripts/:*)", 1)],
     "directory-prefix rule"),
    ("A20", [(WF, "og-regen.sh:*),Bash(node --check:*)", "og-regen.sh:*),Bash(bash tests/run-all.sh),Bash(node --check:*)", 1)],
     "run-all allowed"),
    ("A21", [(WF, "allowed_bots: 'github-actions[bot]'", "allowed_bots: '*'", 1)], "every bot allowed"),
    ("A22", [(WF, "          GH_TOKEN: ${{ github.token }}\n          REPO:", "          GH_TOKEN: ${{ secrets.DOCS_BOT_TOKEN }}\n          REPO:", 1)],
     "dispatch reads DOCS_BOT_TOKEN"),
    ("A22", [(WF, "          GATE: ${{ steps.gate.outcome }}\n", "          GATE: ${{ steps.gate.outcome }}\n"
              "          PAT: ${{ secrets.DOCS_BOT_TOKEN }}\n", 1),
             (WF, "          GH_TOKEN: ${{ secrets.DOCS_BOT_TOKEN }}\n", "          GH_TOKEN: ${{ github.token }}\n", 1)],
     "the model's job holds the PAT"),
    ("A23", [(WF, '[[ "$RELEASE_PR" =~ ^([1-9][0-9]{0,9})?$ ]] \\', '[[ "${{ inputs.release_pr }}" =~ ^([1-9][0-9]{0,9})?$ ]] \\', 1)],
     "an input interpolated into run:"),
    ("A24", [(WF, "          ref: ${{ needs.detect.outputs.sha }}\n          fetch-depth: 0\n          persist-credentials: false\n\n"
              "      - uses: actions/download-artifact",
              "          ref: ${{ needs.detect.outputs.sha }}\n          fetch-depth: 0\n\n      - uses: actions/download-artifact", 1)],
     "publish's checkout keeps credentials"),
    ("A25", [(WF, 'bash "$RUNNER_TEMP/assert-claude-run-complete.sh"', ".github/scripts/assert-claude-run-complete.sh", 1)],
     "guard from the checkout"),
    ("A25", [(WF, "        timeout-minutes: 40\n        continue-on-error: true\n", "        timeout-minutes: 40\n", 1)],
     "a capped run fails sync and skips publish"),
    ("A25", [(WF, '[ "$CLAUDE_CONCLUSION" = success ] || { echo "::error::the Claude run did not complete"; exit 1; }',
              'true', 1)], "a dry run of an incomplete run ends green"),
    ("A25", [(WF, 'if [ "$POST_RC" != 0 ] || [ "$SYNC_RC" != 0 ] || [ "$SYNC_CLAUDE" != success ]; then draft=true; fi',
              'if [ "$POST_RC" != 0 ] || [ "$SYNC_RC" != 0 ]; then draft=true; fi', 1)], "an incomplete run published ready"),
    ("A25", [(WF, 'if [ "$POST_RC" != 0 ] || [ "$SYNC_RC" != 0 ] || [ "$SYNC_CLAUDE" != success ]; then draft=true; fi',
              'if [ "$POST_RC" != 0 ] || [ "$SYNC_CLAUDE" != success ]; then draft=true; fi', 1)],
     "a failed model-job post-checks published ready"),
    ("A26", [(WF, "    permissions:\n      contents: read\n    outputs:\n      artifact:",
              "    permissions:\n      contents: read\n      pull-requests: write\n    outputs:\n      artifact:", 1)],
     "sync gets pull-requests: write"),
    ("A26", [(WF, "    permissions:\n      contents: read\n      pull-requests: write\n    steps:",
              "    permissions:\n      contents: write\n      pull-requests: write\n    steps:", 1)],
     "publish gets contents: write"),
    ("A27", [(WF, "      - uses: actions/download-artifact@",
              "      - uses: anthropics/claude-code-action@756cc22e19660d20e8cc9496b4f242475a7f7790 # v1.0.235\n"
              "      - uses: actions/download-artifact@", 1)], "publish runs a Claude step"),
    ("A28", [(WF, PUB_SNAP, "", 1), (WF, PUB_APPLY, PUB_APPLY + PUB_SNAP.replace("$T/", "$RUNNER_TEMP/"), 1)],
     "publish's snapshot taken after the patch"),
    ("A28", [(WF, 'bash "$T/rd/docs-detect.sh" --range origin/main..HEAD --pr-body',
              "bash .claude/skills/release-docs/scripts/docs-detect.sh --range origin/main..HEAD --pr-body", 1)],
     "publish's PR body from the patched checkout"),
    ("A29", [(WF, '--before "$RUNNER_TEMP/p.snap" --expect-clean \\\n', '--before "$RUNNER_TEMP/p.snap" \\\n', 1)],
     "publish's post-checks without --expect-clean"),
    ("A30", [(WF, '[[ "$start" =~ ^[0-9a-f]{40}$ ]] && [ "$start" = "$START" ] \\\n', "true \\\n", 1)],
     "the bundle's start commit unchecked"),
    ("A30", [(WF, "          START: ${{ needs.detect.outputs.sha }}\n        run: |\n          set -euo pipefail\n          T=",
              "          START: ${{ needs.sync.outputs.rc }}\n        run: |\n          set -euo pipefail\n          T=", 1)],
     "START taken from the model's job"),
    ("A31", [(WF, PUB_IF, "      github.event_name == 'workflow_dispatch' && needs.sync.result == 'success' &&\n"
              "      needs.sync.outputs.changed == 'true'\n", 1)], "publish on a dry run"),
    ("A31", [(WF, PUB_IF, "      github.event_name == 'workflow_dispatch' &&\n"
              "      inputs.dry_run == false && needs.sync.outputs.changed == 'true'\n", 1)],
     "publish without a successful sync"),
    ("A32", [(WF, S + 'git read-tree "$START"\n', "", 1)], "the patch not taken against START"),
    ("A32", [(WF, "          path: ${{ runner.temp }}/sync\n", "          path: ${{ runner.temp }}/other\n", 1)],
     "publish downloads elsewhere"),
    ("A20", [(WF, "Bash(node --check:*),", "", 1)], "node --check dropped"),
    ("A32", [(WF, PUB_APPLY, PUB_APPLY.replace("apply --binary", "apply --index --binary"), 1)], "publish applies with --index"),
    ("A33", [(WF, 'elif meta[1] not in ("100644", "000000"):', "elif False:", 1)], "any mode staged"),
    ("A33", [(WF, "elif path not in allowed:", "elif False:", 1)], "any path staged"),
    ("A33", [(WF, "grep -vE '^ (create|delete) mode 100644 '", "grep -vE '^ (create|delete) mode 1[0-9]+ '", 1)],
     "the patch may create a gitlink"),
    ("A33", [(WF, S + '[ -n "$TREE" ] && [ "$(git write-tree)" = "$TREE" ] || { echo "::error::the staged tree is not the one the stage step checked"; exit 1; }\n',
              S + "git -c core.hooksPath=/dev/null -c core.fsmonitor=false add -A\n", 1)],
     "the push step re-stages after the check"),
    ("A33", [(WF, S + 'bash "$T/rd/docs-detect.sh" --allowed-paths > "$T/allowed.start.txt"\n', "", 1)],
     "START's allowlist never listed"),
    ("PARSE", [(WF, "        run: |\n          set +e\n          rm -rf \"$RUNNER_TEMP/post-checks.md\"",
                "        run: |2\n          set +e\n          rm -rf \"$RUNNER_TEMP/post-checks.md\"", 1)],
     "an indentation indicator the reader does not know"),
]

failures = run_checks(ROOT)
missed = []
skipped = 0
active = {cid for cid, _, yo, _ in CHECKS if not (yo and yaml is None)}
setup_failed = any(x.startswith("[SETUP] ") for x in failures)
for cid, edits, label in ([] if setup_failed else MUTANTS):
    if cid not in active:
        skipped += 1
        continue
    with tempfile.TemporaryDirectory() as tmp:
        vacuous = False
        for rel in FILES:
            os.makedirs(os.path.dirname(os.path.join(tmp, rel)), exist_ok=True)
            shutil.copy(os.path.join(ROOT, rel), os.path.join(tmp, rel))
        for rel, old, new, count in edits:
            src = read(tmp, rel)
            if src.count(old) != count:
                missed.append("self-test anchor for %s (%s) found %d times, want %d: the mutant would be vacuous"
                              % (cid, label, src.count(old), count))
                vacuous = True
                break
            with open(os.path.join(tmp, rel), "w", encoding="utf-8") as fh:
                fh.write(src.replace(old, new))
        if vacuous:
            continue
        got = run_checks(tmp)
        if not any(x.startswith("[%s] " % cid) for x in got):
            missed.append("check %s passed a mutant it exists to catch: %s" % (cid, label))

for cid, desc, yaml_only, _ in ([] if setup_failed else CHECKS):
    if yaml_only and yaml is None:
        print("skip: %s %s (PyYAML not importable)" % (cid, desc))
    elif not any(x.startswith("[%s] " % cid) for x in failures):
        print("ok: %s %s" % (cid, desc))
for x in failures + missed:
    print("FAIL: %s" % x)
if failures or missed:
    sys.exit(1)
print("PASS: release-docs workflow contracts (%d checks%s; %d mutants rejected%s)"
      % (len(active), "" if yaml else ", reader only", len(MUTANTS) - skipped,
         "" if not skipped else ", %d YAML-only skipped" % skipped))
PY
