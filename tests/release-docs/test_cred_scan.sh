#!/usr/bin/env bash
# test_cred_scan.sh — cred_scan.py refuses a credential-shaped string a release-docs run added, and
# nothing else (final review I6; SDD ruling R30 a and b).
#
# The scan is the last look before anything a run produced becomes public: sync runs it over its
# bundle before the upload, publish over the staged tree, the report and the PR body before the
# summary, the upload and the push. So the belt pins both directions:
# - a token of each family is refused wherever it lands (a text file, a binary one, a named file, a
#   file under a named directory), by file and line, and is never printed;
# - a mention is not a token: a bare prefix, a placeholder, an identifier that merely contains a
#   prefix, and a string HEAD's copy of the file already had all pass;
# - anything the scan cannot read is bad input (exit 2), never a pass.
#
# The tokens are built at run time, so this file holds no credential-shaped string itself. Then
# each rule is taken out of a scratch copy of the script, and every such mutant must fail a case.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python3 - "$ROOT/.claude/skills/release-docs/scripts/cred_scan.py" <<'PY'
import os
import shutil
import subprocess
import sys
import tempfile

SCRIPT = sys.argv[1]
ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
ALNUM = b"Zq3Xw7Lm9Kp2Vt5Rb8Nc4Hd6Fy1Js0Tu"
MARK = ALNUM[:8]  # every built tail starts with it: seen in the output, the scan printed a token


def tail(n, extra=b""):
    """n characters no prose produces: letters and digits, plus extra where a family allows it."""
    src = ALNUM + extra
    return (src * (n // len(src) + 1))[:n]


def gh(kind, n=36):
    return b"gh" + kind + b"_" + tail(n)


def pat(n=22, rest=True):
    return b"github" + b"_pat_" + tail(n) + (b"_" + tail(59) if rest else b"")


def ant(n=95):
    """n characters after the prefix, shaped like an OAuth token."""
    return b"sk" + b"-ant-" + b"oat01-" + tail(n - 6, b"-_")


class Scratch:
    """A scratch repository (r/) with one base commit, and a directory beside it (x/) for the
    listing and the named files, which a run's `git add -A` must not see."""

    def __init__(self, base):
        self.tmp = os.path.realpath(tempfile.mkdtemp())
        self.r, self.x = os.path.join(self.tmp, "r"), os.path.join(self.tmp, "x")
        os.makedirs(self.r)
        os.makedirs(self.x)
        self.git("init", "-q")
        for rel, data in base.items():
            self.put(rel, data)
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", "base")

    def git(self, *a):
        return subprocess.run(["git", "-c", "user.name=b", "-c", "user.email=b@x.invalid",
                               "-c", "commit.gpgsign=false"] + list(a), cwd=self.r, env=ENV,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True).stdout

    def put(self, rel, data, root=None):
        path = os.path.join(root or self.r, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as fh:
            fh.write(data)
        return path

    def other(self, rel, data):
        return self.put(rel, data, self.x)

    def staged(self):
        """The listing publish's stage step and sync's bundle step write."""
        self.git("add", "-A")
        return self.other("staged.raw", self.git("diff", "--cached", "--raw", "-z", "--no-renames",
                                                 "--no-abbrev", "HEAD"))

    def scan(self, script, *args):
        p = subprocess.run([sys.executable, "-B", script] + list(args), cwd=self.r, env=ENV,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return p.returncode, p.stdout.decode("utf-8", "replace")

    def close(self):
        shutil.rmtree(self.tmp)


def judge(rc, out, want_rc, *needles):
    f = []
    if rc != want_rc:
        f.append("exit %d, want %d" % (rc, want_rc))
    f += ["the output lacks %r" % n for n in needles if n not in out]
    if MARK.decode() in out:
        f.append("the scan printed the token itself")
    return ["%s — output: %r" % (x, out.strip()) for x in f]


def case_clean(s, script):
    s.put("a.md", b"one\ntwo\n")
    return judge(*s.scan(script, "--staged", s.staged()), 0, "1 changed and 0 other files scanned, 0 refused")


def added_text(token, label):
    def case(s, script):
        s.put("docs/new.md", b"# title\n\nkey " + token + b" here\n")
        return judge(*s.scan(script, "--staged", s.staged()), 1, "::error::", "(%s...)" % label,
                     '"docs/new.md"', "line 3", "1 refused")
    return case


def case_binary(s, script):
    s.put("site/og.png", b"\x89PNG\r\n\x1a\n\x00\x00" + gh(b"s") + b"\x00\x00IEND")
    f = judge(*s.scan(script, "--staged", s.staged()), 1, "(ghs_...)", '"site/og.png"', "binary")
    return f


def case_replace_ref(s, script):
    # A replace ref makes git show another object's content under a blob's name. The scan reads
    # the blob the commit would carry.
    s.put("docs/new.md", b"key " + gh(b"s") + b"\n")
    listing = s.staged()
    real = s.git("hash-object", "docs/new.md").decode().strip()
    s.other("clean.md", b"key removed\n")
    clean = s.git("hash-object", "-w", os.path.join(s.x, "clean.md")).decode().strip()
    s.git("replace", real, clean)
    return judge(*s.scan(script, "--staged", listing), 1, "(ghs_...)", '"docs/new.md"')


def case_head_had_it(s, script):
    s.put("old.md", b"see " + gh(b"p") + b"\nand a new line\n")
    return judge(*s.scan(script, "--staged", s.staged()), 0, "0 refused")


def case_second_copy(s, script):
    s.put("old.md", b"see " + gh(b"p") + b"\nagain " + gh(b"p") + b"\n")
    return judge(*s.scan(script, "--staged", s.staged()), 1, '"old.md"', "(ghp_...)")


def case_deleted(s, script):
    os.remove(os.path.join(s.r, "old.md"))
    return judge(*s.scan(script, "--staged", s.staged()), 0, "1 changed", "0 refused")


HARMLESS = [
    b"blocks the ghp_ prefix",
    b"and gho_ ghu_ ghs_ ghr_ too",
    b"an Anthropic key starts with sk-ant-",
    b"a fine-grained token starts with github_pat_",
    b"weighs_total is a counter",
    b"export GH_TOKEN=ghp_...",
    b"ANTHROPIC_API_KEY=sk-ant-api03-...",
    b"ANTHROPIC_API_KEY=sk-ant-api03-your-key-goes-here",
    b"set github_pat_token_for_the_release_docs_bot",
    b"one short: " + gh(b"p", 19),
    b"one short: " + pat(19, rest=False),
    b"one short: " + ant(39),
]


def case_harmless(s, script):
    s.put("docs/prose.md", b"\n".join(HARMLESS) + b"\n")
    f = judge(*s.scan(script, "--staged", s.staged()), 0, "0 refused")
    body = s.other("pr-body.md", b"\n".join(HARMLESS) + b"\n")
    return f + judge(*s.scan(script, body), 0, "0 refused")


def at_minimum(token, label):
    def case(s, script):
        s.put("docs/new.md", token + b"\n")
        return judge(*s.scan(script, "--staged", s.staged()), 1, "(%s...)" % label, "line 1")
    return case


def case_glued(s, script):
    s.put("docs/new.md", b"https://x.invalid/?token%3D" + gh(b"s") + b"\n\"k\": \"v\\u003d" + gh(b"o") + b"\"\n")
    return judge(*s.scan(script, "--staged", s.staged()), 1, "(ghs_...)", "line 1", "(gho_...)", "line 2")


def case_named_file(s, script):
    body = s.other("pr-body.md", b"## Post-checks\nclaim: " + gh(b"o") + b"\n")
    return judge(*s.scan(script, body), 1, "(gho_...)", "pr-body.md", "line 2",
                 "0 changed and 1 other files scanned, 1 refused")


def case_named_file_is_whole(s, script):
    # A named file has no earlier copy to compare with: what HEAD held is no excuse for it.
    body = s.other("pr-body.md", b"see " + gh(b"p") + b"\n")
    s.put("old.md", b"see " + gh(b"p") + b"\nmore\n")
    return judge(*s.scan(script, "--staged", s.staged(), body), 1, "pr-body.md",
                 "1 changed and 1 other files scanned, 1 refused")


def case_directory(s, script):
    s.other("bundle/shots/a.png", b"\x89PNG\x00clean")
    s.other("bundle/post-checks.md", b"- ok: write fence\n")
    d = os.path.join(s.x, "bundle")
    f = judge(*s.scan(script, d), 0, "0 changed and 2 other files scanned, 0 refused")
    s.other("bundle/deep/er/verifier.json", b'[\n {"reason": "' + ant() + b'"}\n]\n')
    return f + judge(*s.scan(script, d), 1, "(sk-ant-...)", "verifier.json", "line 2",
                     "0 changed and 3 other files scanned, 1 refused")


def case_skip(s, script):
    # sync's bundle: the patch file repeats lines START already had, and --staged covers what it adds.
    s.other("bundle/sync.patch", b"-old line " + gh(b"p") + b"\n")
    s.other("bundle/post-checks.md", b"- ok: write fence\n")
    d = os.path.join(s.x, "bundle")
    skip = ["--skip", os.path.join(d, "sync.patch")]
    f = judge(*s.scan(script, *(skip + [d])), 0, "0 changed and 1 other files scanned, 0 refused")
    s.other("bundle/verifier.json", b'["' + gh(b"s") + b'"]\n')
    f += judge(*s.scan(script, *(skip + [d])), 1, "(ghs_...)", "verifier.json", "0 changed and 2 other files scanned, 1 refused")
    rc, out = s.scan(script, *(skip + [d]))
    return f + (["the skipped file is reported — output: %r" % out] if "sync.patch" in out else [])


def bad_input(build):
    def case(s, script):
        return judge(*s.scan(script, *build(s)), 2, "cred-scan:")
    return case


def link(s, rel):
    s.other("real.md", b"fine\n")
    path = os.path.join(s.x, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    os.symlink(os.path.join(s.x, "real.md"), path)
    return path


def entry(new, path=b"gone.md"):
    return b":100644 100644 " + b"0" * 40 + b" " + new + b" M\0" + path + b"\0"


def no_such_blob(s):
    return s.other("staged.raw", entry(b"a" * 40))


def not_an_object_id(s):
    # git would resolve this to old.md's blob, token and all: only an object id is read.
    return s.other("staged.raw", entry(b"HEAD:old.md"))


def trailing_bytes(s):
    s.put("a.md", b"one\ntwo\n")
    with open(s.staged(), "ab") as fh:
        fh.write(b"trailing")
    return os.path.join(s.x, "staged.raw")


def cut_mid_entry(s):
    s.put("a.md", b"one\ntwo\n")
    with open(s.staged(), "ab") as fh:
        fh.write(entry(b"a" * 40).split(b"\0")[0] + b"\0")
    return os.path.join(s.x, "staged.raw")


OLD = {"old.md": b"see " + gh(b"p") + b"\n"}
CASES = [
    ("a clean change passes", {"a.md": b"one\n"}, case_clean),
    ("an added GitHub token is refused, by file and line", {}, added_text(gh(b"s"), "ghs_")),
    ("an added fine-grained token is refused", {}, added_text(pat(), "github_pat_")),
    ("an added Anthropic token is refused", {}, added_text(ant(), "sk-ant-")),
    ("a token in a binary file is refused", {}, case_binary),
    ("a replace ref does not hide a token", {}, case_replace_ref),
    ("a token HEAD's copy already had is not refused", OLD, case_head_had_it),
    ("a second copy of a token the file already had is refused", OLD, case_second_copy),
    ("a deleted file is not refused", OLD, case_deleted),
    ("prefixes, placeholders and near-misses pass", {}, case_harmless),
    ("20 characters after a GitHub prefix is a token", {}, at_minimum(gh(b"p", 20), "ghp_")),
    ("20 characters after github_pat_ is a token", {}, at_minimum(pat(20, rest=False), "github_pat_")),
    ("40 characters after sk-ant- is a token", {}, at_minimum(ant(40), "sk-ant-")),
    ("a token glued to an escape is refused", {}, case_glued),
    ("a token in a named file is refused, by line", {}, case_named_file),
    ("a named file is scanned whole, whatever HEAD held", OLD, case_named_file_is_whole),
    ("a named directory is walked", {}, case_directory),
    ("a skipped path is left out of a directory, and only it", {}, case_skip),
    ("nothing to scan is bad input", {}, bad_input(lambda s: [])),
    ("a missing path is bad input", {}, bad_input(lambda s: [os.path.join(s.x, "nope.md")])),
    ("a symlink is bad input", {}, bad_input(lambda s: [link(s, "body.md")])),
    ("a symlink under a directory is bad input", {}, bad_input(lambda s: [os.path.dirname(link(s, "b/shots/l.png"))])),
    ("a missing listing is bad input", {}, bad_input(lambda s: ["--staged", os.path.join(s.x, "nope.raw")])),
    ("a malformed listing is bad input", {}, bad_input(lambda s: ["--staged", s.other("staged.raw", b"junk\0a.md\0")])),
    ("an unreadable blob is bad input", {}, bad_input(lambda s: ["--staged", no_such_blob(s)])),
    ("a listing entry that names no object id is bad input", OLD, bad_input(lambda s: ["--staged", not_an_object_id(s)])),
    ("bytes after the last listing entry are bad input", {"a.md": b"one\n"}, bad_input(lambda s: ["--staged", trailing_bytes(s)])),
    ("a listing cut mid-entry is bad input", {"a.md": b"one\n"}, bad_input(lambda s: ["--staged", cut_mid_entry(s)])),
    ("an unknown option is bad input", {}, bad_input(lambda s: ["--stagd", s.staged()])),
]


def run(name, script):
    """[problems] of one case, for the scan at script."""
    base, case = next((b, c) for n, b, c in CASES if n == name)
    s = Scratch(base)
    try:
        return case(s, script)
    except Exception as e:
        return ["raised %s: %s" % (type(e).__name__, e)]
    finally:
        s.close()


failed = False
for name, _base, _case in CASES:
    problems = run(name, SCRIPT)
    for p in problems:
        print("FAIL: %s: %s" % (name, p))
    if not problems:
        print("ok: %s" % name)
    failed = failed or bool(problems)
if failed:
    sys.exit(1)

# Each rule, taken out of a scratch copy of the script, must fail the case that is there for it:
# (what the mutant does, the text replaced, its replacement, the case).
GH_RULE, PAT_RULE, ANT_RULE = "(gh[pousr]_)[A-Za-z0-9]{20,}", "(github_pat_)[A-Za-z0-9]{20,}", "(sk-ant-)[A-Za-z0-9_-]{40,}"
ADDED = "if len(lines) > len(was.get(k, ()))"
LSTAT = ('        mode = os.lstat(path).st_mode\n    except OSError as e:\n'
         '        bad("could not read %s (%s)" % (json.dumps(path), type(e).__name__))\n')
MUTANTS = [
    ("a bare GitHub prefix is a token", GH_RULE, GH_RULE.replace("{20,}", "*"), "prefixes, placeholders and near-misses pass"),
    ("a GitHub token needs 21 characters", GH_RULE, GH_RULE.replace("20", "21"), "20 characters after a GitHub prefix is a token"),
    ("a bare github_pat_ is a token", PAT_RULE, PAT_RULE.replace("{20,}", "*"), "prefixes, placeholders and near-misses pass"),
    ("underscores count toward github_pat_'s minimum", PAT_RULE, PAT_RULE.replace("9]{", "9_]{"),
     "prefixes, placeholders and near-misses pass"),
    ("a fine-grained token needs 21 characters", PAT_RULE, PAT_RULE.replace("20", "21"), "20 characters after github_pat_ is a token"),
    ("fine-grained tokens are not scanned", '\n    rb"|' + PAT_RULE + '[A-Za-z0-9_]*"', "", "an added fine-grained token is refused"),
    ("a bare sk-ant- is a token", ANT_RULE, ANT_RULE.replace("{40,}", "*"), "prefixes, placeholders and near-misses pass"),
    ("an Anthropic token needs 41 characters", ANT_RULE, ANT_RULE.replace("40", "41"), "40 characters after sk-ant- is a token"),
    ("Anthropic tokens are not scanned", '    rb"' + ANT_RULE + '"\n    rb"|', '    rb"', "an added Anthropic token is refused"),
    ("a token must follow a non-word character", 'rb"|(gh[pousr]_)', 'rb"|(?<![A-Za-z0-9_])(gh[pousr]_)',
     "a token glued to an escape is refused"),
    ("lines count from 0", 'data.count(b"\\n", 0, m.start()) + 1', 'data.count(b"\\n", 0, m.start())',
     "an added GitHub token is refused, by file and line"),
    ("what HEAD's copy had is refused too", ADDED, "if True", "a token HEAD's copy already had is not refused"),
    ("a second copy of a known token passes", ADDED, "if k not in was", "a second copy of a token the file already had is refused"),
    ("replace refs are honoured", ',\n                       env=dict(os.environ, GIT_NO_REPLACE_OBJECTS="1"))', ")",
     "a replace ref does not hide a token"),
    ("the old blob is not read", "creds(blob(meta[2]))", "creds(b\"\")", "a token HEAD's copy already had is not refused"),
    ("the token is printed", "by_prefix[prefix].update(lines)", "by_prefix[_token].update(lines)",
     "an added GitHub token is refused, by file and line"),
    ("a binary file gets line numbers", '"(binary)" if b"\\0" in data else ', "", "a token in a binary file is refused"),
    ("a refusal exits 0", "return 1 if refused else 0", "return 0", "an added GitHub token is refused, by file and line"),
    ("named files are not scanned", "others = [whole(f) for p in paths for f in plain_files(p, skip)]", "others = []",
     "a token in a named file is refused, by line"),
    ("a named file is compared with nothing, and passes", "return path, data, creds(data)", "return path, data, {}",
     "a named file is scanned whole, whatever HEAD held"),
    ("a directory is not walked", "        out += plain_files(os.path.join(path, name), skip)\n", "        pass\n",
     "a named directory is walked"),
    ("--skip is taken and ignored", "os.path.normpath(path) == os.path.normpath(skip)", "False",
     "a skipped path is left out of a directory, and only it"),
    ("--skip leaves out its whole directory", "os.path.normpath(path) == os.path.normpath(skip)",
     "os.path.dirname(os.path.normpath(skip)).startswith(os.path.normpath(path))",
     "a skipped path is left out of a directory, and only it"),
    ("a symlink is followed", LSTAT, LSTAT.replace("os.lstat", "os.stat"), "a symlink is bad input"),
    ("a symlink under a directory is followed", LSTAT, LSTAT.replace("os.lstat", "os.stat"),
     "a symlink under a directory is bad input"),
    ("a missing path is skipped", LSTAT, LSTAT.split("        bad(")[0] + "        return []\n", "a missing path is bad input"),
    ("nothing to scan passes", '        bad("nothing to scan")\n', "        pass\n", "nothing to scan is bad input"),
    ("a missing listing is an empty one", '        bad("could not read the listing %s (%s)" % (json.dumps(listing), type(e).__name__))\n',
     "        return []\n", "a missing listing is bad input"),
    ("a malformed entry is skipped", '            bad("unreadable listing entry %s" % json.dumps(raw[i].decode("ascii", "replace")))\n',
     "            continue\n", "a malformed listing is bad input"),
    ("anything git can resolve is read", ' or not all(re.fullmatch(r"[0-9a-f]{40,64}", s) for s in meta[2:4])', "",
     "a listing entry that names no object id is bad input"),
    ("an unreadable blob is an empty one", '        bad("could not read the blob %s" % sha)\n', "        return b\"\"\n",
     "an unreadable blob is bad input"),
    ("trailing bytes are dropped", 'if raw.pop() != b"" or len(raw) % 2:', 'if raw.pop() is None or len(raw) % 2:',
     "bytes after the last listing entry are bad input"),
    ("a half entry is not noticed", 'if raw.pop() != b"" or len(raw) % 2:', 'if raw.pop() != b"":',
     "a listing cut mid-entry is bad input"),
    ("an unknown option is skipped", '            bad("unknown or incomplete option %s" % json.dumps(argv[i]))\n', "            i += 1\n",
     "an unknown option is bad input"),
]
with open(SCRIPT, encoding="utf-8") as fh:
    src = fh.read()
missed = []
tmp = tempfile.mkdtemp()
try:
    mutant = os.path.join(tmp, "cred_scan.py")
    for label, old, new, target in MUTANTS:
        if src.count(old) != 1:
            missed.append("the anchor for the mutant %r is found %d times, want 1" % (label, src.count(old)))
            continue
        with open(mutant, "w", encoding="utf-8") as fh:
            fh.write(src.replace(old, new))
        try:
            compile(src.replace(old, new), mutant, "exec")
        except SyntaxError as e:
            missed.append("the mutant %r is not valid Python (%s): it would fail any case" % (label, e.msg))
            continue
        if not run(target, mutant):
            missed.append("the mutant %r does not fail the case %r" % (label, target))
finally:
    shutil.rmtree(tmp)
for m in missed:
    print("FAIL: %s" % m)
if missed:
    sys.exit(1)
print("ok: every rule is needed (%d mutants each fail their case)" % len(MUTANTS))
PY
