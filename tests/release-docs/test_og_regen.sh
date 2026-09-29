#!/usr/bin/env bash
# test_og_regen.sh — og-regen.sh rebuilds site/og.png from site/og-card.html as a 1200x630 PNG, on
# both paths (ImageMagick 2x downscale, and the Chrome-only 1x shot the CI runner takes), and never
# touches the existing og.png when it cannot (release-docs obligations.md note 6).
# SC2015: each `check && echo ok || fail` reporter is intended — echo cannot fail, so fail runs
# exactly when the check does.
# shellcheck disable=SC2015
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
failures=0
fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
# shellcheck source=tests/release-docs/helpers.sh
. "$ROOT/tests/release-docs/helpers.sh"
OG="$ROOT/.claude/skills/release-docs/scripts/og-regen.sh"

png_1200x630() { # <file> — a complete PNG, exactly 1200x630
  python3 - "$1" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
ok = (len(d) > 33 and d[:8] == b"\x89PNG\r\n\x1a\n" and d[12:16] == b"IHDR"
      and struct.unpack(">II", d[16:24]) == (1200, 630) and d[-8:-4] == b"IEND")
sys.exit(0 if ok else 1)
PY
}

fixture() { # <dir> <og.png content source> — a scratch site/ with the real card and a given og.png
  mkdir -p "$1/site"
  cp "$ROOT/site/og-card.html" "$1/site/og-card.html"
  cp "$2" "$1/site/og.png"
}

printf 'stale og.png\n' > "$SCRATCH/stale"

# T-OG-NOCHROME (needs no Chrome): a Chrome that isn't there → non-zero, the reason, og.png untouched.
fixture "$SCRATCH/nochrome" "$ROOT/site/og.png"
out="$(CHROME=/nonexistent bash "$OG" --root "$SCRATCH/nochrome" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && echo "ok: no Chrome → exit $rc" || fail "no Chrome exited 0"
case "$out" in *"og.png NOT regenerated: "*) echo "ok: no Chrome → says why" ;;
  *) fail "no Chrome message — got [$out]" ;; esac
cmp -s "$ROOT/site/og.png" "$SCRATCH/nochrome/site/og.png" \
  && echo "ok: no Chrome → og.png untouched" || fail "no Chrome changed og.png"

# T-OG-NOCARD (needs no Chrome): a root without site/og-card.html is bad input (exit 2).
mkdir -p "$SCRATCH/nocard/site"
cp "$SCRATCH/stale" "$SCRATCH/nocard/site/og.png"
out="$(bash "$OG" --root "$SCRATCH/nocard" 2>&1)"; rc=$?
expect "no card → exit 2" 2 "$rc"
cmp -s "$SCRATCH/stale" "$SCRATCH/nocard/site/og.png" \
  && echo "ok: no card → og.png untouched" || fail "no card changed og.png"

# T-OG-BADSHOT (needs no Chrome): a "Chrome" that writes a non-PNG screenshot and exits → exit 1,
# the reason, og.png untouched. A non-empty file is not enough to replace the card.
cat > "$SCRATCH/fakechrome" <<'EOF'
#!/bin/sh
for a in "$@"; do case "$a" in --screenshot=*) printf 'not a png\n' > "${a#--screenshot=}" ;; esac; done
EOF
chmod +x "$SCRATCH/fakechrome"
fixture "$SCRATCH/badshot" "$ROOT/site/og.png"
out="$(MAGICK='' CHROME="$SCRATCH/fakechrome" bash "$OG" --root "$SCRATCH/badshot" 2>&1)"; rc=$?
expect "bad screenshot → exit 1" 1 "$rc"
case "$out" in *"og.png NOT regenerated: "*) echo "ok: bad screenshot → says why" ;;
  *) fail "bad screenshot message — got [$out]" ;; esac
cmp -s "$ROOT/site/og.png" "$SCRATCH/badshot/site/og.png" \
  && echo "ok: bad screenshot → og.png untouched" || fail "bad screenshot changed og.png"

have_chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome google-chrome-stable chromium chromium-browser; do
  if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then have_chrome=1; break; fi
done
if [ -z "$have_chrome" ] && [ -z "${CHROME:-}" ]; then
  if [ -n "${CI:-}" ]; then fail "no Chrome on a CI runner"; exit "$failures"; fi
  echo "skip: test_og_regen Chrome cases (no Chrome here)"; exit "$failures"
fi

# T-OG-DEFAULT: the default path (ImageMagick 2x → 1200x630 when magick is installed) replaces a
# stale og.png with a complete 1200x630 PNG.
fixture "$SCRATCH/default" "$SCRATCH/stale"
out="$(bash "$OG" --root "$SCRATCH/default" 2>&1)"; rc=$?
expect "default path → exit 0 ($out)" 0 "$rc"
png_1200x630 "$SCRATCH/default/site/og.png" \
  && echo "ok: default path → 1200x630 PNG" || fail "default path og.png is not a 1200x630 PNG"

# T-OG-CHROMEONLY: MAGICK= forces the CI runner's Chrome-only 1x shot; same result.
fixture "$SCRATCH/chromeonly" "$SCRATCH/stale"
out="$(MAGICK='' bash "$OG" --root "$SCRATCH/chromeonly" 2>&1)"; rc=$?
expect "Chrome-only path → exit 0 ($out)" 0 "$rc"
png_1200x630 "$SCRATCH/chromeonly/site/og.png" \
  && echo "ok: Chrome-only path → 1200x630 PNG" || fail "Chrome-only og.png is not a 1200x630 PNG"

# T-OG-CLEAN: nothing is left behind in site/ (no temp file, no stray Chrome profile).
extra="$(find "$SCRATCH/default/site" "$SCRATCH/chromeonly/site" -type f ! -name og.png ! -name og-card.html)"
expect "no stray files in site/" "" "$extra"

exit "$failures"
