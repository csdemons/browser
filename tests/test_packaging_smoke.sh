#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$TMP/out/AtomGost"
mkdir -p "$OUT/locales" "$OUT/resources"
cat > "$OUT/chrome" <<'STUB'
#!/bin/sh
echo 'Chromium 156.0.8078.79'
STUB
chmod +x "$OUT/chrome"
printf x > "$OUT/icudtl.dat"
printf x > "$OUT/chrome_100_percent.pak"
printf x > "$OUT/locales/ru.pak"
printf x > "$OUT/resources/sample.pak"
printf x > "$OUT/libdummy.so"
# Ensure the builder cannot accidentally package the obj/ directory.
mkdir -p "$OUT/obj"
printf 'secret placeholder' > "$OUT/obj/private.txt"
bash "$HERE/packaging/astra/make-deb.sh" "$OUT" "$TMP/dist"
DEB="$TMP/dist/atom-browser_0.1.0~alpha1_amd64.deb"
[[ -s "$DEB" ]] || exit 1
dpkg-deb -f "$DEB" Package | grep -Fx 'atom-browser'
dpkg-deb -c "$DEB" | grep -F 'opt/atom-browser/libdummy.so'
if dpkg-deb -c "$DEB" | grep -Fq '/obj/'; then
  echo 'ERROR: obj/ leaked into DEB' >&2
  exit 1
fi
sha256sum -c "$DEB.sha256"
echo 'SMOKE TEST OK'
