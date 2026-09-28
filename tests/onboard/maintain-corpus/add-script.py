#!/usr/bin/env python3
"""add-script.py <package.json> <name> <run> — add one script, keeping the file's 2-space layout."""
import json
import sys

path, name, run = sys.argv[1:4]
with open(path) as f:
    data = json.load(f)
data.setdefault("scripts", {})[name] = run
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
