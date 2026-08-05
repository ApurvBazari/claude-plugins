#!/usr/bin/env python3
"""Usage: schema-narrowings.py <schema.json>  < <disclosure-text>

Derive every NARROWING the shipped review-findings schema carries over the frozen 1.4.3 baseline
beside this file, and assert each one is named in the disclosure text read from stdin. Exits 0 when
all are named; exits 1 listing the ones that are not.

WHY A WALK AND NOT A CLAUSE LIST. The first version of this check read the success branch's `allOf`
and nothing else, so it derived exactly the two conditional clauses and was blind to the narrowing
expressed as ordinary keywords — `votes`' bounds, which live under `properties`. Most of what JSON
Schema can narrow with is `minimum`/`maximum`/`enum`/`required`/`additionalProperties`, none of which
is a clause, so a clause-only derivation cannot see the ordinary case; the bounds survived disclosure
only because a subject literal happened to be hardcoded beside the derivation.

WHAT COUNTS AS A NARROWING. A constraint narrows only if a document 1.4.3 could produce can reach it:

  * a keyword on a path the 1.4.3 schema also had (a bound on `votes.total`, an `enum` on an existing
    field, a value ADDED to an existing `required`/`enum` list) — reachable, so it is a narrowing;
  * a keyword under a field or section 1.4.3 never had (`degradedReasons`' sealed items, the
    `definitions.errorEnvelope`, the failure branch) — a 1.4.3 document has no such member, so none
    is rejected by it. Field-additive, disclosed by the entry's exhaustive field list instead;
  * a conditional clause is judged by its `if` side alone, which is the half that decides
    reachability: `if degraded (a 1.4.3 field) then require degradedReasons (a new one)` IS the
    narrowing that rejects every 1.4.3 degraded return, and a rule keyed on the `then` side would
    dismiss it as new-field-only.

Constraint identity carries the VALUE, so tightening an existing constraint in place — a member added
to a `required` list, a `minimum` raised — is an added narrowing rather than an unchanged site; and a
constraint the baseline had and the schema no longer does is reported as a widening.

The baseline is the 1.4.3 schema ITSELF, frozen verbatim as review-findings.schema.1.4.3.json rather
than transcribed into a path list here — a hand-copied baseline is a second source of truth that goes
wrong silently, and this one can be diffed against the release it came from.
"""
import json
import os
import sys

# Keywords that REJECT documents. `type` is deliberately absent: every field carries one, so a new
# optional field would read as a narrowing on the strength of having a declared type.
KEYWORDS = ("enum", "const", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum",
            "minItems", "maxItems", "minLength", "maxLength", "pattern", "multipleOf",
            "uniqueItems", "required", "additionalProperties")

CLAUSE = "if/then"
BASELINE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "review-findings.schema.1.4.3.json")


def clause_label(clause):
    """A conditional clause's identity, taken from its own discriminator rather than its index —
    reordering the clauses must not read as three deletions and three additions."""
    cond = clause.get("if") or {}
    parts = sorted(cond.get("required") or [])
    parts += sorted(f"{k}={json.dumps(v['const'])}"
                    for k, v in (cond.get("properties") or {}).items()
                    if isinstance(v, dict) and "const" in v)
    return "if:" + "+".join(parts)


class Walk:
    """Collects every constraint site in a schema. `chain` is the field names crossed to reach a
    site; `foreign` is set once the walk descends into something the baseline did not have, and is
    never unset — a subtree hanging off a 1.5.0-only field cannot reject a 1.4.3 document."""

    def __init__(self, base_nodes):
        self.base_nodes = base_nodes
        self.sites = {}
        self.nodes = set()

    def known(self, path):
        return self.base_nodes is None or path in self.base_nodes

    def descend(self, node, path, chain, foreign):
        self.walk(node, path, chain, foreign or not self.known(path))

    def walk(self, node, path, chain, foreign):
        if not isinstance(node, dict):
            return
        self.nodes.add(path)
        here = (path + ".") if path else ""

        for clause in node.get("allOf") or []:
            if not isinstance(clause, dict):
                continue
            if "if" in clause:
                key = (f"{here}allOf[{clause_label(clause)}]", CLAUSE)
                self.sites[key] = (json.dumps(clause, sort_keys=True), chain, foreign, clause)
            else:
                self.walk(clause, f"{here}allOf[]", chain, foreign)

        for kw in KEYWORDS:
            if kw not in node or (kw == "additionalProperties" and node[kw] is not False):
                continue
            self.sites[(path, kw)] = (json.dumps(node[kw], sort_keys=True), chain, foreign, node)

        for name, sub in (node.get("properties") or {}).items():
            self.descend(sub, f"{here}properties.{name}", chain + (name,), foreign)

        for key in ("items", "not"):
            if isinstance(node.get(key), dict):
                self.descend(node[key], f"{here}{key}", chain, foreign)

        for name, sub in (node.get("definitions") or {}).items():
            self.descend(sub, f"{here}definitions.{name}", chain, foreign)

        # The SUCCESS branch is the channel a 1.4.3 document arrives on, so its clauses are compared
        # against 1.4.3's root rather than treated as a new region — otherwise moving the unchanged
        # required[] down into the branch would read as a fresh constraint. Every other branch is new
        # by construction: a 1.4.3 return has no top-level `error` to land on one.
        for branch in node.get("oneOf") or []:
            if not isinstance(branch, dict):
                continue
            if "error" in (branch.get("required") or []):
                self.walk(branch, f"{here}oneOf[error]", chain, True)
            else:
                self.walk(branch, path, chain, foreign)


def collect(schema, base_nodes=None):
    w = Walk(base_nodes)
    w.walk(schema, "", (), False)
    return w.sites, w.nodes


BASE = collect(json.load(open(BASELINE, encoding="utf-8")))
BASE_SITES = {k: v[0] for k, v in BASE[0].items()}
BASE_NODES = BASE[1]


def subjects(key, value, chain, clause):
    """The field names a reader must be given to know what was narrowed. For a list-valued keyword
    only the ADDED members are the news; for a scalar bound it is the field the bound sits on."""
    path, kw = key
    if kw == CLAUSE:
        cond, then = clause.get("if") or {}, clause.get("then") or {}
        return (set(cond.get("required") or []) | set(cond.get("properties") or {})
                | set(then.get("required") or []) | set(then.get("properties") or {}))
    if kw in ("required", "enum"):
        prior = BASE_SITES.get(key)
        return set(json.loads(value)) - set(json.loads(prior) if prior else [])
    return {chain[-1]} if chain else {path or "the document root"}


def main():
    text = sys.stdin.read()
    sites, _ = collect(json.load(open(sys.argv[1], encoding="utf-8")), BASE_NODES)

    widened = sorted(f"{p}.{kw}" for p, kw in BASE_SITES if (p, kw) not in sites)
    if widened:
        print(f"a 1.4.3 constraint is gone from the schema — that is a WIDENING, and the entry "
              f"promises nothing was removed: {widened}")
        return 1

    narrowings, undisclosed = {}, {}
    for key, (value, chain, foreign, clause) in sorted(sites.items()):
        if BASE_SITES.get(key) == value:
            continue
        if key[1] == CLAUSE:
            cond = clause.get("if") or {}
            triggers = set(cond.get("required") or []) | set(cond.get("properties") or {})
            if any(f"properties.{f}" not in BASE_NODES for f in triggers):
                continue
        elif foreign:
            continue
        subs = subjects(key, value, chain, clause)
        narrowings[key] = subs
        missing = sorted(s for s in subs if s not in text)
        if missing:
            undisclosed[f"{key[0]}.{key[1]}"] = missing

    if not narrowings:
        print("the schema carries no narrowing over the 1.4.3 baseline — the derivation has no "
              "source, so this check would pass against any text at all")
        return 1
    for site, missing in sorted(undisclosed.items()):
        print(f"the schema narrows at {site} on {missing}, which the disclosure does not name")
    return 1 if undisclosed else 0


if __name__ == "__main__":
    sys.exit(main())
