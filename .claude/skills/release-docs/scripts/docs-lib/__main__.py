"""docs-detect CLI (run as `python3 -B <this dir>` by docs-detect.sh)."""
import json
import sys

import obligations
import repo

USAGE = ("usage: docs-detect.sh [--root DIR] [--range BASE..HEAD] (--out FILE | --gate)\n"
         "       docs-detect.sh [--root DIR] --fix-mechanical | --allowed-paths\n"
         "       docs-detect.sh [--root DIR] --candidates BASE..HEAD\n"
         "       docs-detect.sh [--root DIR] [--range BASE..HEAD] --pr-body --before FILE [--verifier FILE]")
VALUED = ("--root", "--range", "--out", "--candidates", "--before", "--verifier")
FLAGS = ("--gate", "--fix-mechanical", "--allowed-paths", "--pr-body")


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
    try:
        return run(parse(argv))
    except repo.RepoError as e:
        sys.stderr.write("docs-detect: %s\n%s\n" % (e, USAGE))
        return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
