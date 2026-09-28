"""maintain-detect CLI (run as `python3 -B <this dir>` by scripts/maintain-detect.sh)."""
import json
import os
import sys

import gitview

USAGE = ("usage: maintain-detect.sh --base <ref> --out <path>\n"
         "       maintain-detect.sh --mentioned <script> --package <name|-> "
         "[--manifest <package.json>] <file>...\n"
         "       maintain-detect.sh --lesson-file <glob>...\n"
         "       maintain-detect.sh --lesson-present --id <id> --text <text>")


def _opts(argv, valued):
    """Split argv into {flag: value} for the flags in `valued`, and the remaining words."""
    opts, rest, i = {}, [], 0
    while i < len(argv):
        if argv[i] in valued:
            if i + 1 >= len(argv):
                raise ValueError("%s needs a value" % argv[i])
            opts[argv[i]] = argv[i + 1]
            i += 2
        else:
            rest.append(argv[i])
            i += 1
    return opts, rest


def _bad(msg):
    sys.stderr.write("maintain-detect: %s\n%s\n" % (msg, USAGE))
    return 2


def _repo_rel(top, path):
    return os.path.relpath(os.path.abspath(path), top).replace(os.sep, "/")


def detect_mode(argv):
    import context
    import report
    try:
        opts, rest = _opts(argv, ("--base", "--out"))
    except ValueError as e:
        return _bad(str(e))
    out = os.path.abspath(opts["--out"]) if "--out" in opts else None

    def fail(code, message):
        if out and os.path.isdir(os.path.dirname(out)):
            report.write_atomic(out, report.error(code, message))
        sys.stderr.write("maintain-detect: %s\n" % message)
        return 2

    if rest or "--base" not in opts or out is None:
        return fail("bad-args", "detect needs --base <ref> and --out <path>")
    if not os.path.isdir(os.path.dirname(out)):
        return fail("out-dir-missing", "--out directory does not exist: %s" % os.path.dirname(out))
    try:
        top = gitview.toplevel(os.getcwd())
        result = report.build(context.Context(top, opts["--base"]))
    except gitview.DetectError as e:
        return fail(e.code, e.message)
    except Exception as e:                           # never a traceback in place of a report
        return fail("internal", "%s: %s" % (type(e).__name__, e))
    report.write_atomic(out, result)
    return 0


def mentioned_mode(argv):
    import mentions
    import tooling
    try:
        opts, rest = _opts(argv, ("--package", "--manifest"))
    except ValueError as e:
        return _bad(str(e))
    if len(rest) < 2 or "--package" not in opts:
        return _bad("--mentioned needs <script>, --package and at least one file")
    script, files = rest[0], rest[1:]
    try:
        top = gitview.toplevel(os.getcwd())
    except gitview.DetectError as e:
        return _bad(e.message)
    now = gitview.now_files(top)
    packages = mentions.load_packages(top, now)
    name = None if opts["--package"] == "-" else opts["--package"]
    manifest = _repo_rel(top, opts["--manifest"]) if "--manifest" in opts else None
    pkg_dir = mentions.package_dir_for(packages, name, manifest)
    tlines = tooling.load(top, [_repo_rel(top, f) for f in files])
    refs = mentions.script_mention_refs(tlines, packages, script, name, pkg_dir)
    for ref in refs:
        sys.stdout.write(ref + "\n")
    return 0 if refs else 1


def lesson_file_mode(argv):
    import lessons
    if not argv:
        return _bad("--lesson-file needs at least one glob")
    try:
        top = gitview.toplevel(os.getcwd())
    except gitview.DetectError as e:
        return _bad(e.message)
    sys.stdout.write(json.dumps(lessons.lesson_file(top, argv)) + "\n")
    return 0


def lesson_present_mode(argv):
    import lessons
    try:
        opts, rest = _opts(argv, ("--id", "--text"))
    except ValueError as e:
        return _bad(str(e))
    if rest or "--id" not in opts or "--text" not in opts:
        return _bad("--lesson-present needs --id and --text")
    try:
        top = gitview.toplevel(os.getcwd())
    except gitview.DetectError as e:
        return _bad(e.message)
    result = lessons.lesson_present(top, gitview.now_files(top), opts["--id"], opts["--text"])
    sys.stdout.write(json.dumps(result) + "\n")
    return 0


def main(argv):
    modes = {"--mentioned": mentioned_mode, "--lesson-file": lesson_file_mode,
             "--lesson-present": lesson_present_mode}
    if argv and argv[0] in modes:
        return modes[argv[0]](argv[1:])
    return detect_mode(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
