# Atom Browser 0.1.0 Alpha вЂ” Build Status

Chromium: 156.0.8078.79 (a21ce95c24ce3964416f09ae1862f53f319eb4d0)
BoringSSL: 2ea3200c3a3ec176613ab7a0b9a4ffc6db846120

## Windows x64
- Native build: successful, out/AtomWin
- Build mode: Developer Build, is_component_build=false
- GN args: config/windows/args-AtomWin.gn
- Installer: $SetupName
- Size: 201966950 bytes
- SHA256: 386125fd1edcaa9ac5c841df7c3a5c7e4d96f0f49827bfb34f45c26e0c35f06e
- Inno Setup: 6.7.3
- Installed path: C:\Program Files\Atom Browser
- Profile: %LOCALAPPDATA%\Atom Browser\User Data

## Verified
- Installed browser starts.
- Product identity and separate profile.
- Corporate new-tab page and branding.
- Sandbox: Renderer Lockdown/Untrusted; Storage Lockdown/Untrusted; Network Service AppContainer; GPU Low integrity.

## Pending
- GOST TLS interoperability tests.
- CryptoPro CSP, CAdES, Rutoken and JaCarta.
- Astra Linux 1.8 runtime/ABI/sandbox validation.
- Code signing, updater and production hardening.

Generated MIDL TLB files are excluded. CryptoPro SDK headers are not published pending license review.
