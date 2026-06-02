# Fix report — post-audit sprint (full protocol)

**Date:** 2026-05-28 (updated 2026-06-01 — Phase 8 sideload ads)  
**Audit:** `AUDIT_REPORT.md` §23, `docs/PHASE7_BUGS.md` Phase 8, `docs/SECRETS_REPORT.md`

## Phase completion

| Phase | Status |
|-------|--------|
| 0 Dependency map | **Done** — `docs/DEPENDENCY_MAP.md` |
| 1 Security hardening | **Done** — Monetag/Adsterra release guards, WebView nav policy, SSL pin log |
| 2 Stream token | **Done** — 4m cache, `fetchToken` + `fetchTokenResult`, pinned Dio |
| 3 Cleartext / NSC | **Partial** — `fix_http_streams.sh`, `HTTP_HOLDOUTS.md`; NSC list documented |
| 4 God-class refactor | **Partial** — `CatalogService`, `UserStateProvider`, `AdGateProvider`; player still ~3181 LOC |
| 5 Async safety | **Partial** — splash/player paths already guarded; full grep pass deferred |
| 6 i18n | **Partial** — ARB EN/BN/HI/UR; UI not wired to `gen-l10n` yet |
| 7 Hosting / compliance | **Done** — `web/`, `DEPLOY_LEGAL.md`, `cmp_integration_plugs.dart` TODOs |

**Tests:** 113/113 `flutter test`

## New dart-defines (Monetag — no source defaults)

`MONETAG_ONCLICK_ZONE`, `MONETAG_VIGNETTE_ZONE`, `MONETAG_PUSH_ZONE`, `MONETAG_INPAGE_ZONE`, `MONETAG_DIRECT_ZONE`, `MONETAG_ONCLICK_HOST`, `MONETAG_VIGNETTE_HOST`, `MONETAG_PUSH_SCRIPT`, `MONETAG_INPAGE_HOST`, `MONETAG_DIRECT_LINK`

See `NEW_DART_DEFINES.env`.

## Phase 8 — sideload ads (2026-06-01)

| Item | Status |
|------|--------|
| `CAP_LOCAL_ONLY_MODE` + JSON validate in `tool/build_size_apk.sh` | **Done** |
| `AdConfig.capLocalOnlyEffective` + `[LumioAds]` release log | **Done** |
| Expanded `secrets.json` / template | **Done** |
| CI `release_apk.yml` cap local default | **Done** |
| Wire `LEVELPLAY_REWARDED_AD_UNIT` | **Open** (P8-001) |
| Real `STREAM_TOKEN_BASE_URL` + SSL pins on device | **Open** (P8-004) |

## Ops still required

- Deploy stream-token API; set CI defines (replace placeholder `api.lumio.app`)
- Host `web/` on Cloudflare Pages (`lumio.app`)
- Replace `YOUR_*` in `app-ads.txt`
- Finish player/app_provider LOC split (<400 LOC target)
- Licensed CMP vendor selection
