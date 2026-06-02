# Changelog

## 2026-05-28 — Post-audit fix sprint

- Remove hardcoded Monetag zone defaults; require CI dart-defines in release when Monetag is used.
- Harden Adsterra WebView navigation (`AdWebViewNavigationPolicy`).
- Stream token: 4-minute cache cap, `fetchToken` URL API, pinned Dio retry.
- Extract `CatalogService`, `UserStateProvider`, `AdGateProvider`; `MultiProvider` wiring.
- Add `docs/DEPENDENCY_MAP.md`, `web/app-ads.txt`, CMP integration TODO plugs.
