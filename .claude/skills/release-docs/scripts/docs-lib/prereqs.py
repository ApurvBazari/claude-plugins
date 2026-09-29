"""prerequisite-new: a hard dependency that a script changed in range adds, but that no
prerequisites list names. Hard = `command -v X … || <exit N | missing=>` within four lines,
including the `for v in a b; do command -v "$v"` form, or an `if ! command -v X` block that exits
non-zero before its `fi`. A plain `if command -v` is optional and ignored."""
import re

import surfaces
from kinds import ob

CMD_V = re.compile(r'command -v "?\$?\{?([A-Za-z_][\w.+-]*)')
FOR_LOOP = re.compile(r"^\s*for (\w+) in ([^;]+); do")
HARD = re.compile(r"\|\|.*?(exit [1-9]|missing=)")
OPTIONAL = re.compile(r"^\s*(if|elif|while|until)\b")
NEGATED = re.compile(r"^\s*(?:if|elif)\s+!\s*command -v\b")
EXIT = re.compile(r"\bexit [1-9]")
BLOCK_END = re.compile(r"(?:^|;)\s*fi\b")


def _block_exits(lines, i):
    """The `if ! command -v …` block opening on line i exits non-zero before its first `fi`
    (a one-line `…; then …; fi` included). Capped at 30 lines."""
    for j, line in enumerate(lines[i:i + 30]):
        if EXIT.search(line.split(" then", 1)[-1] if j == 0 else line):
            return True
        if BLOCK_END.search(line) and (j > 0 or "then" in line):
            return False
    return False


def deps(script):
    lines, found = script.splitlines(), set()
    for i, line in enumerate(lines):
        if "command -v" not in line:
            continue
        if NEGATED.match(line):
            if not _block_exits(lines, i):
                continue
        elif OPTIONAL.match(line) or not HARD.search(" ".join(lines[i:i + 4])):
            continue
        m = CMD_V.search(line)
        if not m:
            continue
        loop = None
        for j in range(i, max(-1, i - 3), -1):
            loop = FOR_LOOP.match(lines[j])
            if loop:
                break
        if loop and m.group(1) == loop.group(1):
            found.update(loop.group(2).split())
        else:
            found.add(m.group(1))
    return found


def _prereq_section(md):
    m = re.search(r"^#{2,3}\s+(?:prerequisites|requirements)\b.*?$(.*?)(?=^#{1,3}\s|\Z)", md,
                  re.S | re.M | re.I)
    return m.group(1) if m else None


def check(ctx, surf):
    obs, changed = [], ctx.changed_files()
    for p in ctx.plugins():
        scripts = [f for f in changed if f.startswith(p["dir"] + "/scripts/") and f.endswith(".sh")
                   and ctx.exists(f)]
        need = set()
        for f in scripts:
            need |= deps(ctx.read(f))
        if not need:
            continue
        readme_rel = p["dir"] + "/README.md"
        readme = ctx.read(readme_rel) if ctx.exists(readme_rel) else None
        section = _prereq_section(readme) if readme is not None else None
        page_rel = surfaces.page_of(surf, p["name"])
        page = ctx.read(page_rel) if ctx.exists(page_rel) else None  # a missing page is page-missing's
        by = ", ".join(scripts)
        for dep in sorted(need):
            lead = re.compile(r"^\s*[-*]\s+[*`]*%s[*`]*(?![\w-])" % re.escape(dep), re.M)
            if readme is not None and section is None:
                obs.append(ob("prerequisite-new", p["name"], readme_rel, "%s is required by %s but "
                              "the README has no Prerequisites section: add a Prerequisites section "
                              "naming it" % (dep, by), item=dep))
            elif section is not None and not lead.search(section):
                obs.append(ob("prerequisite-new", p["name"], readme_rel, "%s is required by %s but is "
                              "not a README Prerequisites bullet" % (dep, by), item=dep))
            if page is not None and "prerequisites" not in page.lower():
                obs.append(ob("prerequisite-new", p["name"], page_rel, "%s is required by %s but "
                              "the page has no prerequisites area: add a prerequisites grid naming it"
                              % (dep, by), item=dep))
            elif page is not None and '<div class="n">%s</div>' % dep not in page:
                obs.append(ob("prerequisite-new", p["name"], page_rel, "%s is required by %s but is "
                              "not in the page's prerequisites" % (dep, by), item=dep))
    return obs
