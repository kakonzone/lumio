# Phase 7 — deferred / non-blocking bugs

Logged during Phase 7a bring-up. Not fixed inline per sprint rules.

| ID | Area | Issue | Suggested fix |
|----|------|-------|---------------|
| P7-001 | Logs | ~~Missing interstitial loaded log~~ | **Fixed Phase 7b** — `debugPrint` lifecycle logs in `ironsource_service.dart` |
| P7-006 | Consent | **CRITICAL** Returning user: splash called `applyRestrictiveDefaults()` every cold start → native `LevelPlay=false` even when `lumio_ads_consent_v1=granted` → LevelPlay no-fill, Adsterra-only UI | **Fixed** — `applyStoredConsentToSdk()` reads `lumio_ads_consent_v1`; splash uses it; `setConsent()` → `AdManager.retryInitAfterConsent()`; `debugPrint` stored-consent + `setDynamicUserId before init` |
| P7-002 | Logs | Adsterra popunder WebView fires analytics `adsterra_native_loaded` / telemetry only — no `[Adsterra] popunder loaded` string | Add placement-specific `adLog` in `adsterra_webview.dart` `_logAdsterraLoadedOnce` when `placement == 'popunder'` |
| P7-003 | Logs | ~~Missing RC key dump~~ | **Fixed Phase 7b** — `[RemoteConfig] keys=` / `values:` in `ad_safety_service.dart` |
| P7-007 | Tooling | `device_smoke.sh` saved logcat during Gradle (20s window) → **0 lines** | **Fixed** — poll 3s × 60 for `LEVELPLAY_APP_KEY=<set>`; `adb logcat -c`; 60s fresh capture → `logs/device_smoke_*.log`; `[smoke] FAIL` if empty |
| P7-004 | Docs vs code | Sprint checklist implied `hasMonetizationConfig` requires direct **and** WebView; code uses direct **or** WebView + all three LevelPlay units | Update test plans only; behavior is intentional (`ad_config.dart`) |
| P7-005 | Release caps | Empty `CAP_BASE_URL` in release → `[ServerCap] ERROR … ads disabled` | Use `CAP_LOCAL_ONLY_MODE=true` for sideload QA (Phase 7b) or set prod `CAP_BASE_URL` |

## Phase 8 — sideload ads verification (2026-06-01)

| ID | Area | Issue | Status / fix |
|----|------|-------|----------------|
| P8-001 | Config | `LEVELPLAY_REWARDED_AD_UNIT` not wired | **Fixed** — `AdConfig.rewardedAdUnitId`, `LevelPlayAdService` load/show, `AdWaterfall.showRewarded`, `AdManager.showRewarded` / `showRewardedForAdFree`, privacy screen CTA |
| P8-002 | Build | Invalid `secrets.json` → keys not compiled | **Fixed** — `tool/build_size_apk.sh` `json.tool` + CAP guard |
| P8-003 | Release caps | `blocksAdsInRelease` when cap URL empty | **Fixed** — `capLocalOnlyEffective` + `[LumioAds]` log |
| P8-004 | Ops | `api.lumio.app` DNS fail on device | **Mitigated** — sideload (`LUMIO_SIDELOAD_DEV`) uses embedded stream URL in `StreamTokenService`; prod still needs real API |
| P8-005 | UX | Player hides shell ads | **By design** — Home tab + list scroll for visible ads |
| P8-006 | CI | CI `secrets.json` missing cap local mode | **Fixed** — `release_apk.yml` |
| P8-007 | Debug | `adLog()` silent in release | **Fixed** — tagged `[LevelPlay]`/`[AdWaterfall]`/`[Adsterra]` print in release; P8-002 popunder log |

## Inferred APIs pending verification

| API | Location | Status |
|-----|----------|--------|
| `LevelPlayBannerAdView.pauseAutoRefresh` / `resumeAutoRefresh` | `lib/widgets/ad_banner_widget.dart` | `TODO(verify)` — not confirmed against 9.2.0 changelog |
| `LevelPlayInitError.errorCode` | `lib/services/ironsource_service.dart` `onInitFailed` | `TODO(verify)` — field access not confirmed against 9.2.0 changelog |
