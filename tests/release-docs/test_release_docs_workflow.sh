#!/usr/bin/env bash
# test_release_docs_workflow.sh — static contracts for .github/workflows/release-docs.yml and the
# "Docs Obligations" gate in validate.yml (release-docs spec § 7 and § 13 A3; SDD rulings R22, R24).
#
# The workflow can't be exercised before it merges, so this belt pins the safety properties the
# probes and reviews established: the model runs only on workflow_dispatch; the pull_request path
# only detects and dispatches; the snapshot, a read-only copy of the scripts and the before-report
# are made in $RUNNER_TEMP before the model runs, sealed, and verified afterwards along with git's
# state; the authoritative post-checks run from that copy with --expect-clean; a push needs
# post-checks exit 0 or 1 and a report that opens with the write fence's result; no force-add;
# --verifier is always passed; the action pin, model, token and tool allowlist are the probed ones.
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
OTHER_BASH = ["Bash(git diff:*)", "Bash(git status:*)"]
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
    return re.sub(r"\\\n\s*", " ", run)


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
        self.sync = self.wf.get("sync", {"steps": [], "raw": "", "head": "", "if": None})

    def step(self, sid):
        return next((s for s in self.sync["steps"] if s["id"] == sid), None)

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


@check("A1", "sync runs only on workflow_dispatch")
def a1(c):
    want = "github.event_name == 'workflow_dispatch' && needs.detect.outputs.open != '0'"
    got = unwrap(c.sync.get("if"))
    return [] if got == want else ["sync if: is %r, want %r" % (got, want)]


@check("A2", "the pull_request path only detects and dispatches")
def a2(c):
    f = []
    if set(c.wf) != {"detect", "dispatch", "sync"}:
        f.append("jobs are %s, want exactly detect, dispatch, sync" % sorted(c.wf))
    on = c.text[c.text.find("\non:"):c.text.find("\npermissions:")]
    for need in ("  pull_request:\n    types: [opened, reopened, synchronize]\n    branches: [main]\n",
                 "  workflow_dispatch:\n", "      dry_run:\n", "      release_pr:\n"):
        if need not in on:
            f.append("the on: block lacks %r" % need.strip())
    for bad in ("pull_request_target", "push:", "issue_comment", "workflow_run", "repository_dispatch",
                "schedule"):
        if bad in on:
            f.append("the on: block has %s" % bad)
    det = c.wf.get("detect", {})
    dif = unwrap(det.get("if"))
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
        if any((s["uses"] or "").startswith("anthropics/claude-code-action@") for s in job["steps"]) \
                and not unwrap(job.get("if")).startswith("github.event_name == 'workflow_dispatch' &&"):
            f.append("%s runs claude-code-action outside workflow_dispatch" % jid)
    return f


@check("A3", "the snapshot goes to $RUNNER_TEMP first, before the branch and before the model")
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
    if c.text.count("--snapshot") != 1:
        f.append("--snapshot appears %d times in the workflow, want 1" % c.text.count("--snapshot"))
    return f


@check("A4", "the authoritative post-checks use --expect-clean against the sealed snapshot")
def a4(c):
    p = c.step("post")
    want = 'post-checks.sh" --before "$RUNNER_TEMP/before.snap" --expect-clean'
    return [] if p and want in (p["j"] or "") else ["the post step does not run %r" % want]


@check("A5", "the report and the shots are written under $RUNNER_TEMP, to paths cleared first")
def a5(c):
    p = c.step("post")
    j = (p or {}).get("j") or ""
    f = []
    for need in ('--report "$RUNNER_TEMP/post-checks.md"', '--shots "$RUNNER_TEMP/shots"'):
        if need not in j:
            f.append("the post step lacks %s" % need)
    clear = j.find('rm -rf "$RUNNER_TEMP/post-checks.md" "$RUNNER_TEMP/shots"')
    if clear < 0 or clear > j.find("post-checks.sh"):
        f.append("the post step does not clear the report and shots paths before post-checks runs")
    return f


@check("A6", "push and PR only when the gate passed, not a dry run, and post-checks exited 0 or 1")
def a6(c):
    f = []
    pushers = [s for s in c.sync["steps"] if re.search(r"\bgit\b[^\n]*\bpush\b", s["j"] or "")]
    if len(pushers) != 1:
        return ["%d steps push, want exactly 1" % len(pushers)]
    ps = pushers[0]
    want = ("!cancelled() && steps.gate.outputs.publish == 'true' && inputs.dry_run == false && "
            "(steps.post.outputs.rc == '0' || steps.post.outputs.rc == '1')")
    if unwrap(ps["if"]) != want:
        f.append("the push step's if: is %r, want %r" % (unwrap(ps["if"]), want))
    if not re.search(r'^case "\$POST_RC" in 0\|1\) ;; \*\) .*exit 1 ;; esac$', ps["j"] or "", re.M):
        f.append("the push step does not refuse a post-checks exit other than 0 or 1")
    for other in c.sync["steps"]:
        if other is not ps and re.search(r"\b(git\b[^\n]*\bcommit\b|gh pr (create|edit|close|comment))", other["j"] or ""):
            f.append("%r commits or opens PRs outside the push step" % (other["name"] or other["id"]))
    g = c.step("gate") or {}
    gj = g.get("j") or ""
    if not re.search(r'case "\$POST_RC" in\s+0\|1\) ;;\s+\*\) refuse ', gj):
        f.append("the gate step does not refuse a post-checks exit other than 0 or 1")
    if gj.find('echo "publish=true"') < gj.find('case "$POST_RC"'):
        f.append("the gate step can set publish=true before checking the post-checks exit")
    return f


@check("A7", "no force-add anywhere in release-docs.yml")
def a7(c):
    f = []
    for ln in joined(c.text).split("\n"):
        for m in re.finditer(r"\bgit\b(?:\s+-c\s+\S+)*\s+add\b(.*)", ln):
            args = re.split(r"\s*(?:;|&&|\|\||\|)\s*", m.group(1))[0].split()
            if any(a == "--force" or re.match(r"^-[A-Za-z]*f[A-Za-z]*$", a) for a in args):
                f.append("force-add: %s" % ln.strip())
    return f


@check("A8", "the PR body always passes --verifier")
def a8(c):
    lines = [ln for s in c.sync["steps"] for ln in (s["j"] or "").split("\n") if "--pr-body" in ln]
    f = []
    if len(lines) != 1:
        f.append("%d --pr-body commands, want 1" % len(lines))
    elif not re.search(r'--verifier "\$RUNNER_TEMP/verifier\.json"', lines[0]):
        f.append("the --pr-body command does not pass --verifier unconditionally")
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
    args = c.claude_args() or ""
    ok = re.findall(r"--model\s+(\S+)", args) == ["claude-opus-5-5"]
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


@check("A14", "after the model, only the sealed copies run: post-checks and --pr-body from $RUNNER_TEMP/rd")
def a14(c):
    f = []
    if 'bash "$RUNNER_TEMP/rd/post-checks.sh"' not in ((c.step("post") or {}).get("j") or ""):
        f.append("the authoritative post-checks do not run from $RUNNER_TEMP/rd")
    body = [ln for s in c.sync["steps"] for ln in (s["j"] or "").split("\n") if "--pr-body" in ln]
    if not body or not body[0].strip().startswith('bash "$RUNNER_TEMP/rd/docs-detect.sh"'):
        f.append("--pr-body does not run from $RUNNER_TEMP/rd")
    for s in c.after_claude():
        if re.search(r"\.claude/skills/release-docs/scripts/|\.github/scripts/", s["j"] or ""):
            f.append("%r runs a script from the checkout after the model" % (s["name"] or s["id"]))
    pj = (c.step("prepare") or {}).get("j") or ""
    if 'cp -R .claude/skills/release-docs/scripts "$RUNNER_TEMP/rd"' not in pj:
        f.append("the prepare step does not copy the scripts to $RUNNER_TEMP/rd")
    return f


@check("A15", "the sealed copies are made read-only before the model runs")
def a15(c):
    pj = (c.step("prepare") or {}).get("j") or ""
    m = re.search(r"^chmod -R a-w (.*)$", pj, re.M)
    if not m:
        return ["the prepare step has no chmod -R a-w"]
    f = []
    for need in ('"$RUNNER_TEMP/rd"', '"$RUNNER_TEMP/before.snap"', '"$RUNNER_TEMP/obligations.before.json"',
                 '"$RUNNER_TEMP/assert-claude-run-complete.sh"'):
        if need not in m.group(1):
            f.append("chmod -R a-w does not cover %s" % need)
    at = m.start()
    for last in ('--out "$RUNNER_TEMP/obligations.before.json"', ".release-docs/run/"):
        if pj.find(last) > at:
            f.append("chmod -R a-w runs before %s is written" % last)
    if pj.find("seal=") >= 0 and pj.find('s="$(seal') < at:
        f.append("the seal digest is taken before chmod -R a-w")
    pi, ci = c.index(lambda s: s["id"] == "prepare"), c.claude_index()
    if pi is None or ci is None or not pi < ci:
        f.append("the prepare step does not come before the Claude step")
    return f


@check("A16", "the seal is verified after the model and before anything uses the copies")
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
    for sid in ("post",):
        if unwrap(c.step(sid)["if"]) != "!cancelled() && steps.seal.outcome == 'success'":
            f.append("the %s step runs without a verified seal" % sid)
    body = next((s for s in c.sync["steps"] if "--pr-body" in (s["j"] or "")), None)
    if not body or "steps.seal.outcome == 'success'" not in unwrap(body["if"]):
        f.append("the PR body step runs without a verified seal")
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
        f.append("the gate step does not refuse when the seal step did not succeed")
    return f


@check("A18", "every git add, commit and push runs with hooks and fsmonitor off")
def a18(c):
    f, n = [], 0
    for s in c.sync["steps"]:
        for ln in (s["j"] or "").split("\n"):
            for m in re.finditer(r"\bgit\b((?:\s+-c\s+\S+)*)\s+(add|commit|push)\b", ln):
                n += 1
                if "-c core.hooksPath=/dev/null" not in m.group(1) or "-c core.fsmonitor=false" not in m.group(1):
                    f.append("git %s without core.hooksPath=/dev/null and core.fsmonitor=false: %s"
                             % (m.group(2), ln.strip()))
    return f + ([] if n >= 3 else ["found %d git add/commit/push commands, want at least 3" % n])


@check("A19", "a push needs a report that opens with the write fence's result")
def a19(c):
    f = []
    gj = (c.step("gate") or {}).get("j") or ""
    for need in ('report="$RUNNER_TEMP/post-checks.md"', 'fence_line="$(head -n 1 "$report")"',
                 '"- ok: write fence") ;;', '"- FAIL: "*|"- FENCE: "*) [ "$POST_RC" = 1 ] || refuse'):
        if need not in gj:
            f.append("the gate step lacks %r" % need)
    if not re.search(r"^\s*\*\) refuse ", gj[gj.find('case "$fence_line"'):], re.M):
        f.append("the gate step does not refuse a report that opens with anything else")
    if '[ -f "$report" ] && [ ! -L "$report" ] || refuse' not in gj:
        f.append("the gate step does not refuse a missing report")
    # The strings the gate trusts are the ones the fence and post-checks write.
    if '["- ok: write fence"], "ok"' not in c.fence:
        f.append('fence.py no longer reports a clean fence as "- ok: write fence"')
    if not re.search(r'"- FENCE: ', c.fence) or not re.search(r'"- FAIL: ', c.fence):
        f.append("fence.py no longer opens its lines with - FENCE: / - FAIL:")
    fi = c.post_sh.find('fence_out="$(bash "$HERE/docs-detect.sh" --fence')
    if fi < 0 or re.search(r"^\s*say\s+\"", c.post_sh[:fi], re.M) or 'say "$body"' not in c.post_sh[fi:]:
        f.append("post-checks.sh no longer writes the fence's lines first in its report")
    return f


@check("A20", "the scripts are allowed one by one: no directory-prefix rule, no run-all, no node --check")
def a20(c):
    have = c.allowed()
    f = []
    bash = [t for t in have if t.startswith("Bash(")]
    if sorted(bash) != sorted(SCRIPT_RULES + OTHER_BASH):
        f.append("the Bash rules are %s, want %s" % (bash, SCRIPT_RULES + OTHER_BASH))
    if any(t.endswith("/:*)") for t in have):
        f.append("a directory-prefix rule is allowed")
    if any("node" in t for t in have):
        f.append("node --check is allowed")
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


@check("A22", "DOCS_BOT_TOKEN is read only by the push step; the Claude step gets only the OAuth secret")
def a22(c):
    f = []
    refs = re.findall(r"secrets\.([A-Z_]+)", c.text)
    if sorted(refs) != ["CLAUDE_CODE_OAUTH_TOKEN", "DOCS_BOT_TOKEN"]:
        f.append("secrets read: %s, want CLAUDE_CODE_OAUTH_TOKEN and DOCS_BOT_TOKEN once each" % refs)
    for s in c.sync["steps"]:
        if "secrets.DOCS_BOT_TOKEN" in s["raw"] and not re.search(r"\bgit\b[^\n]*\bpush\b", s["j"] or ""):
            f.append("%r reads DOCS_BOT_TOKEN but does not push" % (s["name"] or s["id"]))
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


@check("A25", "the completion guard runs always(), after the model, from its sealed copy")
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
    return f


@check("A26", "permissions are minimal per job", yaml_only=True)
def a26(c):
    want = {None: {"contents": "read"}, "detect": {"contents": "read"},
            "dispatch": {"actions": "write", "contents": "read"}, "sync": {"contents": "read"}}
    f = []
    for jid, perms in want.items():
        got = c.y.get("permissions") if jid is None else (c.y["jobs"].get(jid) or {}).get("permissions")
        if got != perms:
            f.append("%s permissions are %s, want %s" % (jid or "workflow", got, perms))
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
# (check id, [(file, old, new, count)], label). Each must make exactly its check report.
S = "          "
MUTANTS = [
    ("A1", [(WF, "    if: github.event_name == 'workflow_dispatch' && needs.detect.outputs.open != '0'\n",
             "    if: needs.detect.outputs.open != '0'\n", 1)], "sync also runs on pull_request"),
    ("A2", [(WF, "    if: github.event_name == 'pull_request' && needs.detect.outputs.open != '0'\n",
             "    if: needs.detect.outputs.open != '0'\n", 1)], "dispatch also runs on workflow_dispatch"),
    ("A2", [(WF, " && github.event.pull_request.head.repo.full_name == github.repository)", ")", 1)],
     "detect drops the same-repo check"),
    ("A3", [(WF, S + 'bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot "$T/before.snap"\n', "", 1),
            (WF, S + 'git switch -c "$branch"\n',
             S + 'git switch -c "$branch"\n' + S + 'bash .claude/skills/release-docs/scripts/post-checks.sh --snapshot "$T/before.snap"\n', 1)],
     "snapshot taken after the branch"),
    ("A4", [(WF, ' --expect-clean \\\n', ' \\\n', 1)], "post-checks without --expect-clean"),
    ("A5", [(WF, '--report "$RUNNER_TEMP/post-checks.md"', '--report .release-docs/run/post-checks.md', 1)],
     "report inside the checkout"),
    ("A6", [(WF, "steps.post.outputs.rc == '1')", "steps.post.outputs.rc == '2')", 1)], "push on rc 2"),
    ("A6", [(WF, "!cancelled() && steps.gate.outputs.publish == 'true' && inputs.dry_run == false",
             "!cancelled() && inputs.dry_run == false", 1)], "push without the gate"),
    ("A7", [(WF, S + "if git diff --cached --quiet; then\n",
             S + "git -c core.hooksPath=/dev/null -c core.fsmonitor=false add -f .github/docs-surfaces.json\n"
             + S + "if git diff --cached --quiet; then\n", 1)], "force-add"),
    ("A8", [(WF, '--before "$T/obligations.before.json" --verifier "$T/verifier.json" \\\n',
             '--before "$T/obligations.before.json" \\\n', 1)], "PR body without --verifier"),
    ("A9", [(WF, S + "github_token: ${{ github.token }}\n", "", 1)], "no github_token"),
    ("A10", [(WF, "756cc22e19660d20e8cc9496b4f242475a7f7790 # v1.0.235",
              "0000000000000000000000000000000000000000 # v1.0.231", 1)], "another action pin"),
    ("A11", [(WF, "--model claude-opus-5-5", "--model claude-sonnet-5", 1)], "another model"),
    ("A12", [(WF, "Agent,Task,", "Agent,", 1)], "Task not allowed"),
    ("A13", [(VAL, "    if: github.event_name == 'pull_request' && github.base_ref == 'main'\n",
              "    if: github.event_name == 'pull_request'\n", 1)], "gate on every PR"),
    ("A14", [(WF, 'bash "$RUNNER_TEMP/rd/post-checks.sh"', "bash .claude/skills/release-docs/scripts/post-checks.sh", 1)],
     "post-checks from the checkout"),
    ("A15", [(WF, S + 'chmod -R a-w "$T/rd" "$T/assert-claude-run-complete.sh" "$T/before.snap" "$T/obligations.before.json"\n',
              "", 1)], "no chmod"),
    ("A16", [(WF, '[ -n "$SEAL" ] && [ "$s" = "$SEAL" ] || {', '[ -n "$s" ] || {', 1)], "seal compared to nothing"),
    ("A16", [(WF, "if: ${{ !cancelled() && steps.seal.outcome == 'success' }}\n        run: |\n          set +e\n",
              "if: ${{ !cancelled() && steps.claude.outcome != 'skipped' }}\n        run: |\n          set +e\n", 1)],
     "post-checks without a verified seal"),
    ("A17", [(WF, 'for f in "$HOME/.gitconfig" "$HOME/.config/git/config"; do',
              'for f in "$HOME/.config/git/config"; do', 2)], "global .gitconfig not hashed"),
    ("A18", [(WF, "git -c core.hooksPath=/dev/null -c core.fsmonitor=false \\\n            push -q",
              "git -c core.fsmonitor=false \\\n            push -q", 1)], "push with hooks on"),
    ("A19", [(WF, "*) refuse \"the post-checks report does not open with the write fence's result\" ;;", "*) ;;", 1)],
     "any report accepted"),
    ("A20", [(WF, ",".join(SCRIPT_RULES), "Bash(bash .claude/skills/release-docs/scripts/:*)", 1)],
     "directory-prefix rule"),
    ("A20", [(WF, "og-regen.sh:*),Bash(git diff:*)", "og-regen.sh:*),Bash(bash tests/run-all.sh),Bash(git diff:*)", 1)],
     "run-all allowed"),
    ("A21", [(WF, "allowed_bots: 'github-actions[bot]'", "allowed_bots: '*'", 1)], "every bot allowed"),
    ("A22", [(WF, "          GH_TOKEN: ${{ github.token }}\n          REPO:", "          GH_TOKEN: ${{ secrets.DOCS_BOT_TOKEN }}\n          REPO:", 1)],
     "dispatch reads DOCS_BOT_TOKEN"),
    ("A23", [(WF, '[[ "$RELEASE_PR" =~ ^([1-9][0-9]{0,9})?$ ]] \\', '[[ "${{ inputs.release_pr }}" =~ ^([1-9][0-9]{0,9})?$ ]] \\', 1)],
     "an input interpolated into run:"),
    ("A24", [(WF, "          ref: ${{ needs.detect.outputs.sha }}\n          fetch-depth: 0\n          persist-credentials: false\n",
              "          ref: ${{ needs.detect.outputs.sha }}\n          fetch-depth: 0\n", 1)], "checkout keeps credentials"),
    ("A25", [(WF, 'bash "$RUNNER_TEMP/assert-claude-run-complete.sh"', ".github/scripts/assert-claude-run-complete.sh", 1)],
     "guard from the checkout"),
    ("A26", [(WF, "    permissions:\n      contents: read\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1\n        with:\n          ref: ${{ needs.detect.outputs.sha }}",
              "    permissions:\n      contents: write\n    steps:\n      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1\n        with:\n          ref: ${{ needs.detect.outputs.sha }}", 1)],
     "sync gets contents: write"),
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
