# CryptoPro SDK dependency

The public snapshot excludes `include/CSP_*.h` and `include/cpcsp/` from BoringSSL. These appear to be vendor SDK headers; redistribution rights have not been established. The checkpoint script backs them up locally under `D:\Project\cr\private-backup\`, but does not publish them.

For reproducible builds, obtain the appropriate licensed CryptoPro SDK from the vendor and provide its headers locally. Never commit private keys, PFX/P12 containers or license secrets.

CryptoPro CSP interoperability, private-key access and CAdES signing remain unverified.
