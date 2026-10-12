"""House-layout HTML scanners (one layout across site/, see references/page-style.md) and the
checks that read them: badge-version, card-description, og-copy, page-missing, plus
stale-mention for a landing card or site page left behind by a plugin the marketplace dropped."""
import html
import re

import surfaces
from kinds import ob

NAV_BADGE = re.compile(r"(PLUGIN · v)(\d+\.\d+\.\d+)")
FOOT_BADGE = re.compile(r'(<div class="meta">[a-z0-9-]+ · v)(\d+\.\d+\.\d+)')
CARD = re.compile(r'(<a class="pcard" href="\./([a-z0-9-]+)/".*?<span class="pcard-ver">v)'
                  r'(\d+\.\d+\.\d+)(</span>.*?<p class="pcard-desc">)(.*?)(</p>)', re.S)
TITLE = re.compile(r"<title>(.*?)</title>", re.S)
META = re.compile(r'<meta (?:name|property)="([^"]+)" content="([^"]*)"')
OG_KEYS = ("title", "description", "og:title", "og:description", "og:image:alt",
           "twitter:title", "twitter:description", "twitter:image:alt")


def cards(text):
    """{plugin: (version, unescaped description)} for the landing page's grid cards."""
    return {m.group(2): (m.group(3), html.unescape(m.group(5)).strip()) for m in CARD.finditer(text)}


def head_strings(text):
    out = {}
    m = TITLE.search(text)
    if m:
        out["title"] = html.unescape(m.group(1).strip())
    for m in META.finditer(text):
        if m.group(1) in OG_KEYS:
            out[m.group(1)] = html.unescape(m.group(2))
    return out


def _owner(rel, plugins, surf):
    for p in plugins:
        if rel == surfaces.page_of(surf, p["name"]):
            return p["name"]
    return "marketplace"


def _orphans(ctx, surf, plugins, have):
    """A landing card or a site page left behind for a plugin the marketplace no longer lists."""
    names = {p["name"] for p in plugins}
    obs = [ob("stale-mention", n, surf["landing"], "landing card for %s, which the marketplace no "
              "longer lists" % n, token=n, line=0) for n in sorted(have) if n not in names]
    for rel in surfaces.files(ctx, surf):
        parts = rel.split("/")
        if len(parts) == 3 and parts[0] == "site" and parts[2] == "index.html" \
                and parts[1] not in names:
            obs.append(ob("stale-mention", parts[1], rel, "site page for %s, which the marketplace "
                          "no longer lists" % parts[1], token=parts[1], line=0))
    return obs


def check(ctx, surf):
    obs, plugins = [], ctx.plugins()
    landing_rel = surf["landing"]
    have = cards(ctx.read(landing_rel)) if ctx.exists(landing_rel) else {}
    obs.extend(_orphans(ctx, surf, plugins, have))
    for p in plugins:
        page = surfaces.page_of(surf, p["name"])
        if not ctx.exists(page):
            obs.append(ob("page-missing", p["name"], page, "no site page for %s" % p["name"]))
        else:
            text = ctx.read(page)
            for label, rx in (("nav", NAV_BADGE), ("footer", FOOT_BADGE)):
                m = rx.search(text)
                if m and m.group(2) != p["version"]:
                    obs.append(ob("badge-version", p["name"], page, "%s badge v%s ≠ plugin.json %s"
                                  % (label, m.group(2), p["version"]),
                                  expected=p["version"], found=m.group(2)))
        if p["name"] not in have:
            obs.append(ob("page-missing", p["name"], landing_rel,
                          "no landing card for %s" % p["name"]))
            continue
        ver, desc = have[p["name"]]
        if ver != p["version"]:
            obs.append(ob("badge-version", p["name"], landing_rel,
                          "landing badge v%s ≠ plugin.json %s" % (ver, p["version"]),
                          expected=p["version"], found=ver))
        if desc != p["description"]:
            obs.append(ob("card-description", p["name"], landing_rel,
                          "landing card text differs from plugin.json description",
                          expected=p["description"], found=desc))
    for rel in [landing_rel] + [surfaces.page_of(surf, p["name"]) for p in plugins]:
        if not ctx.exists(rel):
            continue
        want = surf["og"].get(rel)
        if want is None:
            obs.append(ob("og-copy", _owner(rel, plugins, surf), rel,
                          "no og entry in surfaces.json for %s" % rel))
            continue
        got = head_strings(ctx.read(rel))
        diff = [k for k in OG_KEYS if got.get(k) != want.get(k)]
        if diff:
            obs.append(ob("og-copy", _owner(rel, plugins, surf), rel,
                          "<head> strings differ from surfaces.json: %s" % ", ".join(diff), keys=diff))
    return obs
