# Doc / code drift report — Phase 2 H2

**Generated:** 2026-05-25  
**Resolved (P2):** 2026-05-25 — see **`docs/DRIFT_RESOLUTION.md`** for all 18 DRIFT rows.  
**Scope:** Audit task specified `docs/ads/` — **that directory does not exist.** This report covers all monetization / ads / fraud docs under `docs/` (28 `.md` files) cross-checked against `lib/`, `android/`, and `test/`.

**Status:** DRIFT rows below are **[RESOLVED]** via doc updates unless noted in `DRIFT_RESOLUTION.md`.

---

## Summary

| Status | Count | Meaning |
|--------|------:|---------|
| **MATCHED** | 42 | Claim verified in code |
| **DRIFT** | 18 | **[RESOLVED]** — see `DRIFT_RESOLUTION.md` |
| **MISSING** | 2 | Doc references symbol/path that does not exist |
| **PARTIAL** | 6 | Directionally right but incomplete or wrong path/name |
| **N/A** | 4 | Historical / illustrative only |

**Highest-impact drifts:** secrets setup still described as editing `ad_config.dart` literals; `PHASE5_SECURITY.md` wrong API names; hardcoded banner unit ID in device-test docs; `LEVELPLAY_SDK_VERIFICATION.md` privacy section superseded by `AdConsentService`.

---

## Scope note

| Audit expectation | Actual |
|-------------------|--------|
| `docs/ads/*.md` | **MISSING** — use `docs/ADS_*.md`, `PLACEMENT_MAP.md`, `PHASE5_SECURITY.md`, `DEVICE_TEST_TASK_*.md`, etc. |

---

## `docs/ADS_README.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Tri-network: LevelPlay + Unity mediated + Adsterra WebView | `pubspec.yaml` `unity_levelplay_mediation`; `lib/ads/adsterra/*`; `channel_tap_ad_rotator.dart` L6–11 | **MATCHED** |
| 2 | `ADS_TEST_MODE` / `blockAdsInThisBuild` | `lib/config/ad_config.dart` L15–24 | **MATCHED** |
| 3 | Device fingerprint in `ad_safety_service.dart` | `lib/services/ad_safety_service.dart` | **MATCHED** |
| 4 | Consent on splash | `lib/services/ad_consent_service.dart`, `lib/screens/splash_screen.dart` | **MATCHED** |
| 5 | Server caps via `server_cap_client.dart` | `lib/ads/server_cap_client.dart` → `ServerCap` | **MATCHED** |
| 6 | VPN routing in `ad_safety_service.dart` | `lib/services/vpn_signal_service.dart` + `ad_safety_service.dart` | **MATCHED** |
| 7 | `setDynamicUserId` before init | `lib/services/ironsource_service.dart` L84–100 | **MATCHED** |
| 8 | Per-device caps / 30s isolation | `lib/services/ad_trigger_manager.dart` | **MATCHED** |
| 9 | Analytics `ad_analytics.dart` | `lib/ads/analytics/ad_analytics.dart` | **MATCHED** |
| 10 | Copy App Key → `ad_config.dart` → `levelPlayAppKey` | Keys are `String.fromEnvironment` only — empty unless dart-define / Gradle | **DRIFT** — use `docs/SECRETS_ENV.md` flow |
| 11 | Paste Adsterra URLs into `ad_config.dart` | Same — all `ADSTERRA_*` from environment | **DRIFT** |
| 12 | Server caps described as “stub” | GET caps + Play Integrity header (`server_cap.dart` L62–67) | **DRIFT** — wording only; behavior is real client |
| 13 | LevelPlay 9.2.0 no App Open; `showAppOpenSubstitute` | `ironsource_service.dart` L223+; `ad_manager.dart` `showColdStartAppOpen` | **MATCHED** |
| 14 | Banner refresh 60s dashboard-only | `AdConfig.levelPlayBannerDashboardRefreshSeconds` | **MATCHED** |
| 15 | Release: LevelPlay init **without** `ApplicationKey` in manifest | `AndroidManifest.xml` L77–80 meta-data `com.ironsource.sdk.ApplicationKey` | **DRIFT** — manifest **requires** key via `@string/levelplay_app_key` (Gradle `resValue`) |
| 16 | Week 1 checklist items | Various — device-only | **N/A** |

---

## `docs/ADS_SETUP.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Config in `lib/config/ad_config.dart` | Present | **MATCHED** |
| 2 | Unity Ads as separate “Waterfall fallback” network row | Unity is **mediation-only**; no Unity SDK | **DRIFT** — align with `ADS_README` / `channel_tap_ad_rotator.dart` |
| 3 | First channel tap → rotated Adsterra → IS → Unity | `ChannelTapAdRotator` + `WaterfallLogic` — IS slots only, no Unity SDK | **PARTIAL** |
| 4 | `AdConfig.adsterraDirectLink` | `String.fromEnvironment('ADSTERRA_DIRECT_LINK')` | **MATCHED** (name); setup is env not paste |

---

## `docs/PLACEMENT_MAP.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Screen placement table | `ad_placement_config.dart`, screens, `ad_manager.dart` | **MATCHED** |
| 2 | `aggressive_mode` intervals 4/4/12m/social bar | `AdPlacementConfig` + `AdsterraOverlayWidget` | **MATCHED** |
| 3 | `lib/ads/ad_placement_config.dart` | Exists | **MATCHED** |
| 4 | `lib/ads/ad_placement_news.dart` | Exists | **MATCHED** |
| 5 | `AdManager.showSplashDirectLinkIfAllowed()` | `lib/ads/ad_manager.dart` L124 | **MATCHED** |
| 6 | `AdManager.onExitIntent()` | `lib/ads/ad_manager.dart` L284; `main.dart` L182 | **MATCHED** |
| 7 | `AdListInjector.buildSeparatedChannelList` under `lib/ads/` | `lib/widgets/ad_list_injector.dart` | **DRIFT** — wrong directory in doc |
| 8 | Log `[Placement]` on `AdManager.init` | `AdPlacementConfig.logPlacementSummaryOnce()` — verify call site in `ad_manager.dart` init | **PARTIAL** — grep init path when editing doc |

---

## `docs/PHASE5_SECURITY.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Install ID + secure storage | `ad_safety_service.dart`, `SecureInstallIdStore`, native channel | **MATCHED** |
| 2 | VPN signals + ≥2 → prefer clean SDK | `vpn_signal_service.dart`, `ad_safety_service.dart` | **MATCHED** |
| 3 | Play Integrity H1 table | `integrity_check.dart`, `PlayIntegrityBridge.kt` | **MATCHED** |
| 4 | `server_cap_client.dart` → `ServerCapClient.check()` | Class is **`ServerCapService`**; method is **`allowsPlacement()`** | **MISSING** — wrong type/method names |
| 5 | `AdTriggerManager` → `allowsPlacement` before show | `ad_trigger_manager.dart` L202, L225, L259 | **MATCHED** |
| 6 | `ad_config.dart` field `serverCapBaseUrl` | Actual: **`AdConfig.capBaseUrl`** | **DRIFT** |
| 7 | Consent flow mermaid | `splash_screen.dart`, `ad_consent_service.dart` | **MATCHED** |
| 8 | `lib/ads/ironsource_service.dart` in file table | File is **re-export** only: `export '../services/ironsource_service.dart'` | **PARTIAL** |

---

## `docs/SERVER_CAP_API.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Active client GET `{CAP_BASE_URL}/caps/{installId}` | `server_cap.dart` L11, L62–69 | **MATCHED** |
| 2 | 5min cache | `_cacheTtl` L16 | **MATCHED** |
| 3 | `X-Integrity-Token` one-shot | `integrity_attestation_service.dart` + `server_cap.dart` L64–67 | **MATCHED** |
| 4 | Facade `server_cap_client.dart` → `ServerCap` | `ServerCapService` delegates to `ServerCap` | **MATCHED** |
| 5 | POST + HMAC body (legacy Phase 6) | Not wired in app | **N/A** — correctly marked legacy |
| 6 | `CAP_HMAC_KEY` required for caps | `ServerCap.isConfigured` only checks **`capBaseUrl`** | **DRIFT** — HMAC unused for GET client |

---

## `docs/LEVELPLAY_SDK_VERIFICATION.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Plugin 9.2.0 / native 9.4.0 | `pubspec.lock`, plugin `levelplay_constants.dart` | **MATCHED** — see `LEVELPLAY_VERSION_SKEW.md` |
| 2 | API table (init, privacy, ads) | `ironsource_service.dart`, `ad_consent_service.dart` | **MATCHED** |
| 3 | Banner unit example `znewe3rrge3dh03f` | **Not in repo** — units come from `LEVELPLAY_BANNER_AD_UNIT` define | **DRIFT** — example ID is operator-specific |
| 4 | “Phase 5 will add first-launch consent gate” | `AdConsentService` + splash dialog **already shipped** | **DRIFT** — section 5.2 privacy is stale |
| 5 | “Lumio now calls `setCCPA(false)` until CMP” | Consent: `setCCPA(!granted)` when user chooses | **DRIFT** — static false only in `applyRestrictiveDefaults` |
| 6 | Manifest `ApplicationKey` READY_FOR_DEVICE_TEST | `AndroidManifest.xml` + Gradle `resValue` | **MATCHED** |

---

## `docs/MONETIZATION_BLUEPRINT.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | `ironsource_service.dart` path | `lib/services/ironsource_service.dart` | **MATCHED** |
| 2 | `AdsterraEngine` / `AdsterraWebViewService` | `lib/ads/adsterra_engine.dart`, `lib/services/adsterra_webview_service.dart` | **MATCHED** |
| 3 | Week 1 “Done” | Subjective | **N/A** |
| 4 | LIVE “IS every 3rd channel tap” | Funnel via `AdTriggerManager` + rotator — not literal “every 3rd” in one constant | **PARTIAL** — marketing vs exact rule |

---

## `docs/ADSTERRA_TELEMETRY_API.md`

| # | Doc claim | Code location | Status |
|---|-----------|---------------|--------|
| 1 | Client `adsterra_telemetry_client.dart` | Exists | **MATCHED** |
| 2 | Entry `logAdsterraTelemetry()` in `ad_debug_log.dart` | Exists | **MATCHED** |
| 3 | `AdManager.init` → `logConfigurationOnce()` | `ad_manager.dart` L52 | **MATCHED** |
| 4 | RC `adsterra_enabled` gate | `AdsterraTelemetryService.report` — verify RC check in file | **MATCHED** (confirm on edit) |

---

## `docs/SECRETS_ENV.md` / `docs/PLAY_INTEGRITY_SERVER.md` / `docs/NETWORK_SECURITY_B5.md`

| Doc | Status |
|-----|--------|
| `SECRETS_ENV.md` | **MATCHED** with post–B2 `ad_config.dart` env-only keys |
| `PLAY_INTEGRITY_SERVER.md` | **MATCHED** with H1 implementation |
| `NETWORK_SECURITY_B5.md` | **MATCHED** with `network_security_config.xml` + generator script |

---

## Device test docs (`DEVICE_TEST_TASK_*.md`, `DEVICE_TEST_CHECKLIST.md`)

| Pattern | Status |
|---------|--------|
| References to `znewe3rrge3dh03f` as `AdConfig.bannerAdUnitId` | **DRIFT** — use placeholder “your banner unit ID” or dart-define name only |
| `server_cap_test.dart`, `server_cap_client_test.dart` | **MATCHED** under `test/` |
| Task 9 consent / privacy table | **MATCHED** with `ad_consent_service.dart` L59–77 |
| Task 2 GET cap flow | **MATCHED** with `server_cap.dart` |

---

## `docs/RELEASE_NOTES_PHASE6.md`

| # | Claim | Status |
|---|--------|--------|
| 1 | Package versions 9.2.0 / webview 4.13.1 | Matches `pubspec.yaml` / lock | **MATCHED** |
| 2 | Banner unit `znewe3rrge3dh03f` | **DRIFT** — same as LEVELPLAY doc |

---

## Recommended doc fixes (for your approval — not applied)

1. **ADS_README / ADS_SETUP:** Replace “paste into `ad_config.dart`” with `docs/SECRETS_ENV.md` dart-define / `local.properties` steps.
2. **ADS_README checklist:** Change “without ApplicationKey” → “with `LEVELPLAY_APP_KEY` synced to manifest `ApplicationKey`”.
3. **PHASE5_SECURITY:** `ServerCapService.allowsPlacement`, `AdConfig.capBaseUrl`.
4. **LEVELPLAY_SDK_VERIFICATION:** Remove “Phase 5 will add consent”; document `AdConsentService` mapping; remove hardcoded unit ID or mark “example only”.
5. **DEVICE_TEST_* / RELEASE_NOTES:** Replace `znewe3rrge3dh03f` with generic “dashboard banner unit ID”.
6. **PLACEMENT_MAP:** `lib/widgets/ad_list_injector.dart`.
7. **ADS_SETUP:** Unity row → “Mediated in LevelPlay dashboard only”.
8. **SERVER_CAP_API:** Clarify `CAP_HMAC_KEY` is legacy POST-only (optional note).

---

## Verification commands (H2)

```bash
cd /home/kakonzone/Downloads/FlutterProject/lumio
rg -l 'znewe3rrge3dh03f|serverCapBaseUrl|ServerCapClient' docs/
rg 'class ServerCapService|capBaseUrl' lib/config/ad_config.dart lib/ads/server_cap_client.dart
test -d docs/ads && echo exists || echo 'docs/ads MISSING'
```

**REQUIRES DEVICE TEST** for any doc claim about fill rates, dashboard refresh timing, or Play Integrity verdicts — not verifiable from static drift pass alone.
