#!/usr/bin/env bash
# test_docs_detect_pages.sh — badge-version, card-description, og-copy, page-missing,
# inventory-count, inventory-row and --fix-mechanical (release-docs spec § 5).
# shellcheck disable=SC2016
# SC2015: each `check && echo ok || fail` reporter is intended — echo cannot fail, so fail runs
# exactly when the check does.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"

# T3-CLEAN: the synced fixture has no page or inventory obligation.
fx_repo clean
detect
for k in badge-version card-description og-copy page-missing inventory-count inventory-row; do
  expect "T3-CLEAN no $k" 0 "$(count "$k")"
done

# T3-BADGE: a bump leaves nav, footer and landing badges stale; --fix-mechanical fixes exactly those.
fx_repo badge
bump 1.1.0 '- One.'
detect
expect "T3-BADGE three badge-version" 3 "$(count badge-version)"
expect "T3-BADGE expected field" "1.1.0" "$(field badge-version expected)"
cp site/alpha/index.html "$SCRATCH/before.html"
bash "$DETECT" --fix-mechanical >/dev/null
detect
expect "T3-BADGE fixed" 0 "$(count badge-version)"
expect "T3-BADGE fixer touched only the two badge lines" 2 \
  "$(diff "$SCRATCH/before.html" site/alpha/index.html | grep -c '^>')"

# T3-AMP: the card compare is entity-aware; the fixer writes &amp;.
fx_repo amp
detect
expect "T3-AMP escaped card equals the manifest's &" 0 "$(count card-description)"
python3 - <<'PY'
import json
for f in (".claude-plugin/marketplace.json", "alpha/.claude-plugin/plugin.json"):
    d = json.load(open(f))
    (d["plugins"][0] if "plugins" in d else d)["description"] = "Alpha does x & y now."
    json.dump(d, open(f, "w"))
PY
detect
expect "T3-AMP changed description -> card-description" 1 "$(count card-description)"
bash "$DETECT" --fix-mechanical >/dev/null
grep -q '<p class="pcard-desc">Alpha does x &amp; y now.</p>' site/index.html \
  && echo "ok: T3-AMP fixer wrote &amp;" || fail "T3-AMP card text: $(grep pcard-desc site/index.html)"
detect
expect "T3-AMP fixed" 0 "$(count card-description)"

# T3-OG: a changed og:title, and a page with no og entry.
fx_repo og
sed -i.bak 's/<meta property="og:title" content="alpha — fixture">/<meta property="og:title" content="alpha — changed">/' site/alpha/index.html
detect
expect "T3-OG changed og:title" 1 "$(count og-copy site/alpha/index.html)"
case "$(field og-copy detail)" in *"og:title"*) echo "ok: T3-OG names the key" ;; *) fail "T3-OG detail: $(field og-copy detail)" ;; esac
python3 -c "import json; p='.github/docs-surfaces.json'; d=json.load(open(p)); d['og'].pop('site/index.html'); json.dump(d, open(p,'w'))"
detect
expect "T3-OG missing entry" 1 "$(count og-copy site/index.html)"

# T3-MISSING: a new marketplace plugin with no page and no landing card.
fx_repo missing
python3 - <<'PY'
import json
d = json.load(open(".claude-plugin/marketplace.json"))
d["plugins"].append({"name": "beta", "source": "./beta", "version": "0.1.0", "description": "Beta."})
json.dump(d, open(".claude-plugin/marketplace.json", "w"))
PY
put beta/.claude-plugin/plugin.json '{"name":"beta","version":"0.1.0","description":"Beta."}'
detect
expect "T3-MISSING page + card" 2 "$(count page-missing)"

# T3-COUNT: a new skill and a new agent make the stats wrong; a new user skill is missing from the table.
fx_repo count
put alpha/skills/fly/SKILL.md '---' 'name: fly' 'description: Flies.' '---'
put alpha/agents/second.md '# Second'
detect
expect "T3-COUNT skills + agents stats" 2 "$(count inventory-count)"
expect "T3-COUNT fly missing from the table (+ root CLAUDE.md skills + agents lists)" 3 "$(count inventory-row)"
expect "T3-COUNT table row names the skill" "fly" "$(field inventory-row item)"

# T3-PHANTOM: a /alpha:gone row for a skill that does not exist.
fx_repo phantom
sed -i.bak 's#<tr><td class="slash">core</td>#<tr><td class="slash">/alpha:gone</td><td>x</td></tr><tr><td class="slash">core</td>#' site/alpha/index.html
detect
expect "T3-PHANTOM phantom row" 1 "$(count inventory-row site/alpha/index.html)"

# T3-PREFIX: skills render + render-review; the table has only /alpha:render-review.
fx_repo prefix
put alpha/skills/render/SKILL.md '---' 'name: render' 'description: R.' '---'
put alpha/skills/render-review/SKILL.md '---' 'name: render-review' 'description: RR.' '---'
sed -i.bak 's#<tr><td class="slash">core</td>#<tr><td class="slash">/alpha:render-review [x]</td><td>x</td></tr><tr><td class="slash">core</td>#' site/alpha/index.html
detect
python3 - "$OUT" <<'PY' && echo "ok: T3-PREFIX render missing, render-review present" || fail "T3-PREFIX items wrong"
import json, sys
items = {o.get("item") for o in json.load(open(sys.argv[1]))["obligations"]
         if o["kind"] == "inventory-row" and o["file"] == "site/alpha/index.html"}
sys.exit(0 if "render" in items and "render-review" not in items else 1)
PY

# T3-NOAGENTS: a plugin with no agents dir and no agents stat or list invents nothing.
fx_repo noagents
rm -rf alpha/agents
sed -i.bak 's#<div class="hstat"><div class="v">1</div><div class="l">agents</div></div>##' site/alpha/index.html
sed -i.bak 's/                ├── skills\/ (run, core)/                └── skills\/ (run, core)/; /agents\/ (checker)/d' CLAUDE.md
detect
expect "T3-NOAGENTS no inventory-count" 0 "$(count inventory-count)"
expect "T3-NOAGENTS no inventory-row" 0 "$(count inventory-row)"

# T3-REMOVED-PLUGIN: a landing card and a site page left behind for a plugin the marketplace dropped.
fx_repo removedplugin
python3 - <<'PY'
p = "site/index.html"
card = ('<a class="pcard" href="./gone/" aria-label="gone"><div class="pcard-name">gone '
        '<span class="pcard-ver">v0.1.0</span></div>\n<p class="pcard-desc">Gone.</p></a>\n')
t = open(p).read()
open(p, "w").write(t.replace("</section></main></body></html>", card + "</section></main></body></html>"))
PY
mkdir -p site/gone && fx_page 0.1.0 > site/gone/index.html
detect
expect "T3-REMOVED-PLUGIN card + page flagged" 2 \
  "$(python3 -c "import json; print(sum(1 for o in json.load(open('$OUT'))['obligations'] if o['kind']=='stale-mention' and o.get('token')=='gone'))")"

# T3-ALLOWED: the write-fence list holds the surfaces, the ledger and every plugin page path.
fx_repo allowed
bash "$DETECT" --allowed-paths > "$SCRATCH/allowed.lst"
for p in site/index.html site/alpha/index.html alpha/README.md CLAUDE.md .github/docs-ledger.json \
         .github/docs-surfaces.json site/og.png; do
  grep -qxF "$p" "$SCRATCH/allowed.lst" && echo "ok: T3-ALLOWED $p" || fail "T3-ALLOWED missing $p"
done
grep -qxF alpha/CHANGELOG.md "$SCRATCH/allowed.lst" && fail "T3-ALLOWED lists a CHANGELOG"

exit "$failures"
