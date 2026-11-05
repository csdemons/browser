# Atom Browser UI — Курчатовский институт style (functional prototype)

**Scope:** a corporate quick-access homepage plus a separate runnable demonstration of API-backed search and skeleton states. It is not a patch to Chromium and does not implement real authentication, registry integration, or GOST TLS.

## Corporate homepage (default route `/`)

The default start page is **corporate services**, not a search page. It preserves the blue Kurchatov Institute design and emblem from the supplied reference. Seven direct HTTPS links, with no API probing and no duplicate network requests:

- Телефония — https://tel.nrcki.ru
- Корпоративный портал — https://portal.nrcki.ru
- Сайт института — https://nrcki.ru
- Облачное хранилище — https://next.nrcki.ru
- Talk — https://talk.nrcki.ru
- RuPost — https://rp.nrcki.ru
- Exchange — https://mail.rrcki.ru

There are no fake service-status indicators or external favicon fetches. Links open in the active tab. Actual access depends on corporate network and permissions.

The materials-search demo remains available at **`/materials.html`**, without being loaded or invoked on the homepage.

## Features

- Dark navy/blue Kurchatov visual theme, institute crest from user-provided reference screenshot. The homepage has no search requests.
- Five animated gray skeleton result cards while loading; accessible busy status and reduced-motion support.
- 400ms debounce after last keystroke; Enter/Search trigger immediately.
- **One unified GET `/api/search`** includes suggestions + paginated results.
- Request deduplication by canonical URL, cancel obsolete requests with AbortController, stale-response guard, 15-second in-memory cache.
- Server-side pagination with `page` and `page_size` (up to 25); client receives only one page.
- Go HTTP server compresses JSON responses >=1KiB with gzip only when supported by `Accept-Encoding`, sets `Vary: Accept-Encoding`.
- Mock data only. Not a real Kurchatov Institute service or an official materials database.

## Launch on homik / WSL2

```bash
cd ~/projects/atom-browser/browser
# Copy this folder into your repository, e.g. "cp -R prototype ..." after extracting the zip.
cd prototype
go run ./server
# Open http://127.0.0.1:8765 in your browser.
```

The server binds to 127.0.0.1 only; no external access. Requires Go 1.22+; no third-party dependencies. Set `ATOM_UI_ADDR=127.0.0.1:9999` to override the port.

## Test

```bash
go test ./...
curl -i -H 'Accept-Encoding: gzip' 'http://127.0.0.1:8765/api/search?page_size=25' --output /dev/null
curl -s --compressed 'http://127.0.0.1:8765/api/search?q=%D1%82%D0%B8%D1%82%D0%B0%D0%BD&page=2&page_size=2'
```

To inspect the actual response header:

```bash
curl -sS -D - -o /dev/null -H 'Accept-Encoding: gzip' 'http://127.0.0.1:8765/api/search?page_size=25'
```

Expected: `Content-Encoding: gzip`, `Vary: Accept-Encoding`, and `Cache-Control: private, no-store` for large responses.

## Production integration

- Replace in-memory `materials` with a datastore query that uses indexes, bounded pagination, access controls, and true field filtering; use **cursor-based** pagination for very large datasets.
- Enforce authentication and authorization server-side; never rely on hiding UI results for access control.
- Replace simulated 540 ms backend latency with real latency; use the Network tab to observe skeletons with throttling.
- Coordinate compression between Go and reverse proxy. Brotli requires server/proxy support. Browsers automatically negotiate supported `Accept-Encoding`; frontend JS does not set it.
- Ensure privacy-safe caching rules and do not cache sensitive responses in a shared proxy.
- Add real integration tests, service rate limits, accessible keyboard navigation for suggestions, telemetry, and monitoring.

## Committing to GitHub

```bash
cd ~/projects/atom-browser/browser
git add prototype
git commit -m 'feat(ui): add skeleton search prototype with debounced paginated API'
git push origin main
```
