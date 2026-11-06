#!/usr/bin/env bash
# Atom Browser 0.1.0 Alpha: build a separate Debian/Astra test package.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_OUT="$(cd "$REPO_ROOT/.." && pwd)/chromium/src/out/AtomGost"
OUT="${1:-$DEFAULT_OUT}"
DIST="${2:-$REPO_ROOT/dist}"
VERSION="0.1.0~alpha1"
PACKAGE="atom-browser"

[[ -x "$OUT/chrome" ]] || { echo "ERROR: missing executable $OUT/chrome" >&2; exit 1; }
command -v dpkg-deb >/dev/null || { echo 'ERROR: dpkg-deb is required' >&2; exit 1; }
[[ "$(uname -m)" == "x86_64" ]] || { echo 'ERROR: requires Linux x86_64 host' >&2; exit 1; }
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/opt/atom-browser"
mkdir -p "$APP" "$STAGING/DEBIAN" "$STAGING/usr/bin" "$STAGING/usr/share/applications" "$STAGING/usr/share/icons/hicolor/scalable/apps"

# Component builds of Chromium put dynamically linked .so files alongside chrome.
# Copy runtime assets, not obj, gen, .ninja, logs, symbol files or developer tools.
shopt -s nullglob
for item in "$OUT"/*; do
  [[ -f "$item" ]] || continue
  name="${item##*/}"
  case "$name" in
    chrome|chrome_sandbox|chrome_crashpad_handler|*.pak|*.dat|*.bin|*.so|*.so.*)
      cp -a -- "$item" "$APP/$name" ;;
  esac
done
for dir in locales resources swiftshader MEIPreload; do
  [[ -d "$OUT/$dir" ]] && cp -a -- "$OUT/$dir" "$APP/$dir"
done
shopt -u nullglob

for required in chrome icudtl.dat; do
  [[ -e "$APP/$required" ]] || { echo "ERROR: missing Chromium runtime asset $required" >&2; exit 1; }
done
[[ -d "$APP/locales" ]] || { echo 'ERROR: missing Chromium locales directory' >&2; exit 1; }
chmod 0755 "$APP/chrome"
# Never automatically grant setuid privileges to an alpha sandbox helper.
if [[ -f "$APP/chrome_sandbox" ]]; then chmod 0755 "$APP/chrome_sandbox"; fi

cat > "$STAGING/usr/bin/atom-browser" <<'LAUNCHER'
#!/bin/sh
# Keep Atom Browser separate from existing Chromium and Chrome profiles.
exec /opt/atom-browser/chrome --user-data-dir="${XDG_CONFIG_HOME:-$HOME/.config}/atom-browser" "$@"
LAUNCHER
chmod 0755 "$STAGING/usr/bin/atom-browser"

cat > "$STAGING/usr/share/applications/atom-browser.desktop" <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Atom Browser
GenericName=Web Browser
Comment=Atom Browser corporate test build
Exec=atom-browser %U
TryExec=/usr/bin/atom-browser
Icon=atom-browser
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
Terminal=false
StartupNotify=true
DESKTOP

cat > "$STAGING/usr/share/icons/hicolor/scalable/apps/atom-browser.svg" <<'ICON'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
 <rect x="4" y="4" width="120" height="120" rx="26" fill="#07386d"/>
 <g fill="none" stroke="#8edaff" stroke-width="5">
  <ellipse cx="64" cy="64" rx="47" ry="20" transform="rotate(-55 64 64)"/>
  <ellipse cx="64" cy="64" rx="47" ry="20" transform="rotate(55 64 64)"/>
  <ellipse cx="64" cy="64" rx="47" ry="20"/>
 </g>
 <circle cx="64" cy="64" r="10" fill="#fff"/>
</svg>
ICON

# This is a controlled alpha dependency baseline, not a claim of Astra compatibility.
cat > "$STAGING/DEBIAN/control" <<CONTROL
Package: $PACKAGE
Version: $VERSION
Section: web
Priority: optional
Architecture: amd64
Maintainer: Atom Browser Project
Depends: libc6, libnss3, libnspr4, libatk1.0-0, libatk-bridge2.0-0, libgbm1, libasound2, libx11-6, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxrandr2, libxkbcommon0, libxss1, libdbus-1-3, libatspi2.0-0
Description: Atom Browser corporate Chromium-Gost alpha test build
 Independent browser profile and corporate new tab page.
 Unverified for production on Astra Linux 1.8.
CONTROL

OUTPUT="$DIST/atom-browser_${VERSION}_amd64.deb"
dpkg-deb --root-owner-group --build "$STAGING" "$OUTPUT"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"
echo "Built: $OUTPUT"
echo "Sandbox note: chrome_sandbox is NOT setuid in this alpha."
echo "Astra 1.8 must be tested with sandbox enabled before use."
