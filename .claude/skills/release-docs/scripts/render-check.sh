#!/usr/bin/env bash
# render-check.sh — render-verify site pages in headless Chrome (release-docs spec § 6).
#
# Usage: render-check.sh [--shots DIR] PAGE...
#   For each page: node --check on its inline scripts; then a Chrome probe at 1400px for uncaught
#   errors, sections that never show or are empty, nav links / data-d keys that do not resolve and
#   openD() throwing; and at 500px for horizontal overflow. --shots writes dark + light screenshots.
#   Env: CHROME (binary), RENDER_TIMEOUT (seconds per Chrome run, default 30).
# Exit: 0 all clean, 1 any page failed, 2 bad input or no Chrome.
# Chrome writes its output and then never exits on its own, so every run is polled and killed.
#
# Deviation from the original design: the DOM probe runs in real wall-clock time and reports via
# console.log instead of via --dump-dom under --virtual-time-budget. On this machine's Chrome,
# --virtual-time-budget was verified to make IntersectionObserver's initial callback unreliable (it
# can fail to fire at all across budgets from 4s-25s on the real page geometry), which would make
# every "hidden section" check flaky. Real time fires it reliably. See render_probe.py's docstring.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

shots=""
pages=()
while [ $# -gt 0 ]; do
  case "$1" in
    --shots) shots="${2:?--shots needs a directory}"; shift 2 ;;
    -*) echo "render-check: unknown option $1" >&2; exit 2 ;;
    *) pages+=("$1"); shift ;;
  esac
done
[ ${#pages[@]} -gt 0 ] || { echo "usage: render-check.sh [--shots DIR] PAGE..." >&2; exit 2; }

# RENDER_TIMEOUT feeds arithmetic in chrome_run (limit=$(( RENDER_TIMEOUT * 2 ))); a malformed value
# there errors under set -e in a way that can unwind past the page loop without ever printing a
# per-page line, so it is validated and normalized once, up front, instead of defaulted inline. The
# digit check alone isn't enough: that arithmetic is bash arithmetic, which reads a leading 0 as
# octal ("08" then crashes the same way — "value too great for base"; "017" is silently 15, not 17).
# 10#$RENDER_TIMEOUT forces the base-10 reading, so it is applied once, right here, before -gt 0.
if [ -n "${RENDER_TIMEOUT:-}" ]; then
  case "$RENDER_TIMEOUT" in
    ''|*[!0-9]*)
      echo "render-check: RENDER_TIMEOUT must be a positive integer (seconds): $RENDER_TIMEOUT" >&2
      exit 2 ;;
  esac
  RENDER_TIMEOUT=$((10#$RENDER_TIMEOUT))
  [ "$RENDER_TIMEOUT" -gt 0 ] || {
    echo "render-check: RENDER_TIMEOUT must be a positive integer (seconds): $RENDER_TIMEOUT" >&2
    exit 2
  }
fi
RENDER_TIMEOUT="${RENDER_TIMEOUT:-30}"

for cmd in node python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "render-check: $cmd not found" >&2; exit 2; }
done
if [ -z "${CHROME:-}" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
  done
fi
[ -n "${CHROME:-}" ] || { echo "render-check: no Chrome found (set CHROME=)" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/render-check.XXXXXX")"
cleanup() { pkill -f "$WORK/prof-" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

# chrome_run <tag> <window WxH> <done-test: dom|png> <output> <chrome args...>
# The "dom" test runs in real wall-clock time (no --virtual-time-budget — see the deviation note
# above) and polls for the probe's console.log marker, captured via --enable-logging=stderr --v=1.
# For "png", any stale file at <output> (left by an earlier render-check.sh run into the same
# --shots dir) is removed first — otherwise the done-test [ -s "$out" ] is already true and Chrome
# is killed ~1s in, leaving the old screenshot in place and silently reported as this run's.
chrome_run() {
  local tag="$1" win="$2" test="$3" out="$4" pid i=0 limit
  shift 4
  limit=$(( RENDER_TIMEOUT * 2 ))
  [ "$test" = png ] && rm -f "$out"
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --no-first-run \
    --user-data-dir="$WORK/prof-$tag" --window-size="$win" "$@" \
    > "$WORK/$tag.log" 2>&1 &
  pid=$!
  while [ "$i" -lt "$limit" ]; do
    if [ "$test" = dom ]; then
      grep -q 'RCPROBE:' "$WORK/$tag.log" 2>/dev/null && break
    else
      [ -s "$out" ] && { sleep 1; break; }
    fi
    sleep 0.5
    i=$((i + 1))
  done
  kill "$pid" 2>/dev/null || true
  pkill -f "$WORK/prof-$tag" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  if [ "$test" = dom ]; then mv "$WORK/$tag.log" "$out"; fi
}

# probe_verdict <tag> <width> <html file> — the dom check for one width, printing judge's verdict
# (empty when clean). Retried exactly once, and only when the probe itself never reported (Chrome
# never wrote the console marker before RENDER_TIMEOUT) — spec § 10's single retry. A failure the
# probe DID report (a real hidden section, bad nav link, openD() throw, overflow, ...) is never
# retried; it is judge's verdict on the first, real attempt.
probe_verdict() {
  local tag="$1" width="$2" html="$3" verdict
  chrome_run "$tag" "$width,30000" dom "$WORK/$tag.log" --enable-logging=stderr --v=1 "file://$html"
  verdict="$(python3 "$HERE/render_probe.py" read "$WORK/$tag.log" \
    | python3 "$HERE/render_probe.py" judge "$width")"
  case "$verdict" in
    "the probe never reported"*)
      chrome_run "$tag-r2" "$width,30000" dom "$WORK/$tag-r2.log" --enable-logging=stderr --v=1 "file://$html"
      verdict="$(python3 "$HERE/render_probe.py" read "$WORK/$tag-r2.log" \
        | python3 "$HERE/render_probe.py" judge "$width")"
      ;;
  esac
  printf '%s' "$verdict"
}

# shot <tag> <win> <out> <chrome args...> — a screenshot, retried once if it comes out missing or
# empty (spec § 10), then a stderr warning (not a page FAIL — shots are artifacts for the reviewer,
# not part of the pass/fail contract) if it is still missing or empty after the retry.
shot() {
  local tag="$1" win="$2" out="$3"
  shift 3
  chrome_run "$tag" "$win" png "$out" "$@"
  if [ ! -s "$out" ]; then
    chrome_run "$tag-r2" "$win" png "$out" "$@"
  fi
  [ -s "$out" ] || echo "render-check: warning: screenshot not written: $out" >&2
}

fail=0
n=0
for page in "${pages[@]}"; do
  [ -f "$page" ] || { echo "render-check: no such page: $page" >&2; exit 2; }
  n=$((n + 1))
  bad=""
  python3 "$HERE/render_probe.py" scripts "$page" "$WORK/p$n.js"
  if ! node --check "$WORK/p$n.js" 2>"$WORK/p$n.node"; then
    bad="inline script does not parse: $(head -n 3 "$WORK/p$n.node" | tr '\n' ' ')"
  fi
  python3 "$HERE/render_probe.py" inject "$page" "$WORK/p$n.html" probe
  for width in 1400 500; do
    verdict="$(probe_verdict "p$n-$width" "$width" "$WORK/p$n.html")"
    [ -z "$verdict" ] || bad="${bad:+$bad; }$verdict"
  done
  if [ -n "$shots" ]; then
    mkdir -p "$shots"
    case "$(basename "$page")" in
      index.html) name="$(basename "$(dirname "$page")")" ;;
      *) name="$(basename "$page" .html)" ;;
    esac
    shot "p$n-dark" "1400,9000" "$shots/$name-dark.png" --screenshot="$shots/$name-dark.png" "file://$(cd "$(dirname "$page")" && pwd)/$(basename "$page")"
    python3 "$HERE/render_probe.py" inject "$page" "$WORK/p$n-light.html" light
    shot "p$n-light" "1400,9000" "$shots/$name-light.png" --screenshot="$shots/$name-light.png" "file://$WORK/p$n-light.html"
  fi
  if [ -n "$bad" ]; then echo "FAIL $page: $bad"; fail=1; else echo "ok   $page"; fi
done
exit "$fail"
