#!/usr/bin/env bash
# test_render_check.sh — render-check.sh passes a good page and fails the four ways a site page
# broke or could break: a " inside DET (blank page), a nav link to no section, a section that never
# shows, and horizontal overflow at 500px (release-docs spec § 6).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"

have_chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
  if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then have_chrome=1; break; fi
done
if [ -z "$have_chrome" ] && [ -z "${CHROME:-}" ]; then
  if [ -n "${CI:-}" ]; then fail "no Chrome on a CI runner"; exit "$failures"; fi
  echo "skip: test_render_check (no Chrome here)"; exit 0
fi

page() { # <file> <extra section html> <det entry> <nav target>
  cat > "$1" <<EOF
<!DOCTYPE html><html lang="en" data-theme="dark"><head><meta charset="utf-8"><title>t</title>
<style>section{opacity:0;transition:opacity .2s}section.vis{opacity:1}</style></head><body>
<nav><a href="#top">Top</a><a href="#$4">Two</a></nav><main>
<section id="top"><h1>Top</h1><button data-d="a" onclick="openD('a')">A</button></section>
<section id="two"><p>Two</p>$2</section></main>
<aside id="panel"><div id="pbd"></div></aside>
<script>
const DET={a:{b:"$3"}};
function openD(k){document.getElementById('pbd').innerHTML=DET[k].b;}
function closeD(){}
const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting)e.target.classList.add('vis');}));
document.querySelectorAll('section').forEach(s=>io.observe(s));
</script></body></html>
EOF
}

page "$SCRATCH/good.html" "" "fine" two
page "$SCRATCH/quote.html" "" 'broken " quote' two
page "$SCRATCH/nav.html" "" "fine" missing
page "$SCRATCH/wide.html" '<div style="width:900px">wide</div>' "fine" two
sed 's/<section id="two">/<section id="two" style="display:none">/' "$SCRATCH/good.html" > "$SCRATCH/hidden.html"

run() { RC=0; OUTTXT="$(bash "$RENDER" "$@" 2>&1)" || RC=$?; }

run "$SCRATCH/good.html"
expect "T5-GOOD exit 0" 0 "$RC"
run "$SCRATCH/quote.html"
expect "T5-QUOTE exit 1" 1 "$RC"
case "$OUTTXT" in *"does not parse"*) echo "ok: T5-QUOTE node --check named" ;; *) fail "T5-QUOTE output: $OUTTXT" ;; esac
run "$SCRATCH/nav.html"
expect "T5-NAV exit 1" 1 "$RC"
case "$OUTTXT" in *"nav"*"missing"*) echo "ok: T5-NAV names the target" ;; *) fail "T5-NAV output: $OUTTXT" ;; esac
run "$SCRATCH/hidden.html"
expect "T5-HIDDEN exit 1" 1 "$RC"
case "$OUTTXT" in *"hidden"*"two"*) echo "ok: T5-HIDDEN names the section" ;; *) fail "T5-HIDDEN output: $OUTTXT" ;; esac
run "$SCRATCH/wide.html"
expect "T5-WIDE exit 1" 1 "$RC"
case "$OUTTXT" in *"500px"*"overflow"*) echo "ok: T5-WIDE overflow at 500px" ;; *) fail "T5-WIDE output: $OUTTXT" ;; esac
run --shots "$SCRATCH/shots" "$SCRATCH/good.html"
[ -s "$SCRATCH/shots/good-dark.png" ] && [ -s "$SCRATCH/shots/good-light.png" ] \
  && echo "ok: T5-SHOTS both themes written" || fail "T5-SHOTS missing: $(ls "$SCRATCH/shots" 2>&1)"
run "$SCRATCH/nope.html"
expect "T5-BADINPUT exit 2" 2 "$RC"

exit "$failures"
