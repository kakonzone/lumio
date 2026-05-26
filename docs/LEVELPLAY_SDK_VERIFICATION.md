# LevelPlay SDK verification — `unity_levelplay_mediation` 9.2.0

Source package: `~/.pub-cache/hosted/pub.dev/unity_levelplay_mediation-9.2.0/`  
Native Android SDK (bundled): **9.4.0** (`LevelPlayConstants.ANDROID_SDK_VERSION`)

Verified: **2026-05-24** (Phase 3)

---

## Verification table

| API / behavior | Lumio usage | Status | Exact signature / source |
|----------------|-------------|--------|---------------------------|
| `LevelPlay.setDynamicUserId` | Before `init` | ✅ | `static Future<void> setDynamicUserId(String dynamicUserId)` — `lib/src/levelplay.dart:55` |
| `LevelPlay.init` | `ironsource_service.dart` | ✅ | `static Future<void> init({required LevelPlayInitRequest initRequest, required LevelPlayInitListener initListener})` — `lib/src/levelplay.dart:122` |
| `LevelPlayInitRequest.builder` | App key + userId | ✅ | `static LevelPlayInitRequestBuilder builder(String appKey)` — `lib/src/models/level_play_init_request.dart:15` |
| `LevelPlayInitRequestBuilder.withUserId` | Device fingerprint | ✅ | `LevelPlayInitRequestBuilder withUserId(String userId)` — `level_play_init_request.dart:34` |
| `LevelPlayPrivacySettings.setGDPRConsents` | Before init | ✅ | `static Future<void> setGDPRConsents(Map<String, bool> networkConsents)` — `lib/src/models/level_play_privacy_settings.dart:34` |
| `LevelPlayPrivacySettings.setCCPA` | Before init | ✅ | `static Future<void> setCCPA(bool value)` — `level_play_privacy_settings.dart:54` — **`true` = user opted out of sale** (doc lines 40–44) |
| `LevelPlayPrivacySettings.setCOPPA` | Before init | ✅ | `static Future<void> setCOPPA(bool value)` — `level_play_privacy_settings.dart:75` — **`true` = child / COPPA applies** |
| `LevelPlayInterstitialAd` ctor | Interstitial unit | ✅ | `LevelPlayInterstitialAd({required this.adUnitId})` — `lib/src/models/level_play_interstitial_ad.dart:26` |
| `LevelPlayInterstitialAd.loadAd` | Preload | ✅ | `Future<void> loadAd()` — `level_play_interstitial_ad.dart:54` |
| `LevelPlayInterstitialAd.showAd` | Display | ✅ | `Future<void> showAd({String? placementName = ''})` — `level_play_interstitial_ad.dart:57` |
| `LevelPlayInterstitialAd.setListener` | Bridge | ✅ | `void setListener(LevelPlayInterstitialAdListener listener)` — `level_play_interstitial_ad.dart:29` |
| `LevelPlayRewardedAd` ctor / load / show | Rewarded | ✅ | Same pattern — `lib/src/models/level_play_rewarded_ad.dart:26–57` |
| `LevelPlayBannerAdView` widget | HOME banner | ✅ | `const LevelPlayBannerAdView({required adUnitId, required adSize, required listener, placementName, bidFloor, ...})` — `lib/src/widgets/level_play_banner_ad_view.dart:33` |
| `LevelPlayBannerAdView.loadAd` | After mount | ✅ | `Future<void> loadAd()` — `level_play_banner_ad_view.dart:46` |
| `LevelPlayBannerAdView.destroy` | Dispose | ✅ | `Future<void> destroy()` — `level_play_banner_ad_view.dart:49` |
| `LevelPlayBannerAdView.pauseAutoRefresh` | Optional | ✅ | `Future<void> pauseAutoRefresh()` — `level_play_banner_ad_view.dart:52` |
| `LevelPlayBannerAdView.resumeAutoRefresh` | Optional | ✅ | `Future<void> resumeAutoRefresh()` — `level_play_banner_ad_view.dart:55` |
| Banner refresh interval (60s) | `AdConfig.levelPlayBannerDashboardRefreshSeconds` | ✅ **Dashboard** | No `setRefreshRate` on Flutter widget or native `Config.Builder` (only `setAdSize`, `setBidFloor`, `setPlacementName`). Refresh defined in **LevelPlay dashboard**; SDK auto-refreshes. Plugin factory: `LevelPlayBannerAdViewFactory.kt:25–37` |
| Native App Open ad | — | **N/A** | No `AppOpen` class in package `lib/` tree |
| `showAppOpenSubstitute` | Splash cold start | ✅ **Custom** | Lumio-only: interstitial + caps — **not** SDK App Open |
| `LevelPlayAdInfo.revenue` | Analytics | ✅ | `final double revenue` — `lib/src/models/level_play_ad_info.dart:46` |
| `com.ironsource.sdk.ApplicationKey` manifest | `@string/levelplay_app_key` | **READY_FOR_DEVICE_TEST** | `AndroidManifest.xml` meta-data + `resValue` from `LEVELPLAY_APP_KEY` dart-define in `android/app/build.gradle.kts` |
| Dart + manifest key sync | `String.fromEnvironment('LEVELPLAY_APP_KEY')` | **READY_FOR_DEVICE_TEST** | Same dart-define must be passed to `flutter build` and Gradle |
| Init retry (8s, 1 backoff) | `ironsource_service.dart` | **READY_FOR_DEVICE_TEST** | Logs `[LevelPlay] init_failed reason=…` and `[LevelPlay] init success` |

---

## Privacy implementation (3.2)

Per `level_play_privacy_settings.dart`:

- **CCPA:** `setCCPA(true)` → user **opted out** of sale. After splash consent, `AdConsentService.applyToLevelPlaySdk()` sets `setCCPA(!granted)`.
- **GDPR:** map values = consent **granted**. After grant, `setGDPRConsents({'LevelPlay': true})`; before consent, restrictive defaults via `applyRestrictiveDefaults()`.

First-launch consent is **shipped**: `AdConsentService` + `ad_consent_dialog.dart` on splash (see `lib/screens/splash_screen.dart`).

---

## App-open substitute (3.3)

| Item | Detail |
|------|--------|
| What users see | Full-screen **interstitial** after splash |
| What it is not | LevelPlay **App Open** ad format (not in Flutter 9.2.0) |
| Entry | `SplashScreen` → `AdManager.showColdStartAppOpen()` → `LevelPlayAdService.showAppOpenSubstitute()` |
| Caps | `AdTriggerManager`: 3/day, 4h gap, shares interstitial hourly limits |

---

## Banner refresh (3.4)

| Layer | Refresh control |
|-------|-----------------|
| Flutter 9.2.0 | `pauseAutoRefresh()` / `resumeAutoRefresh()` only |
| Native `Config.Builder` (9.4.0) | No refresh-interval setter exposed to Flutter |
| Lumio constant | `AdConfig.levelPlayBannerDashboardRefreshSeconds` (= **60**) — dashboard target only |

### Dashboard setup (operator checklist)

1. Open [LevelPlay](https://platform.ironsrc.com/) → **Monetize** → **Ad units**.
2. Select your banner unit ID (from `LEVELPLAY_BANNER_AD_UNIT` dart-define / dashboard).
3. Set **auto-refresh** to **60 seconds** (must match `levelPlayBannerDashboardRefreshSeconds`).
4. Save and publish; cold-start the app on a release APK to verify a second impression ~60s after the first (network permitting).

**READY_FOR_DEVICE_TEST:** Lumio does not log refresh ticks; confirm via dashboard + logcat `onAdDisplayed` on banner placement `home_bottom` (if analytics wired) or IronSource test suite.

**Renamed (Task 7):** `bannerRefreshSeconds` → `levelPlayBannerDashboardRefreshSeconds` to avoid implying a Dart/SDK setter exists.

---

## Android app key (3.5)

| Source | Value |
|--------|--------|
| **Dart** | `--dart-define=LEVELPLAY_APP_KEY=…` → `AdConfig.levelPlayAppKey` |
| **Native manifest** | `com.ironsource.sdk.ApplicationKey` → `@string/levelplay_app_key` (Gradle `resValue`) |
| **Init** | `LevelPlayInitRequest.builder(appKey)` → `LevelPlay.init()` |

Build example:

```bash
flutter build apk --release \
  --dart-define=LEVELPLAY_APP_KEY=your_app_key
```

**READY_FOR_DEVICE_TEST** — logcat: `[LevelPlay] setDynamicUserId` → `[LevelPlay] init success` (or `init_failed` then retry).

## Advertising ID opt-out (Android)

- Permission: `com.google.android.gms.permission.AD_ID` (declared in manifest).
- User opt-out: **Settings → Privacy → Ads** (wording varies by OEM) limits advertising ID collection.
- Lumio does not bypass limitAdTracking; mediation behavior is delegated to LevelPlay/GMS.

---

## Code changes in Phase 3

- `ironsource_service.dart`: CCPA `false`, GDPR `LevelPlay: false`, app-open docs
- `ad_banner_widget.dart`, `ad_config.dart`, `ADS_README.md`: banner / app-open clarity
- This file: verification table
