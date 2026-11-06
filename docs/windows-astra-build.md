# Atom Browser 0.1.0 Alpha — Astra Linux 1.8 and Windows x64

**State:** Build scripts / packaging kit, not signed or production-ready binaries.

Source: `https://github.com/csdemons/browser`, Chromium `156.0.8078.79`, pinned Chromium-Gost patch set.
The successful `out/AtomGost/chrome` build exists on **homik (WSL2)**, not in this kit.
The new-tab design and Kurchatov emblem are preserved by transferring the **same tested source modifications** to Windows.

## A. Linux: package the already-built executable into an Astra test DEB

Run on homik WSL2, in the project's original directory layout:

```bash
cd ~/projects/atom-browser/browser
# After extracting this kit into the repo:
bash packaging/astra/make-deb.sh
sha256sum -c dist/atom-browser_0.1.0~alpha1_amd64.deb.sha256
dpkg-deb -I dist/atom-browser_0.1.0~alpha1_amd64.deb
dpkg-deb -c dist/atom-browser_0.1.0~alpha1_amd64.deb | head -n 40
mkdir -p /mnt/d/Project/AtomBrowser
cp -v dist/atom-browser_0.1.0~alpha1_amd64.deb* /mnt/d/Project/AtomBrowser/
```

Use a separate **Astra Linux 1.8 SE test VM** for acceptance. Verify library dependencies and sandbox (not in WSL):

```bash
sudo apt install ./atom-browser_0.1.0~alpha1_amd64.deb
bash check-astra.sh
atom-browser --version
atom-browser chrome://new-tab-page/
```

The menu contains Atom Browser; user data is isolated at `~/.config/atom-browser`.
There is no `--no-sandbox` or `--ignore-certificate-errors` switch.
The test package deliberately leaves `chrome_sandbox` **without SUID privileges**. On Astra with unprivileged user namespaces disabled, the browser may refuse to run. **Do not bypass sandbox**. Use the upstream Chromium sandbox packaging approach only after security audit and approval for the site's Astra security mode.

**Important:** The Ubuntu/WSL-built program has **not** been ABI and run-time tested on Astra 1.8. If system libraries or kernel features do not match, compile within a suitable Astra 1.8 build VM or use a compatible sysroot, then retest. Chromium's component build copies several `.so` dependencies; the resulting package may be large and must be inspected using `ldd`, sandbox page and smoke tests. This is **not yet a hardened distribution installer**.

## B. Windows: create a source bundle from the actual working Linux tree

The Linux repository has patched source files not all pushed to the GitHub project (Chromium and BoringSSL are separate repositories). Therefore we must **export the exact built checkout**, not just clone `csdemons/browser` and assume Windows has the GOST changes.

On homik:

```bash
cd ~/projects/atom-browser/browser
python3 packaging/windows/export-source.py
unzip -l dist/atom-browser-windows-source-0.1.0-alpha.zip | less
cp dist/atom-browser-windows-source-0.1.0-alpha.zip /mnt/d/Project/
```

Review the snapshot before sharing it: it contains changed source files (including third-party crypto headers and the custom new-tab assets). It does **not** contain a compiled EXE. It only exports allowed source paths, excludes profiles and output binaries, and records SHA256 per file. Check whether local changes are intentional before compiling or distributing.

## C. Windows x64: native build (not WSL)

Chromium **156.0.8078.79** requires **Visual Studio 2026 >=18.0**, the **Desktop development with C++** and **MFC/ATL** components, and **Windows 11 SDK 10.0.28000.2270**, according to the source-tag Windows build instructions. The build must run on Windows. Recommended at least 32-64 GB RAM, fast SSD and **100+ GB free NTFS space**; larger builds may require substantially more.

In **CMD.EXE** as a normal user (adapt paths as necessary):

```cmd
mkdir C:\src
cd /d C:\src
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git C:\src\depot_tools
set PATH=C:\src\depot_tools;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0
git config --global core.autocrlf false
git config --global core.longpaths true
mkdir C:\src\chromium
cd /d C:\src\chromium
fetch --no-history chromium
cd /d C:\src\chromium\src
git fetch origin refs/tags/156.0.8078.79:refs/tags/156.0.8078.79 --depth=1
git checkout --detach 156.0.8078.79
cd /d C:\src\chromium
gclient sync --revision src@156.0.8078.79 --no-history --jobs=1
gclient runhooks
```

Keep **separate** `depot_tools` directories for Windows and WSL; Chromium warns their caches are platform-specific. Do not run Windows `gclient` in your WSL source directory.

Clone the Atom project into `C:\src\atom-browser\browser`:

```cmd
mkdir C:\src\atom-browser
git clone https://github.com/csdemons/browser.git C:\src\atom-browser\browser
```

Copy the files of this kit into that repo (or push them from WSL). Then run in **PowerShell** (with Windows depot_tools on PATH):

```powershell
$env:PATH = 'C:\src\depot_tools;' + $env:PATH
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
cd C:\src\atom-browser\browser
.\packaging\windows\apply-and-build.ps1 `
  -ChromiumSrc 'C:\src\chromium\src' `
  -SnapshotZip 'D:\Project\atom-browser-windows-source-0.1.0-alpha.zip'
```

After a successful native build:

```powershell
.\packaging\windows\make-portable.ps1 `
  -BuildDir 'C:\src\chromium\src\out\AtomWin' `
  -Destination 'D:\Project\AtomBrowser'
```

Unpack `Atom-Browser-0.1.0-alpha-windows-x64-portable.zip`, run `Atom Browser.cmd`. It uses an independent `%LOCALAPPDATA%\Atom Browser\User Data` profile. `chrome.exe` may display `Chromium 156...` until branding is implemented in the actual binary. This is a **portable alpha**, not a Windows signed EXE/MSI installer. A real branded offline installer and code signing are separate work.

### Required acceptance tests (both platforms)

- `--version` and process startup; local `chrome://new-tab-page/` opens.
- Kurchatov emblem and seven HTTPS shortcuts (`tel`, `portal`, `nrcki`, `next`, `talk`, `rp`, `mail`). Ctrl+T opens the same corporate page.
- Normal Chromium tabs, extensions, profile isolation, PDF, downloads.
- `chrome://sandbox` correctly reports isolation; NO `--no-sandbox`.
- Standard HTTPS certificate validation, including negative tests (expired, untrusted and name-mismatch certificates). NO `--ignore-certificate-errors`.
- CryptoPro CSP, GOST TLS, CRL/OCSP, CAdES plugin, Rutoken and JaCarta must undergo **separate platform-specific tests**; compiling the patches does NOT guarantee that they work.
- EDR/Wazuh, AV, system policies, Astra security level, update and uninstall behavior.
- Before wider deployment: code signing, reproducibility audit, SBOM, dependency scanning, and automated release pipeline.

## D. Commit the kit

```bash
cd ~/projects/atom-browser/browser
git add packaging/astra/ packaging/windows/ docs/windows-astra-build.md
git commit -m 'build: add Astra deb and Windows x64 alpha packaging pipeline'
git push origin main
```
