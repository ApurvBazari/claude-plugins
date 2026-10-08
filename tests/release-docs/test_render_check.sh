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

# GNU-behaviour mv shim: GNU mv (the CI runner, ubuntu-latest) exits 1 on a same-file move; BSD mv
# (macOS) exits 0, which is why this class of difference only ever showed up in CI. Put ahead of
# PATH for the whole belt so every case here — not just the baseline ones below — sees mv the way
# CI's runner does.
mkdir -p "$SCRATCH/gnu-bin"
cat > "$SCRATCH/gnu-bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
args=("$@")
n=${#args[@]}
if [ "$n" -ge 2 ]; then
  a="${args[$((n - 2))]}"
  b="${args[$((n - 1))]}"
  if [ -e "$a" ] && [ -e "$b" ] && [ "$a" -ef "$b" ]; then
    echo "mv: '$a' and '$b' are the same file" >&2
    exit 1
  fi
fi
exec /bin/mv "$@"
EOF
chmod +x "$SCRATCH/gnu-bin/mv"
export PATH="$SCRATCH/gnu-bin:$PATH"

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

# T5-BASELINE (final review R16, rehearsal #12/#20): the handoff, lens and notify pages already
# overflow at 500px, so a strict check made every run that edits them a needs-owner draft. With
# --baseline DIR (HEAD's copy of each PAGE at DIR/PAGE), an overflow fails only when it grows, or when
# HEAD had none; one that didn't grow is a note, never a failure.
mkdir -p "$SCRATCH/bl/base" "$SCRATCH/bl/tree"
page "$SCRATCH/bl/base/same.html" '<div style="width:700px">wide</div>' "fine" two
page "$SCRATCH/bl/tree/same.html" '<div style="width:700px">wide, and edited</div>' "fine" two
cp "$SCRATCH/bl/base/same.html" "$SCRATCH/bl/base/grow.html"
page "$SCRATCH/bl/tree/grow.html" '<div style="width:800px">wider</div>' "fine" two
page "$SCRATCH/bl/base/fresh.html" "" "fine" two
page "$SCRATCH/bl/tree/fresh.html" '<div style="width:700px">new overflow</div>' "fine" two
page "$SCRATCH/bl/tree/nobase.html" '<div style="width:700px">no HEAD copy</div>' "fine" two
cd "$SCRATCH/bl/tree" || exit 1
run --baseline "$SCRATCH/bl/base" same.html
expect "T5-BASELINE unchanged overflow passes" 0 "$RC"
case "$OUTTXT" in *"ok   same.html"*"pre-existing overflow (unchanged: "*) echo "ok: T5-BASELINE unchanged overflow is a note" ;; *) fail "T5-BASELINE note: $OUTTXT" ;; esac
run --baseline "$SCRATCH/bl/base" grow.html
expect "T5-BASELINE grown overflow fails" 1 "$RC"
case "$OUTTXT" in *"FAIL grow.html"*"grew"*) echo "ok: T5-BASELINE says it grew" ;; *) fail "T5-BASELINE grow: $OUTTXT" ;; esac
run --baseline "$SCRATCH/bl/base" fresh.html
expect "T5-BASELINE overflow HEAD lacked fails" 1 "$RC"
run --baseline "$SCRATCH/bl/base" nobase.html
expect "T5-BASELINE no HEAD copy: strict" 1 "$RC"
run same.html
expect "T5-BASELINE non-vacuous: without --baseline the same page fails" 1 "$RC"

# T5-FONTS (SDD ruling R30 d): a page's width depends on whether its web fonts arrived (the handoff
# page is 547px wide at 500px with them and 536px without), and the page and HEAD's copy are two
# separate renders. So the comparison holds only when both got their fonts the same way: the probe
# reports what did not load, and when the two reports differ the pair is rendered once more. If
# they still differ the page fails as not comparable, never as "grew", and a narrower page is never
# passed on the strength of a render that lacked its fonts.
# A Chrome stand-in prints one probe line per call, chosen by what is rendered (the page p1 or
# HEAD's copy b1), at which width, and on which attempt (-f2 is the second render of the pair).
cat > "$SCRATCH/fake-fonts.sh" <<'EOF'
#!/usr/bin/env bash
args="$*"
echo "$args" >> "${FAKE_CHROME_LOG:?}"
probe() {
  echo "RCPROBE:{\"errors\":[],\"hidden\":[],\"empty\":[],\"badNav\":[],\"badKeys\":[],\"openErrors\":[],\"width\":$1,\"scrollWidth\":$2,\"fonts\":\"$3\"}:ENDPROBE"
}
case "$args" in
  *"--window-size=1400,"*) probe 1400 1400 "" ;;
  *)
    case "$args" in *"/b1.html"*) who=B ;; *) who=P ;; esac
    case "$args" in *"-f2"*) try=2 ;; *) try=1 ;; esac
    v="FAKE_${who}${try}"
    v="${!v:?}"
    probe 500 "${v%%|*}" "${v#*|}"
    ;;
esac
exec sleep 9999
EOF
chmod +x "$SCRATCH/fake-fonts.sh"
NOCSS="1 stylesheet(s) not loaded"
fonts_run() { # <page, 1st render> <HEAD's copy, 1st> <page, 2nd> <HEAD's copy, 2nd>, each "scrollWidth|fonts"
  : > "$SCRATCH/fake-fonts.log"
  CHROME="$SCRATCH/fake-fonts.sh" FAKE_CHROME_LOG="$SCRATCH/fake-fonts.log" RENDER_TIMEOUT=2 \
    FAKE_P1="$1" FAKE_B1="$2" FAKE_P2="$3" FAKE_B2="$4" run --baseline "$SCRATCH/bl/base" same.html
  CALLS="$(wc -l < "$SCRATCH/fake-fonts.log" | tr -d ' ')"
}
fonts_run "547|" "547|" "0|unused" "0|unused"
expect "T5-FONTS same fonts, same width: passes" 0 "$RC"
expect "T5-FONTS same fonts: the pair is rendered once (3 calls)" 3 "$CALLS"
fonts_run "547|" "536|$NOCSS" "547|" "547|"
expect "T5-FONTS lopsided once, then alike: passes" 0 "$RC"
case "$OUTTXT" in *"ok   same.html"*"pre-existing overflow (unchanged: 547px)"*) echo "ok: T5-FONTS judged on the second pair" ;; *) fail "T5-FONTS second pair: $OUTTXT" ;; esac
expect "T5-FONTS lopsided once: the pair is rendered exactly once more (5 calls)" 5 "$CALLS"
fonts_run "547|" "536|$NOCSS" "547|" "536|$NOCSS"
expect "T5-FONTS lopsided twice: fails" 1 "$RC"
case "$OUTTXT" in
  *grew*) fail "T5-FONTS lopsided twice is called growth: $OUTTXT" ;;
  *"FAIL same.html"*"not comparable"*"HEAD's copy: $NOCSS"*) echo "ok: T5-FONTS not comparable, with the reason, never 'grew'" ;;
  *) fail "T5-FONTS lopsided twice: $OUTTXT" ;;
esac
expect "T5-FONTS lopsided twice: no third render (5 calls)" 5 "$CALLS"
fonts_run "536|$NOCSS" "536|$NOCSS" "0|unused" "0|unused"
expect "T5-FONTS neither render got its fonts: comparable, passes" 0 "$RC"
expect "T5-FONTS neither got its fonts: the pair is rendered once (3 calls)" 3 "$CALLS"
fonts_run "536|$NOCSS" "547|" "560|" "547|"
expect "T5-FONTS a narrower page without its fonts is not passed: the second pair shows the growth" 1 "$RC"
case "$OUTTXT" in *"FAIL same.html"*"grew (scrollWidth 560, HEAD's copy 547)"*) echo "ok: T5-FONTS the growth is reported from the second pair" ;; *) fail "T5-FONTS hidden growth: $OUTTXT" ;; esac
# The probe runs inside the page, so everything it reports is the page's to write, the font state
# included. What reads the report cuts it down to plain characters before it is compared or printed:
# it ends up in a PR body.
fonts_run "547|" "536|bad](http://x.invalid) *x* _y_ <b> # h" "547|" "536|bad](http://x.invalid) *x* _y_ <b> # h"
expect "T5-FONTS a font state written to break out of the report: still fails as not comparable" 1 "$RC"
case "$OUTTXT" in
  *"]("*|*"*x*"*|*"_y_"*|*"<b>"*|*"# h"*|*"http://"*) fail "T5-FONTS the state reaches the report as written: $OUTTXT" ;;
  *"not comparable"*"HEAD's copy: bad(http:xinvalid) x y b h)"*) echo "ok: T5-FONTS the state is reduced to plain characters where it is read" ;;
  *) fail "T5-FONTS plain characters: $OUTTXT" ;;
esac
fonts_run "547|" "536|$NOCSS" "490|" "490|"
expect "T5-FONTS the second pair no longer overflows: passes" 0 "$RC"
case "$OUTTXT" in *"pre-existing"*) fail "T5-FONTS a note about an overflow that is not there: $OUTTXT" ;; *"ok   same.html"*) echo "ok: T5-FONTS no overflow, no note" ;; *) fail "T5-FONTS no overflow: $OUTTXT" ;; esac

# T5-FONTS-REAL, in real Chrome: the probe waits for the fonts and reports the state they ended in.
# One page, three things HEAD's copy does not share, each of which must show in the reason:
# - a font that takes 3 seconds to fail, longer than the probe's fixed 2-second settle: the report
#   says it failed, so the probe waited for it; one that measured at 2 seconds would say pending;
# - a linked stylesheet that cannot be reached (nothing listens on port 9);
# - the site pages' own way, an @import in a <style> block, reachable in the page and not in HEAD's
#   copy. A failed import raises no error anywhere and leaves no font to fail: what tells the two
#   renders apart is how many font faces their CSS declared (here four against none).
# The heading's font has a name written to break out of the report it ends up in (markup, a link,
# emphasis), and comes out in plain characters. It is declared twice, one face per character range
# as a web font service does, and both fail: the report names it once.
python3 - "$SCRATCH/slow.port" <<'PY' &
import http.server, os, sys, time
class Slow(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.endswith(".css"):  # a font stylesheet, served at once: one face, used by nothing
            body = b"@font-face{font-family:Web;src:url(/unused.woff2)}"
            self.send_response(200)
            self.send_header("Content-Type", "text/css")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        time.sleep(3)
        self.send_error(404)
    def log_message(self, *a):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), Slow)
open(sys.argv[1] + ".tmp", "w").write(str(s.server_address[1]))
os.rename(sys.argv[1] + ".tmp", sys.argv[1])
s.serve_forever()
PY
slow_pid=$!
i=0
while [ $i -lt 50 ] && [ ! -s "$SCRATCH/slow.port" ]; do sleep 0.1; i=$((i + 1)); done
port="$(cat "$SCRATCH/slow.port" 2>/dev/null)"
sed "s#<style>#<link rel=\"stylesheet\" href=\"http://127.0.0.1:9/x.css\"><style>@import url('http://127.0.0.1:${port:-1}/fonts.css');@font-face{font-family:SlowFace;src:url(http://127.0.0.1:${port:-1}/f.woff2)}body{font-family:SlowFace,sans-serif}@font-face{font-family:\"Bad<b>*_[x](y)\";src:url(http://127.0.0.1:9/b.woff2);unicode-range:U+0-7F}@font-face{font-family:\"Bad<b>*_[x](y)\";src:url(http://127.0.0.1:9/c.woff2);unicode-range:U+80-FF}h1{font-family:\"Bad<b>*_[x](y)\",serif}h1::after{content:\"é\"}#" \
  "$SCRATCH/bl/base/same.html" > "$SCRATCH/bl/tree/webfonts.html"
sed "s#<style>#<style>@import url('http://127.0.0.1:9/fonts.css');#" \
  "$SCRATCH/bl/base/same.html" > "$SCRATCH/bl/base/webfonts.html"
run --baseline "$SCRATCH/bl/base" webfonts.html
expect "T5-FONTS-REAL fonts that ended differently in the page and in HEAD's copy: fails" 1 "$RC"
case "$OUTTXT" in
  *grew*) fail "T5-FONTS-REAL a font difference is called growth: $OUTTXT" ;;
  *"not comparable"*) echo "ok: T5-FONTS-REAL not comparable, never 'grew'" ;;
  *) fail "T5-FONTS-REAL not comparable: $OUTTXT" ;;
esac
case "$OUTTXT" in
  *"page: 4 font face(s) declared; "*"; HEAD's copy: no font faces declared)"*) echo "ok: T5-FONTS-REAL a failed @import shows as no font faces declared" ;;
  *) fail "T5-FONTS-REAL @import: $OUTTXT" ;;
esac
case "$OUTTXT" in
  *"page: "*"; 1 stylesheet(s) not loaded; "*"; HEAD's copy: "*) echo "ok: T5-FONTS-REAL the unreachable stylesheet is reported" ;;
  *) fail "T5-FONTS-REAL stylesheet: $OUTTXT" ;;
esac
case "$OUTTXT" in
  *"page: "*"; failed: "*"SlowFace normal normal"*"; HEAD's copy: "*) echo "ok: T5-FONTS-REAL the probe waited for the slow font, and names it as failed" ;;
  *) fail "T5-FONTS-REAL slow font: $OUTTXT" ;;
esac
case "$OUTTXT" in
  *"<b>"*|*"]("*|*"*_"*) fail "T5-FONTS-REAL a font's name reaches the report as written: $OUTTXT" ;;
  *"; failed: Badbx(y) normal normal, SlowFace normal normal; "*) echo "ok: T5-FONTS-REAL a font's name is reduced to plain characters, and listed once" ;;
  *) fail "T5-FONTS-REAL font name: $OUTTXT" ;;
esac
kill "$slow_pid" 2>/dev/null
wait "$slow_pid" 2>/dev/null
cd "$ROOT" || exit 1

# T5-POST-BASELINE: post-checks renders against HEAD's site/ itself, so the real flow gets the rule.
fx_repo overflow
sed -i.bak 's#<h1>alpha</h1>#<h1>alpha</h1><div style="width:700px">wide nav</div>#' site/alpha/index.html
rm -f site/alpha/index.html.bak
git commit -qam 'an overflowing page'
bash "$POST" --snapshot "$SCRATCH/ov.snap" >/dev/null 2>&1 || fail "T5-POST-BASELINE snapshot"
sed -i.bak 's#<h1>alpha</h1>#<h1>alpha, edited</h1>#' site/alpha/index.html && rm -f site/alpha/index.html.bak
RC=0
RELEASE_DOCS_SKIP=gate,belts bash "$POST" --before "$SCRATCH/ov.snap" --report "$SCRATCH/ov.md" >/dev/null 2>&1 || RC=$?
expect "T5-POST-BASELINE unchanged overflow passes post-checks" 0 "$RC"
grep -qF 'pre-existing overflow (unchanged: ' "$SCRATCH/ov.md" \
  && echo "ok: T5-POST-BASELINE the note is in the report" || fail "T5-POST-BASELINE report: $(cat "$SCRATCH/ov.md")"
sed -i.bak 's#width:700px#width:900px#' site/alpha/index.html && rm -f site/alpha/index.html.bak
RC=0
RELEASE_DOCS_SKIP=gate,belts bash "$POST" --before "$SCRATCH/ov.snap" --report "$SCRATCH/ov2.md" >/dev/null 2>&1 || RC=$?
expect "T5-POST-BASELINE grown overflow fails post-checks" 1 "$RC"
cd "$ROOT" || exit 1

exit "$failures"
