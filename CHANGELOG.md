# Changelog

## [1.0.0-wc-hotfix-1]

### Performance

- Force mediacodec hardware decode on Android (was auto-safe → caused SW fallback on MIUI/ColorOS)
- Default stream quality 540p on mobile, 720p on tablet (was 1080p)
- Auto-quality clamps to 720p without wifi + >50% battery
- Removed CPU-side `vf scale` filter on Android
- Probe and prewarm now gated behind 5-second idle state

## [1.0.0-rc1]

- Stabilize four failing test suites (server-cap fail-closed, splash delay profile).
- Legal: GitHub Pages workflow, `LegalUrls` constants (`kakonzone.github.io/lumio`).
- CI: `SSL_PIN_PRIMARY` / `SSL_PIN_BACKUP` dart-defines with release fail-fast.
- Monetag: `MONETAG_ZONE_*` dart-define aliases (empty = ads disabled).
- Home tab scroll performance (isolated search, lazy ad WebViews, tab rebuild fix).
- PiP: `FLAG_SECURE` cleared in player; manifest `supportsPictureInPicture`.
- Skipped: Cloudflare stream-token Worker (deferred).

## 2026-05-28 — Post-audit fix sprint

- Remove hardcoded Monetag zone defaults; require CI dart-defines in release when Monetag is used.
- Harden Adsterra WebView navigation (`AdWebViewNavigationPolicy`).
- Stream token: 4-minute cache cap, `fetchToken` URL API, pinned Dio retry.
- Extract `CatalogService`, `UserStateProvider`, `AdGateProvider`; `MultiProvider` wiring.
- Add `docs/DEPENDENCY_MAP.md`, `web/app-ads.txt`, CMP integration TODO plugs.
