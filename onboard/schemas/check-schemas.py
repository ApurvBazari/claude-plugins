#!/usr/bin/env python3
"""Validate onboard JSON example fixtures against their schemas.

Two fixture classes live in onboard/schemas/examples/:

  - <name>.example.json          — a POSITIVE fixture that MUST validate against
                                   its schema.
  - <schema>--<case>.reject.json — a NEGATIVE fixture that MUST be REJECTED by
                                   the <schema> schema. These pin security/shape
                                   constraints (e.g. custom-specialist agent-path
                                   traversal, unbounded prompts): a reject fixture
                                   that validates is a regression and fails here.

Each fixture is matched to its schema by name:
  - context-shape-v3  -> onboard/skills/generate/references/context-shape-v3.json
  - everything else   -> onboard/schemas/<schema>.json
For a reject fixture, <schema> is the basename up to the first "--".

Exit 0 when every positive fixture validates AND every reject fixture is rejected
(or none exist), 1 on a missing schema, a positive validation error, or a reject
fixture that unexpectedly validated, 2 when the jsonschema dev dependency is absent.
"""
import glob
import json
import os
import sys

try:
    import jsonschema
except ImportError:
    print("ERROR: missing dev dependency — run: python3 -m pip install --user jsonschema",
          file=sys.stderr)
    sys.exit(2)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # -> onboard/
EXAMPLES_DIR = os.path.join(ROOT, "schemas", "examples")


def schema_path_for(name):
    if name == "context-shape-v3":
        return os.path.join(ROOT, "skills", "generate", "references", "context-shape-v3.json")
    return os.path.join(ROOT, "schemas", name + ".json")


def load_schema(schema_name):
    """Return (schema_dict, None) or (None, error_message)."""
    schema_path = schema_path_for(schema_name)
    if not os.path.isfile(schema_path):
        return None, f"schema not found at {schema_path}"
    with open(schema_path) as f:
        return json.load(f), None


def main():
    examples = sorted(glob.glob(os.path.join(EXAMPLES_DIR, "*.example.json")))
    rejects = sorted(glob.glob(os.path.join(EXAMPLES_DIR, "*.reject.json")))
    if not examples and not rejects:
        print("0 fixtures found — nothing to validate")
        return 0
    failures = 0

    # Positive fixtures — each MUST validate.
    for ex in examples:
        name = os.path.basename(ex)[: -len(".example.json")]
        schema, err = load_schema(name)
        if err:
            print(f"FAIL {name}: {err}", file=sys.stderr)
            failures += 1
            continue
        with open(ex) as f:
            instance = json.load(f)
        try:
            jsonschema.validate(instance, schema)
            print(f"OK       {name}")
        except jsonschema.ValidationError as err:
            print(f"FAIL     {name}: {err.message} (at path {list(err.path)})", file=sys.stderr)
            failures += 1

    # Negative fixtures — each MUST be rejected.
    for rj in rejects:
        base = os.path.basename(rj)[: -len(".reject.json")]
        schema_name = base.split("--", 1)[0]
        schema, err = load_schema(schema_name)
        if err:
            print(f"FAIL {base}: {err}", file=sys.stderr)
            failures += 1
            continue
        with open(rj) as f:
            instance = json.load(f)
        try:
            jsonschema.validate(instance, schema)
            print(f"FAIL     {base}: expected schema rejection but it validated", file=sys.stderr)
            failures += 1
        except jsonschema.ValidationError:
            print(f"OK rej   {base}")

    if failures:
        print(f"{failures} fixture(s) failed", file=sys.stderr)
        return 1
    print(f"{len(examples)} positive + {len(rejects)} reject fixture(s) validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
