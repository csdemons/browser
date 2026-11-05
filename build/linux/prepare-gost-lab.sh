#!/usr/bin/env bash
set -euo pipefail

ROOT="$HOME/projects/atom-browser"
SRC="$ROOT/chromium/src"
GOST="$ROOT/chromium-gost-upstream"
BORINGSSL="$SRC/third_party/boringssl/src"

echo "=== ATOM BROWSER GOST LAB ==="

test "$(git -C "$SRC" branch --show-current)" = \
  "atom/gost-integration"

test "$(git -C "$SRC" describe --tags --exact-match HEAD)" = \
  "156.0.8078.79"

test "$(git -C "$GOST" rev-parse HEAD)" = \
  "449f36bfecc149098184660ee12ef57e1e1d3bfd"

git -C "$SRC" diff --quiet
git -C "$SRC" diff --cached --quiet
git -C "$BORINGSSL" diff --quiet
git -C "$BORINGSSL" diff --cached --quiet

EXCLUDES=(
  --exclude=sandbox/policy/features.cc
  --exclude=sandbox/policy/mac/network.sb
  --exclude=sandbox/policy/win/sandbox_win.cc
  --exclude=net/cert/cert_verify_proc.cc
  --exclude=net/cert/cert_verify_proc_builtin.cc
  --exclude=chrome/browser/ssl/ssl_config_service_manager.cc
)

echo "=== VERIFY PATCHES ==="

git -C "$SRC" apply --check \
  "${EXCLUDES[@]}" \
  "$GOST/patch/gostssl-chromium.patch"

git -C "$BORINGSSL" apply --check \
  "$GOST/patch/gostssl-boringssl.patch"

echo "=== PREPARE BORINGSSL BRANCH ==="

BRANCH=$(git -C "$BORINGSSL" branch --show-current)

if [[ -z "$BRANCH" ]]; then
  git -C "$BORINGSSL" switch -c atom/gost-integration
elif [[ "$BRANCH" != "atom/gost-integration" ]]; then
  echo "Unexpected BoringSSL branch: $BRANCH"
  exit 1
fi

echo "=== APPLY CHROMIUM PATCH ==="

git -C "$SRC" apply \
  "${EXCLUDES[@]}" \
  "$GOST/patch/gostssl-chromium.patch"

echo "=== APPLY BORINGSSL PATCH ==="

git -C "$BORINGSSL" apply \
  "$GOST/patch/gostssl-boringssl.patch"

echo "=== INSTALL GOST SOURCES ==="

cp "$GOST/src/gostssl.cpp" \
  "$SRC/third_party/boringssl/gostssl.cpp"

cp "$GOST/src/msspi/src/msspi.cpp" \
  "$SRC/third_party/boringssl/msspi.cpp"

cp "$GOST/src/msspi/src/msspi.h" \
  "$SRC/third_party/boringssl/msspi.h"

cp "$GOST/src/msspi/src/capix.hpp" \
  "$SRC/third_party/boringssl/capix.hpp"

cp "$GOST/src/msspi/third_party/cprocsp/include/"*.h \
  "$BORINGSSL/include/"

cp -R "$GOST/src/msspi/third_party/cprocsp/include/cpcsp" \
  "$BORINGSSL/include/"

echo "=== INSTALL CERTIFICATES ==="

mkdir -p "$SRC/chrome/browser/resources/bundled_ca"

cp -R "$GOST/extra/bundled_ca/." \
  "$SRC/chrome/browser/resources/bundled_ca/"

echo "=== DONE: EXPERIMENTAL SOURCES PREPARED ==="
echo "Security verification is still required."
