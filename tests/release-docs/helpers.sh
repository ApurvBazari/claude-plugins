#!/usr/bin/env bash
# Usage: source "$ROOT/tests/release-docs/helpers.sh"   (after defining ROOT and fail())
#
# Scratch marketplace fixtures for the release-docs belts: one plugin, `alpha`, whose site page,
# landing card, README, CHANGELOG and root CLAUDE.md tree are all in sync — committed on `main`,
# with `develop` checked out on top. Sourced, never executed: the name deliberately does not match
# tests/run-all.sh's discovery pattern.

# DETECT, POST, RENDER, OUT and RC are read by the belts that source this file.
# shellcheck disable=SC2034
DETECT="$ROOT/.claude/skills/release-docs/scripts/docs-detect.sh"
# shellcheck disable=SC2034
POST="$ROOT/.claude/skills/release-docs/scripts/post-checks.sh"
# shellcheck disable=SC2034
RENDER="$ROOT/.claude/skills/release-docs/scripts/render-check.sh"

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=belt GIT_AUTHOR_EMAIL=belt@example.invalid
export GIT_COMMITTER_NAME=belt GIT_COMMITTER_EMAIL=belt@example.invalid

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/release-docs-belt.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT

# put <path> <line...> — write a file (parents created), lines joined by newlines.
put() {
  local path="$1"
  shift
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$@" > "$path"
}

# expect <what> <expected> <actual>
expect() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else fail "$1 — expected [$2], got [$3]"; fi
}

fx_page() { # <version> — alpha's plugin page in the house layout
  cat <<EOF
<!DOCTYPE html><html lang="en" data-theme="dark"><head>
<meta charset="utf-8">
<title>alpha — fixture</title>
<meta name="description" content="Alpha page.">
<meta property="og:title" content="alpha — fixture">
<meta property="og:description" content="Alpha page.">
<meta property="og:image:alt" content="card">
<meta name="twitter:title" content="alpha — fixture">
<meta name="twitter:description" content="Alpha page.">
<meta name="twitter:image:alt" content="card">
</head><body>
<nav><div class="nav-links"><a href="#top">Top</a><a href="#skills">Skills</a></div>
<div class="nav-meta"><span class="dot"></span> PLUGIN · v$1</div></nav>
<main>
<section id="top"><h1>alpha</h1>
<div class="hstat"><div class="v"><em>2</em></div><div class="l">skills</div></div>
<div class="hstat"><div class="v">1</div><div class="l">agents</div></div></section>
<section id="skills"><table class="ref-table"><tbody>
<tr><td class="slash">/alpha:run</td><td>Runs.</td></tr>
<tr><td class="slash">core</td><td>Internal.</td></tr>
</tbody></table>
<div class="sec-label">prerequisites</div>
<div class="edge"><div class="n">git</div><div class="t">Required</div></div></section>
<div class="foot"><div class="meta">alpha · v$1 · MIT · by belt</div></div>
</main></body></html>
EOF
}

fx_landing() { # <version> <escaped description>
  cat <<EOF
<!DOCTYPE html><html lang="en" data-theme="dark"><head>
<meta charset="utf-8">
<title>market — fixture</title>
<meta name="description" content="Market page.">
<meta property="og:title" content="market — fixture">
<meta property="og:description" content="Market page.">
<meta property="og:image:alt" content="card">
<meta name="twitter:title" content="market — fixture">
<meta name="twitter:description" content="Market page.">
<meta name="twitter:image:alt" content="card">
</head><body><main><section id="plugins">
<a class="pcard" href="./alpha/" aria-label="alpha"><div class="pcard-name">alpha <span class="pcard-ver">v$1</span></div>
<p class="pcard-desc">$2</p></a>
</section></main></body></html>
EOF
}

fx_og() { # <title> <description> — one surfaces.json og entry
  printf '{"title":"%s","description":"%s","og:title":"%s","og:description":"%s","og:image:alt":"card","twitter:title":"%s","twitter:description":"%s","twitter:image:alt":"card"}' \
    "$1" "$2" "$1" "$2" "$1" "$2"
}

# fx_repo <name> — a fresh, fully-synced marketplace; `main` = the synced base, `develop` checked out.
# Its fixture markdown carries literal backticks.
# shellcheck disable=SC2016
fx_repo() {
  REPO="$SCRATCH/$1"
  mkdir -p "$REPO" && cd "$REPO" || exit 1
  git init -q -b main .
  put .claude-plugin/marketplace.json \
    '{"name":"fx","plugins":[{"name":"alpha","source":"./alpha","version":"1.0.0","description":"Alpha does a & b."}]}'
  put alpha/.claude-plugin/plugin.json \
    '{"name":"alpha","version":"1.0.0","description":"Alpha does a & b."}'
  put alpha/skills/run/SKILL.md '---' 'name: run' 'description: Runs.' '---' '' '# Run'
  put alpha/skills/core/SKILL.md '---' 'name: core' 'description: Core.' 'user-invocable: false' '---' '' '# Core'
  put alpha/agents/checker.md '# Checker'
  put alpha/scripts/tool.sh '#!/usr/bin/env bash' 'echo tool'
  put alpha/README.md '# alpha' '' '## Skills' '' '### `/alpha:run`' '' 'Runs.' '' \
    '## Prerequisites' '' '- **git** — history' '- **jq** (optional) — with a `python3` fallback'
  put alpha/CHANGELOG.md '# Changelog' '' '## 1.0.0 — 2026-01-01' '' '- First release.'
  put CLAUDE.md '# fx' '' '```' '.claude-plugin/marketplace.json' '         │' \
    '         └──→ alpha/                     ← fixture' \
    '                ├── skills/ (run, core)' \
    '                └── agents/ (checker)' '```'
  mkdir -p site/alpha
  fx_page 1.0.0 > site/alpha/index.html
  fx_landing 1.0.0 'Alpha does a &amp; b.' > site/index.html
  mkdir -p .claude/skills/release-docs .github
  printf '{"schemaVersion":1,"surfaces":["site/index.html","site/*/index.html","README.md","CLAUDE.md","{plugin}/README.md","{plugin}/CONVENTIONS.md","{plugin}/references/**/*.md","{plugin}/skills/*/references/**/*.md"],"frozen":["site/*/examples/**"],"landing":"site/index.html","pages":{"alpha":"site/alpha/index.html"},"og":{"site/index.html":%s,"site/alpha/index.html":%s},"retired":[]}\n' \
    "$(fx_og 'market — fixture' 'Market page.')" "$(fx_og 'alpha — fixture' 'Alpha page.')" \
    > .claude/skills/release-docs/surfaces.json
  put .github/docs-ledger.json '{"schemaVersion":1,"entries":{},"intentional":[]}'
  git add -A && git commit -qm base
  git switch -q -c develop
}

# bump <version> <changelog line...> — bump alpha (plugin.json + marketplace) and prepend a
# CHANGELOG section with the given lines; commits on the current branch.
bump() {
  local v="$1"
  shift
  python3 - "$v" <<'PY'
import json, sys
v = sys.argv[1]
for f in (".claude-plugin/marketplace.json", "alpha/.claude-plugin/plugin.json"):
    d = json.load(open(f))
    if "plugins" in d:
        d["plugins"][0]["version"] = v
    else:
        d["version"] = v
    json.dump(d, open(f, "w"))
PY
  { printf '# Changelog\n\n## %s — 2026-02-01\n\n' "$v"; printf '%s\n' "$@"; printf '\n'
    sed '1,2d' alpha/CHANGELOG.md; } > alpha/CHANGELOG.md.new && mv alpha/CHANGELOG.md.new alpha/CHANGELOG.md
  git add -A && git commit -qm "bump $v"
}

# detect [range] — run the detector; OUT is the report path, RC the exit code.
detect() {
  OUT="$SCRATCH/obligations.json"
  rm -f "$OUT"
  RC=0
  bash "$DETECT" --range "${1:-main..HEAD}" --out "$OUT" 2>"$SCRATCH/stderr" || RC=$?
}

# count <kind> [file] — how many open obligations of that kind (optionally in that file).
count() {
  python3 - "$OUT" "$1" "${2:-}" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(sum(1 for o in d["obligations"] if o["kind"] == sys.argv[2] and (not sys.argv[3] or o["file"] == sys.argv[3])))
PY
}

# field <kind> <key> [n] — a field of the n-th obligation of that kind (default 0).
field() {
  python3 - "$OUT" "$1" "$2" "${3:-0}" <<'PY'
import json, sys
hits = [o for o in json.load(open(sys.argv[1]))["obligations"] if o["kind"] == sys.argv[2]]
n = int(sys.argv[4])
print(hits[n].get(sys.argv[3], "") if len(hits) > n else "")
PY
}
