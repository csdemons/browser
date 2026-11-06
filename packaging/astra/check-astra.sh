#!/usr/bin/env bash
# Run on an actual Astra Linux 1.8 test machine after installing Atom Browser.
set -euo pipefail
cat /etc/os-release
[[ -x /opt/atom-browser/chrome ]] || { echo 'ERROR: Atom Browser is not installed' >&2; exit 1; }
/opt/atom-browser/chrome --version
printf '\n=== Library dependency check ===\n'
missing="$(ldd /opt/atom-browser/chrome | grep 'not found' || true)"
if [[ -n "$missing" ]]; then echo "$missing" >&2; exit 1; fi
printf 'No missing direct shared libraries.\n'
printf '\n=== Unprivileged namespaces ===\n'
sysctl kernel.unprivileged_userns_clone 2>/dev/null || true
printf '\nOpen atom-browser, then inspect chrome://sandbox and test ГОСТ TLS.\n'
printf 'Do not pass --no-sandbox or --ignore-certificate-errors.\n'
