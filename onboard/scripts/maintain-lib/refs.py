"""reference-broken: rule `paths:` globs that matched at base and match nothing now (D31), and
repo paths run by `.claude/settings.json` hook commands that the diff deleted or renamed (D29)."""
import json
import posixpath
import re

import gitview
from globs import glob_regex
from tooling import paths_field, read_lines

_PROJECT_DIR = re.compile(r"\$\{CLAUDE_PROJECT_DIR\}|\$CLAUDE_PROJECT_DIR(?![A-Za-z0-9_])")
_CMD_SPLIT = re.compile(r"[\s`;&|()<>]+")
_ROOT = "\x00root"


def rule_globs(ctx):
    items = []
    base_files = [f for f in ctx.base_files if not gitview.is_vendor(f)]
    now_files = [f for f in ctx.now_files if not gitview.is_vendor(f)]
    for rel in ctx.tooling_files:
        if not rel.startswith(".claude/rules/"):
            continue
        for glob in paths_field(read_lines(ctx.top, rel)) or []:
            rx = glob_regex(glob)
            if any(rx.match(f) for f in base_files) and not any(rx.match(f) for f in now_files):
                items.append({"kind": "reference-broken", "file": rel, "glob": glob,
                              "disposition": "defer", "reason": "stale-reference",
                              "hint": "edit by hand: the rule's paths: glob matches no file now"})
    return items


def _commands(node):
    if isinstance(node, dict):
        for key, value in sorted(node.items()):
            if key == "command" and isinstance(value, str):
                yield value
            else:
                for cmd in _commands(value):
                    yield cmd
    elif isinstance(node, list):
        for value in node:
            for cmd in _commands(value):
                yield cmd


def hook_paths(command):
    """Repo-relative paths a hook command names: ${CLAUDE_PROJECT_DIR}-anchored, or relative
    tokens containing '/'."""
    out = []
    unquoted = command.replace('"', "").replace("'", "")      # "$CLAUDE_PROJECT_DIR"/x.sh -> one token
    for tok in _CMD_SPLIT.split(_PROJECT_DIR.sub(_ROOT, unquoted)):
        if tok.startswith(_ROOT):
            tok = tok[len(_ROOT):].lstrip("/")
        elif "/" not in tok or tok.startswith(("/", "~", "$", "-")) or "://" in tok:
            continue
        tok = posixpath.normpath(tok[2:] if tok.startswith("./") else tok)
        if tok not in (".", "..") and not tok.startswith("../") and tok not in out:
            out.append(tok)
    return out


def hook_commands(ctx):
    text = gitview.read_now(ctx.top, ".claude/settings.json")
    try:
        settings = json.loads(text) if text else {}
    except ValueError:
        return []
    hooks = settings.get("hooks") if isinstance(settings, dict) else None
    items, seen = [], set()
    for command in _commands(hooks or {}):
        for path in hook_paths(command):
            if path in seen or gitview.is_tooling(path) or path not in ctx.resolver.base_files:
                continue
            broken, renamed_to = ctx.resolver.breakage(path)
            if broken:
                seen.add(path)
                item = {"kind": "reference-broken", "file": ".claude/settings.json", "path": path}
                if renamed_to:
                    item["renamedTo"] = renamed_to
                item.update({"disposition": "defer", "reason": "stale-reference",
                             "hint": "edit by hand: a hook command runs a path the diff "
                                     + ("renamed" if renamed_to else "deleted")})
                items.append(item)
    return items
