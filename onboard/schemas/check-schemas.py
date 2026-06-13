#!/usr/bin/env python3
"""Validate onboard JSON example fixtures against their schemas.

For each onboard/schemas/examples/<name>.example.json, validate it against:
  - onboard/skills/generate/references/<name>.json   when name == "context-shape-v3"
  - onboard/schemas/<name>.json                       otherwise

Exit 0 when every example validates (or none exist), 1 on a missing schema or a
validation error, 2 when the jsonschema dev dependency is absent.
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


def main():
    examples = sorted(glob.glob(os.path.join(EXAMPLES_DIR, "*.example.json")))
    if not examples:
        print("0 examples found — nothing to validate")
        return 0
    failures = 0
    for ex in examples:
        name = os.path.basename(ex)[: -len(".example.json")]
        schema_path = schema_path_for(name)
        if not os.path.isfile(schema_path):
            print(f"FAIL {name}: schema not found at {schema_path}", file=sys.stderr)
            failures += 1
            continue
        with open(schema_path) as f:
            schema = json.load(f)
        with open(ex) as f:
            instance = json.load(f)
        try:
            jsonschema.validate(instance, schema)
            print(f"OK   {name}")
        except jsonschema.ValidationError as err:
            print(f"FAIL {name}: {err.message} (at path {list(err.path)})", file=sys.stderr)
            failures += 1
    if failures:
        print(f"{failures} example(s) failed", file=sys.stderr)
        return 1
    print(f"{len(examples)} example(s) validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
