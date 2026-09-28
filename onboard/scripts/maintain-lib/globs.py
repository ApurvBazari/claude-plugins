"""Rule `paths:` glob -> regex: `**`, `*`, `?`, `[...]`, `{a,b}`; a glob without '/' matches a
basename at any depth, and a trailing '/' matches everything under that directory."""
import re


def _body(g):
    out, i = [], 0
    while i < len(g):
        c = g[i]
        if g.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
            continue
        if g.startswith("**", i):
            out.append(".*")
            i += 2
            continue
        if c == "*":
            out.append("[^/]*")
        elif c == "?":
            out.append("[^/]")
        elif c == "{" and "}" in g[i:]:
            j = g.index("}", i)
            out.append("(?:" + "|".join(_body(alt) for alt in g[i + 1:j].split(",")) + ")")
            i = j + 1
            continue
        elif c == "[" and "]" in g[i + 1:]:
            j = g.index("]", i + 1)
            inner = g[i + 1:j]
            if inner.startswith("!"):
                inner = "^" + inner[1:]
            out.append("[" + inner.replace("\\", "\\\\") + "]")
            i = j + 1
            continue
        else:
            out.append(re.escape(c))
        i += 1
    return "".join(out)


def glob_regex(glob):
    g = glob.strip()
    if g.startswith("./"):
        g = g[2:]
    g = g.lstrip("/")
    if g.endswith("/"):
        g += "**"
    prefix = "" if "/" in g else "(?:.*/)?"
    return re.compile("^" + prefix + _body(g) + "$")
