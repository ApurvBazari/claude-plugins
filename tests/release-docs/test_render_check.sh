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

# a DET entry that throws when opened, with no [data-d] element pointing at it — the shape of the
# real handoff/lens/notify/walkthrough pages, which open details via onclick="openSurface(...)"
# rather than a data-d button, so the only way to reach the throw is to walk Object.keys(DET).
cat > "$SCRATCH/detboom.html" <<'EOF'
<!DOCTYPE html><html lang="en" data-theme="dark"><head><meta charset="utf-8"><title>t</title>
<style>section{opacity:0;transition:opacity .2s}section.vis{opacity:1}</style></head><body>
<nav><a href="#top">Top</a><a href="#two">Two</a></nav><main>
<section id="top"><h1>Top</h1></section>
<section id="two"><p>Two</p></section></main>
<aside id="panel"><div id="pbd"></div></aside>
<script>
const DET={a:{b:"fine"},boom:null};
function openD(k){document.getElementById('pbd').innerHTML=DET[k].b;}
function closeD(){}
const io=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting)e.target.classList.add('vis');}));
document.querySelectorAll('section').forEach(s=>io.observe(s));
</script></body></html>
EOF

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
run "$SCRATCH/detboom.html"
expect "T5-DETBOOM exit 1" 1 "$RC"
case "$OUTTXT" in *"openD() threw"*) echo "ok: T5-DETBOOM catches a DET key with no data-d" ;; *) fail "T5-DETBOOM output: $OUTTXT" ;; esac
run --shots "$SCRATCH/shots" "$SCRATCH/good.html"
[ -s "$SCRATCH/shots/good-dark.png" ] && [ -s "$SCRATCH/shots/good-light.png" ] \
  && echo "ok: T5-SHOTS both themes written" || fail "T5-SHOTS missing: $(ls "$SCRATCH/shots" 2>&1)"

# a stale PNG left in the shots dir (e.g. from an earlier render-check.sh run) must be replaced, not
# reported as this run's — mkstemp-free rm-before-write, verified by checking the PNG magic bytes.
printf 'not a png' > "$SCRATCH/shots/good-dark.png"
run --shots "$SCRATCH/shots" "$SCRATCH/good.html"
magic="$(head -c 8 "$SCRATCH/shots/good-dark.png" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
case "$magic" in 89504e470d0a1a0a*) echo "ok: T5-STALE-SHOT replaced with a real PNG" ;; *) fail "T5-STALE-SHOT magic: $magic" ;; esac

RENDER_TIMEOUT=abc run "$SCRATCH/good.html"
expect "T5-BADTIMEOUT exit 2" 2 "$RC"
case "$OUTTXT" in *"RENDER_TIMEOUT"*) echo "ok: T5-BADTIMEOUT names the var" ;; *) fail "T5-BADTIMEOUT output: $OUTTXT" ;; esac

# RENDER_TIMEOUT feeds bash arithmetic (limit=$(( RENDER_TIMEOUT * 2 ))), which reads a leading 0 as
# octal: "08" is not valid octal and used to crash (exit 1, no per-page line — the digit check let it
# through); "017" is valid octal 15 and used to silently run as if RENDER_TIMEOUT were 15, not 17.
RENDER_TIMEOUT=08 run "$SCRATCH/good.html"
expect "T5-BADTIMEOUT-08 exit 0, no crash" 0 "$RC"
case "$OUTTXT" in *"ok   "*) echo "ok: T5-BADTIMEOUT-08 ran (no octal crash)" ;; *) fail "T5-BADTIMEOUT-08 output: $OUTTXT" ;; esac

# "017" must be read as decimal 17 (limit=34), not octal 15 (limit=30) — traced directly from the
# real script's own `limit=$(( RENDER_TIMEOUT * 2 ))` line via bash -x, then killed immediately
# (this case does not need Chrome to actually finish, only that first arithmetic step).
xtrace="$SCRATCH/xtrace017.log"
: > "$xtrace"
RENDER_TIMEOUT=017 bash -x "$RENDER" "$SCRATCH/good.html" >/dev/null 2>"$xtrace" &
xpid=$!
i=0
while [ $i -lt 20 ] && ! grep -q '++ limit=' "$xtrace" 2>/dev/null; do sleep 0.2; i=$((i + 1)); done
limit_line="$(grep -m1 '++ limit=' "$xtrace" 2>/dev/null)"
kill "$xpid" 2>/dev/null
wait "$xpid" 2>/dev/null
pkill -f "render-check\." 2>/dev/null
case "$limit_line" in
  *"limit=34"*) echo "ok: T5-BADTIMEOUT-017 reads 017 as decimal 17 (limit=34), not octal 15 (limit=30)" ;;
  *) fail "T5-BADTIMEOUT-017 limit line: $limit_line" ;;
esac

# spec § 10's single retry: a CHROME= stand-in distinguishes the retry attempt (its profile dir
# carries a "-r2" suffix — see render-check.sh's probe_verdict/shot) so the retry path can be
# exercised deterministically, without depending on real Chrome flakiness. It logs one line per
# invocation so the count proves exactly one retry per width (2 widths => 4 lines), never more.
cat > "$SCRATCH/fake-chrome.sh" <<'EOF'
#!/usr/bin/env bash
args="$*"
echo "$args" >> "${FAKE_CHROME_LOG:?}"
case "$args" in
  *"-r2"*)
    if [ "${FAKE_CHROME_MODE:-}" = recovers ]; then
      echo 'RCPROBE:{"errors":[],"hidden":[],"empty":[],"badNav":[],"badKeys":[],"openErrors":[],"width":1400,"scrollWidth":1400}:ENDPROBE'
    fi
    ;;
esac
exec sleep 9999
EOF
chmod +x "$SCRATCH/fake-chrome.sh"

: > "$SCRATCH/fake-chrome-recovers.log"
CHROME="$SCRATCH/fake-chrome.sh" FAKE_CHROME_MODE=recovers FAKE_CHROME_LOG="$SCRATCH/fake-chrome-recovers.log" RENDER_TIMEOUT=2 \
  run "$SCRATCH/good.html"
expect "T5-RETRY-RECOVERS exit 0" 0 "$RC"
lines="$(wc -l < "$SCRATCH/fake-chrome-recovers.log" | tr -d ' ')"
[ "$lines" = 4 ] && echo "ok: T5-RETRY-RECOVERS retried exactly once per width (4 calls)" \
  || fail "T5-RETRY-RECOVERS call count: $lines"

: > "$SCRATCH/fake-chrome-hangs.log"
CHROME="$SCRATCH/fake-chrome.sh" FAKE_CHROME_MODE=hangs FAKE_CHROME_LOG="$SCRATCH/fake-chrome-hangs.log" RENDER_TIMEOUT=2 \
  run "$SCRATCH/good.html"
expect "T5-RETRY-GIVES-UP exit 1" 1 "$RC"
case "$OUTTXT" in *"the probe never reported"*) echo "ok: T5-RETRY-GIVES-UP names the failure" ;; *) fail "T5-RETRY-GIVES-UP output: $OUTTXT" ;; esac
lines="$(wc -l < "$SCRATCH/fake-chrome-hangs.log" | tr -d ' ')"
[ "$lines" = 4 ] && echo "ok: T5-RETRY-GIVES-UP stopped after exactly one retry per width (4 calls, not more)" \
  || fail "T5-RETRY-GIVES-UP call count: $lines"

run "$SCRATCH/nope.html"
expect "T5-BADINPUT exit 2" 2 "$RC"

exit "$failures"
