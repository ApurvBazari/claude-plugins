"""inventory-count / inventory-row: skills and agents on disk vs. what the docs list — the plugin
page's stats and skill table, and the root CLAUDE.md architecture tree."""
import os
import re

import audit
import surfaces
from kinds import ob

STAT = re.compile(r'<div class="v">(?:<em>)?([^<]+?)(?:</em>)?</div><div class="l">([^<]+)</div>')
SLASH = re.compile(r'<td class="slash">([^<]+)</td>')
FRONT = re.compile(r"\A---\n(.*?)\n---", re.S)


def skills(ctx, pdir):
    """{skill name: user_invocable} from <pdir>/skills/*/SKILL.md frontmatter."""
    out, root = {}, ctx.path(pdir + "/skills")
    if not os.path.isdir(root):
        return out
    for d in sorted(os.listdir(root)):
        f = os.path.join(root, d, "SKILL.md")
        if not os.path.isfile(f):
            continue
        with open(f, encoding="utf-8") as fh:
            m = FRONT.match(fh.read().replace("\r\n", "\n"))
        front = m.group(1) if m else ""
        name = re.search(r"^name:\s*['\"]?([a-z0-9-]+)", front, re.M)
        hidden = re.search(r"^user-invocable:\s*false\s*$", front, re.M)
        out[name.group(1) if name else d] = hidden is None
    return out


def agents(ctx, pdir):
    root = ctx.path(pdir + "/agents")
    if not os.path.isdir(root):
        return []
    return sorted(f[:-3] for f in os.listdir(root) if f.endswith(".md"))


def _names(cell, plugin, skill):
    """A table cell names the skill: the bare name, or /plugin:skill followed by a non-name char."""
    return cell == skill or re.match(r"/%s:%s(?![\w-])" % (re.escape(plugin), re.escape(skill)),
                                     cell) is not None


def _tree_list(block, label):
    m = re.search(re.escape(label) + r"/ \(([^)]*)\)", block, re.S)
    if not m:
        return None
    return {w.strip(" │\n\t") for w in m.group(1).split(",") if w.strip(" │\n\t")}


def _page(ctx, p, page, sk, ag):
    obs, text = [], ctx.read(page)
    want = {"skills": len(sk), "user skills": sum(1 for v in sk.values() if v), "agents": len(ag)}
    for value, label in STAT.findall(text):
        label, value = label.strip(), value.strip()
        if label in want and value.isdigit() and int(value) != want[label]:
            obs.append(ob("inventory-count", p["name"], page, "stat '%s' says %s, disk has %d"
                          % (label, value, want[label]), expected=want[label], found=int(value)))
    cells = [c.strip() for c in SLASH.findall(text)]
    for s in sk:
        if not any(_names(c, p["name"], s) for c in cells):
            obs.append(ob("inventory-row", p["name"], page,
                          "skill %s is not in the page's skill table" % s, item=s))
    for c in cells:
        m = re.match(r"/%s:([a-z0-9-]+)" % re.escape(p["name"]), c)
        if m and m.group(1) not in sk:
            obs.append(ob("inventory-row", p["name"], page, "table row for /%s:%s, which no longer "
                          "exists" % (p["name"], m.group(1)), item=m.group(1)))
    return obs


def _tree(p, claude, sk, ag):
    obs, start = [], claude.find("──→ %s/" % p["dir"])
    if start < 0:
        # A new plugin is exactly this case, and nothing else catches it (doc-audit's
        # PLUGIN_NOT_IN_ROOT reads only the root README).
        if sk or ag:
            obs.append(ob("inventory-row", p["name"], "CLAUDE.md",
                          "root CLAUDE.md tree has no entry for %s" % p["name"]))
        return obs
    end = claude.find("──→ ", start + 4)
    block = claude[start:end if end > 0 else len(claude)]
    for label, have in (("skills", set(sk)), ("agents", set(ag))):
        listed = _tree_list(block, label)
        if listed is None:
            if have:
                obs.append(ob("inventory-row", p["name"], "CLAUDE.md",
                              "root CLAUDE.md tree has no %s/ list for %s" % (label, p["name"])))
        elif listed != have:
            obs.append(ob("inventory-row", p["name"], "CLAUDE.md", "root CLAUDE.md %s list %s ≠ disk %s"
                          % (label, sorted(listed), sorted(have))))
    return obs


def check(ctx, surf):
    obs = []
    claude = ctx.read("CLAUDE.md") if ctx.exists("CLAUDE.md") else ""
    for p in ctx.plugins():
        sk, ag = skills(ctx, p["dir"]), agents(ctx, p["dir"])
        page = surfaces.page_of(surf, p["name"])
        if ctx.exists(page):
            obs.extend(_page(ctx, p, page, sk, ag))
        obs.extend(_tree(p, claude, sk, ag))
    return obs + audit.check(ctx)
