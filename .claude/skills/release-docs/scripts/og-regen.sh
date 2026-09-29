#!/usr/bin/env bash
# og-regen.sh — regenerate site/og.png (the social card) from site/og-card.html, for /release-docs.
#
# Usage: og-regen.sh [--root DIR]        (default root: the enclosing git checkout)
#   Shoots the card in headless Chrome into a temporary file and replaces site/og.png only when the
#   result is a complete 1200x630 PNG. With ImageMagick it takes the card header's 2x shot and
#   downscales it to 1200x630; without it (the CI runner has none) it takes a 1x shot at 1200x630.
#   Env: CHROME (Chrome binary), MAGICK (ImageMagick binary; set it empty to skip ImageMagick).
# Exit: 0 regenerated; 1 not regenerated (site/og.png untouched); 2 bad input.
# Every failure prints "og.png NOT regenerated: <why>". Chrome writes its output and then never exits
# on its own, so each run is polled for the PNG and then killed by its unique --user-data-dir.
set -euo pipefail

LIMIT=60   # half-second polls per Chrome run (30s)

die() { # <exit code> <why>
  echo "og.png NOT regenerated: $2" >&2
  exit "$1"
}

root=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)
      { [ $# -ge 2 ] && [ -n "$2" ]; } || die 2 "--root needs a directory"
      root="$2"
      shift 2 ;;
    *) die 2 "unknown argument $1 (usage: og-regen.sh [--root DIR])" ;;
  esac
done
if [ -n "$root" ]; then
  [ -d "$root" ] || die 2 "no such directory: $root"
  ROOT="$(cd "$root" && pwd)"
else
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die 2 "not inside a git checkout (pass --root DIR)"
fi
CARD="$ROOT/site/og-card.html"
DEST="$ROOT/site/og.png"
[ -f "$CARD" ] || die 2 "no card at $CARD"
command -v python3 >/dev/null 2>&1 || die 2 "python3 not found (needed to check the PNG)"

if [ -z "${CHROME:-}" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then CHROME="$c"; break; fi
  done
fi
[ -n "${CHROME:-}" ] || die 1 "no Chrome found (set CHROME=)"
{ [ -x "$CHROME" ] || command -v "$CHROME" >/dev/null 2>&1; } || die 1 "Chrome not executable: $CHROME"

# MAGICK unset: use `magick` when it is on the PATH. MAGICK set but empty: never use ImageMagick.
if [ -z "${MAGICK+x}" ]; then
  MAGICK="$(command -v magick 2>/dev/null || true)"
fi
if [ -n "$MAGICK" ]; then
  { [ -x "$MAGICK" ] || command -v "$MAGICK" >/dev/null 2>&1; } || die 1 "ImageMagick not executable: $MAGICK"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/og-regen.XXXXXX")"
NEW="$DEST.new.$$"
cleanup() { pkill -f "$WORK/prof-" 2>/dev/null || true; rm -rf "$WORK"; rm -f "$NEW"; }
trap cleanup EXIT

# shoot <attempt> <scale> <out> — one Chrome run at 1200x630 CSS px, polled until the PNG lands
# (plus a second for the write to finish) or Chrome dies, then killed.
shoot() {
  local tag="$1" scale="$2" out="$3" pid i=0
  rm -f "$out"
  "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars --no-first-run \
    --user-data-dir="$WORK/prof-$tag" --virtual-time-budget=8000 \
    --window-size=1200,630 --force-device-scale-factor="$scale" --screenshot="$out" \
    "file://$CARD" > "$WORK/chrome-$tag.log" 2>&1 &
  pid=$!
  while [ "$i" -lt "$LIMIT" ]; do
    [ -s "$out" ] && { sleep 1; break; }
    # Chrome exited without writing the PNG. Checked by pid and by profile dir, so a launcher that
    # forks Chrome and exits doesn't count as dead.
    { kill -0 "$pid" 2>/dev/null || pgrep -f "$WORK/prof-$tag" >/dev/null 2>&1; } || break
    sleep 0.5
    i=$((i + 1))
  done
  kill "$pid" 2>/dev/null || true
  pkill -f "$WORK/prof-$tag" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

png_ok() { # <file> <width> <height> — a complete PNG of exactly that size
  python3 - "$@" <<'PY'
import struct, sys
try:
    d = open(sys.argv[1], "rb").read()
except OSError:
    sys.exit(1)
ok = (len(d) > 33 and d[:8] == b"\x89PNG\r\n\x1a\n" and d[12:16] == b"IHDR"
      and struct.unpack(">II", d[16:24]) == (int(sys.argv[2]), int(sys.argv[3]))
      and d[-8:-4] == b"IEND")
sys.exit(0 if ok else 1)
PY
}

if [ -n "$MAGICK" ]; then
  how="ImageMagick 2x downscale"
  shoot 1 2 "$WORK/shot.png"
  png_ok "$WORK/shot.png" 2400 1260 || shoot 2 2 "$WORK/shot.png"   # one retry (spec § 10)
  png_ok "$WORK/shot.png" 2400 1260 || die 1 "Chrome wrote no complete 2400x1260 screenshot"
  "$MAGICK" "$WORK/shot.png" -resize 1200x630 -strip "$WORK/og.png" > "$WORK/magick.log" 2>&1 \
    || die 1 "ImageMagick failed: $(head -n 1 "$WORK/magick.log")"
else
  how="Chrome-only 1x"
  shoot 1 1 "$WORK/og.png"
  png_ok "$WORK/og.png" 1200 630 || shoot 2 1 "$WORK/og.png"         # one retry (spec § 10)
fi
png_ok "$WORK/og.png" 1200 630 || die 1 "no complete 1200x630 PNG came out ($how)"

# Copy beside the destination, then rename: site/og.png is never left half-written.
cp "$WORK/og.png" "$NEW" || die 1 "cannot write $NEW"
mv -f "$NEW" "$DEST" || die 1 "cannot replace $DEST"
echo "og.png regenerated: $DEST (1200x630, $how)"
