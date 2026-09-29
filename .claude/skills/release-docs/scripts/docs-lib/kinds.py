"""Obligation kinds, who resolves each, and the one obligation constructor."""

KINDS = ("badge-version", "card-description", "inventory-count", "inventory-row",
         "prerequisite-new", "stale-mention", "changelog-entry", "page-missing", "og-copy")

RESOLVER = {"badge-version": "script", "card-description": "script",
            "inventory-count": "model", "inventory-row": "model", "prerequisite-new": "model",
            "stale-mention": "model", "changelog-entry": "model", "page-missing": "model",
            "og-copy": "model"}


def ob(kind, plugin, file, detail, **extra):
    d = {"kind": kind, "plugin": plugin, "file": file, "detail": detail, "resolver": RESOLVER[kind]}
    d.update(extra)
    return d
