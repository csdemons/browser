# Atom Browser

Chromium-based corporate browser project.

## Alpha checkpoint

- Version: `0.1.0-alpha`
- Chromium: `156.0.8078.79`
- Targets: Windows x64 and Astra Linux 1.8 x86-64
- Windows x64 installer built and installed; Windows Sandbox verified.
- GOST TLS and CryptoPro functional interoperability tests are pending.
- Astra Linux 1.8 runtime compatibility is not yet verified.
- Windows installer is not code-signed.

## Repository layout

- `patches/chromium/` вЂ” tracked Chromium source delta.
- `patches/boringssl/` вЂ” tracked BoringSSL source delta.
- `patches/source-files/` вЂ” new source files and resources.
- `branding/` вЂ” Atom Browser icons.
- `packaging/` вЂ” Windows and Astra packaging.
- `config/` вЂ” pinned GN arguments.
- `docs/` вЂ” recovery, security and release notes.
- `releases/v0.1.0-alpha/` вЂ” release manifest and SHA256 (installer EXE is a GitHub Release asset).

Pinned revisions are in `UPSTREAM.lock` and `BUILD.lock`. Never use `--no-sandbox` or `--ignore-certificate-errors` in release builds. Never commit private keys, PFX/P12, profiles, crash dumps, build output or installer binaries.
