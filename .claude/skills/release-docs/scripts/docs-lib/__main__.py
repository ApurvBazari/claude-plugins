"""docs-detect CLI (run as `python3 -B <this dir>` by docs-detect.sh)."""
import json
import sys

import obligations
import repo

USAGE = ("usage: docs-detect.sh [--root DIR] [--range BASE..HEAD] (--out FILE | --gate)\n"
         "       docs-detect.sh [--root DIR] --fix-mechanical | --allowed-paths\n"
         "       docs-detect.sh [--root DIR] --candidates BASE..HEAD\n"
         "       docs-detect.sh [--root DIR] [--range BASE..HEAD] --pr-body --before FILE [--verifier FILE]\n"
         "       docs-detect.sh [--root DIR] --snapshot FILE | --render-pages\n"
         "       docs-detect.sh [--root DIR] --fence --before FILE [--expect-clean]")
VALUED = ("--root", "--range", "--out", "--candidates", "--before", "--verifier", "--snapshot")
FLAGS = ("--gate", "--fix-mechanical", "--allowed-paths", "--pr-body", "--fence", "--render-pages",
         "--expect-clean")


def parse(argv):
    opts, i = {}, 0
    while i < len(argv):
        a = argv[i]
        if a in VALUED:
            if i + 1 >= len(argv):
                raise repo.RepoError("%s needs a value" % a)
            opts[a], i = argv[i + 1], i + 2
        elif a in FLAGS:
            opts[a], i = True, i + 1
        else:
            raise repo.RepoError("unknown argument: %s" % a)
    return opts


def run(opts):
    ctx = repo.Context(opts.get("--root"), opts.get("--range", "origin/main..HEAD"))
    if opts.get("--fix-mechanical"):
        import mechanical
        for line in mechanical.fix(ctx):
            print(line)
        return 0
    if opts.get("--allowed-paths"):
        import surfaces
        for rel in surfaces.allowed_paths(ctx):
            print(rel)
        return 0
    if "--candidates" in opts:
        import stale
        print(json.dumps(stale.range_candidates(ctx.with_range(opts["--candidates"])), indent=2))
        return 0
    if opts.get("--pr-body"):
        import prbody
        if "--before" not in opts:
            raise repo.RepoError("--pr-body needs --before FILE")
        print(prbody.render(ctx, opts["--before"], opts.get("--verifier")))
        return 0
    if "--snapshot" in opts:
        import fence
        fence.snapshot(ctx, opts["--snapshot"])
        return 0
    if opts.get("--fence"):
        import fence
        if "--before" not in opts:
            raise repo.RepoError("--fence needs --before SNAPSHOT")
        try:
            lines, verdict = fence.fence(ctx, opts["--before"], bool(opts.get("--expect-clean")))
        except Exception as e:  # anything unexpected: the fence did not complete, never "fenced"
            sys.stderr.write("docs-detect: fence did not complete: %s\n" % fence.describe(e))
            return 2
        print("\n".join(lines))
        print("%s %s" % (fence.MARKER, verdict))
        return 0 if verdict == "ok" else 1
    if opts.get("--render-pages"):
        import fence
        for rel in fence.render_pages(ctx):
            print(rel)
        return 0
    if "--out" not in opts and "--gate" not in opts:
        raise repo.RepoError("say what to do: --out FILE or --gate")
    report = obligations.collect(ctx)
    if "--out" in opts:
        with open(opts["--out"], "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2, ensure_ascii=False)
            f.write("\n")
    if opts.get("--gate"):
        for o in report["obligations"]:
            print("OPEN %-17s %s — %s" % (o["kind"], o["file"], o["detail"]))
        print("docs-detect: %d open obligation(s)" % report["open"])
        return 1 if report["open"] else 0
    return 0


def main(argv):
    # Bad input exits 2, never with a traceback: exit 1 is the gate's "open obligations" code, so
    # a crash must not masquerade as one. OSError/ValueError are the last line of defence.
    try:
        return run(parse(argv))
    except (repo.RepoError, OSError, ValueError) as e:
        sys.stderr.write("docs-detect: %s\n%s\n" % (e, USAGE))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
