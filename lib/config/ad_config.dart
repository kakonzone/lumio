import 'package:flutter/foundation.dart';

/// Tri-network monetization — keys via `--dart-define` only (see docs/SECRETS.md).
class AdConfig {
  AdConfig._();

  /// `--dart-define=ADS_ENABLED=true` — enables ads in debug/profile (safe default: off).
  static const bool adsEnabledDefine = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: false,
  );

  /// `--dart-define=ALLOW_SILENT_DEBUG_ADS=true` — hide the debug ads-disabled overlay.
  static const bool allowSilentDebugAds = bool.fromEnvironment(
    'ALLOW_SILENT_DEBUG_ADS',
    defaultValue: false,
  );

  /// Debug overlay when plain `flutter run` leaves ads off (R10).
  static bool get shouldShowAdsDisabledBanner =>
      kDebugMode && !adsEnabledDefine && !allowSilentDebugAds;

  /// `--dart-define=DIAGNOSTICS_ENABLED=true` — unlock in-app ad diagnostics screen.
  static const bool diagnosticsEnabledDefine = bool.fromEnvironment(
    'DIAGNOSTICS_ENABLED',
    defaultValue: false,
  );

  static bool get diagnosticsEnabled => diagnosticsEnabledDefine;

  /// Legacy alias — prefer [adsEnabledDefine].
  static const bool testMode = bool.fromEnvironment(
    'ADS_TEST_MODE',
    defaultValue: false,
  );

  /// True when ad SDKs may load: always in release; in debug/profile only with [adsEnabledDefine] (or legacy [testMode]).
  static bool get adsEnabled =>
      kReleaseMode || adsEnabledDefine || adsTestModeEffective;

  /// `ADS_TEST_MODE` honored only outside release (debug / profile).
  static bool get adsTestModeEffective => !kReleaseMode && testMode;

  /// Block LevelPlay / Adsterra in non-release unless `ADS_ENABLED=true` (or legacy `ADS_TEST_MODE=true`).
  static bool get blockAdsInThisBuild =>
      !kReleaseMode && !adsEnabledDefine && !testMode;

  /// Toffee stream JWT — never commit; pass via `secrets.json` or CI secret.
  static const String toffeeSubscriberToken = String.fromEnvironment(
    'TOFFEE_SUBSCRIBER_TOKEN',
  );

  static bool get hasToffeeSubscriberToken =>
      toffeeSubscriberToken.trim().isNotEmpty;

  @visibleForTesting
  static bool shouldBlockAdsForBuild({
    required bool isReleaseMode,
    required bool adsEnabledDefine,
    bool legacyTestModeDefine = false,
  }) =>
      !isReleaseMode && !adsEnabledDefine && !legacyTestModeDefine;

  // ── LevelPlay / IronSource (clean SDK layer) ───────────────────────────
  /// `--dart-define=LEVELPLAY_APP_KEY=...` or `android/local.properties` (Gradle → manifest).
  static const String levelPlayAppKey = String.fromEnvironment(
    'LEVELPLAY_APP_KEY',
  );
  static const String interstitialAdUnitId = String.fromEnvironment(
    'LEVELPLAY_INTERSTITIAL_AD_UNIT',
  );
  static const String rewardedAdUnitId = String.fromEnvironment(
    'LEVELPLAY_REWARDED_AD_UNIT',
  );
  static const String bannerAdUnitId = String.fromEnvironment(
    'LEVELPLAY_BANNER_AD_UNIT',
  );

  static bool get hasLevelPlayAppKey => levelPlayAppKey.trim().isNotEmpty;
  static bool get hasLevelPlayAdUnits =>
      interstitialAdUnitId.trim().isNotEmpty &&
      rewardedAdUnitId.trim().isNotEmpty &&
      bannerAdUnitId.trim().isNotEmpty;
  /// Dashboard: configure Unity Ads as mediated network (no Unity SDK in app).
  static const String unityMediationNote =
      'Unity Ads → LevelPlay dashboard mediation only';

  // ── Adsterra zones (WebView / direct link — aggressive layer) ──────────
  static const String adsterraDirectLink = String.fromEnvironment(
    'ADSTERRA_DIRECT_LINK',
  );

  /// Pipe-separated direct links for random channel-tap browser pick (`url1|url2|...`).
  static const String adsterraDirectLinksBundle = String.fromEnvironment(
    'ADSTERRA_DIRECT_LINKS',
  );

  static List<String> get adsterraDirectLinkRotation {
    final bundle = adsterraDirectLinksBundle.trim();
    if (bundle.isNotEmpty) {
      return bundle
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = adsterraDirectLink.trim();
    if (single.isNotEmpty) return [single];
    return [];
  }
  static const String adsterraSmartlinkUrl = String.fromEnvironment(
    'ADSTERRA_SMARTLINK_URL',
  );
  static const String adsterraPopunderScriptUrl = String.fromEnvironment(
    'ADSTERRA_POPUNDER_SCRIPT_URL',
  );
  static const String adsterraPopunderBaseUrl = String.fromEnvironment(
    'ADSTERRA_POPUNDER_BASE_URL',
  );
  static const String adsterraNativeInvokeUrl = String.fromEnvironment(
    'ADSTERRA_NATIVE_INVOKE_URL',
  );
  static const String adsterraNativeContainerId = String.fromEnvironment(
    'ADSTERRA_NATIVE_CONTAINER_ID',
  );
  static const String adsterraNativeBaseUrl = String.fromEnvironment(
    'ADSTERRA_NATIVE_BASE_URL',
  );
  static const String adsterraSocialScriptUrl = String.fromEnvironment(
    'ADSTERRA_SOCIAL_SCRIPT_URL',
  );
  static const String adsterraSocialBaseUrl = String.fromEnvironment(
    'ADSTERRA_SOCIAL_BASE_URL',
  );
  static const String adsterraBanner728InvokeUrl = String.fromEnvironment(
    'ADSTERRA_BANNER728_INVOKE_URL',
  );
  static const String adsterraBanner728ContainerId = String.fromEnvironment(
    'ADSTERRA_BANNER728_CONTAINER_ID',
  );
  static const String adsterraBanner728BaseUrl = String.fromEnvironment(
    'ADSTERRA_BANNER728_BASE_URL',
  );

  /// Full URL for POST cap check — see `docs/SERVER_CAP_API.md`.
  static const String capBaseUrl = String.fromEnvironment('CAP_BASE_URL');
  static const String capHmacKey = String.fromEnvironment('CAP_HMAC_KEY');

  /// Release QA without cap backend: local [AdTriggerManager] caps only (no server GET).
  static const bool capLocalOnlyMode = bool.fromEnvironment(
    'CAP_LOCAL_ONLY_MODE',
    defaultValue: false,
  );

  /// Reserved for v1.1 Option A — unused in v1.0 (Option B). See `docs/PLAY_INTEGRITY_OPTION_B.md`.
  static const String playIntegrityCloudProjectNumber = String.fromEnvironment(
    'PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER',
  );

  /// Private Adsterra telemetry — see `docs/ADSTERRA_TELEMETRY_API.md` (not Firebase).
  static const String adsterraTelemetryUrl =
      String.fromEnvironment('ADSTERRA_TELEMETRY_URL');
  static const String adsterraTelemetryHmacKey =
      String.fromEnvironment('ADSTERRA_TELEMETRY_HMAC_KEY');

  /// Salt for legacy fingerprint → installId migration (`--dart-define` in CI).
  static const String fingerprintMigrationSalt = String.fromEnvironment(
    'FINGERPRINT_MIGRATION_SALT',
    defaultValue: 'lumio_fp_migration_v1',
  );

  // ── Per-device caps (shared-WiFi safe — keyed by device fingerprint) ───
  static const int interstitialMaxPerHour = 8;
  static const int interstitialMinGapSeconds = 60;
  static const int rewardedMaxPerHour = 5;
  static const int appOpenMaxPerDay = 3;
  static const int appOpenMinGapHours = 4;
  static const int adsterraDirectLinkMaxPerDay = 3;
  static const int adsterraPopunderMaxPerSession = 2;
  static const int adsterraPopunderCooldownSeconds = 90;
  /// No LevelPlay call within this window after Adsterra popunder/background.
  static const int networkIsolationSeconds = 30;

  // ── Session funnel (AdTriggerManager) ──────────────────────────────────
  static const int interstitialCooldownSeconds = 90;
  static const int maxInterstitialsPerSession = 8;
  static const int channelClicksBeforeInterstitial = 3;
  static const int splashMinMsBeforeAds = 5000;
  static const int waterfallTimeoutMs = 5000;
  static const int firstClickResetHours = 24;
  static const int channelTapAdMinSeconds = 5;

  // ── Display refresh ────────────────────────────────────────────────────────
  /// **LevelPlay dashboard only** — not sent to the SDK from Dart (9.2.0 has pause/resume only).
  ///
  /// IronSource → Monetize → Ad units → [bannerAdUnitId] → set auto-refresh to this value.
  /// See `docs/LEVELPLAY_SDK_VERIFICATION.md` § Banner refresh.
  static const int levelPlayBannerDashboardRefreshSeconds = 60;

  /// Adsterra sticky WebView reload interval (app-controlled).
  static const int adsterraStickyRefreshSeconds = 20;
  static const int nativeListInterval = 8;
  /// NEWS tab — denser than channel lists (see `docs/PLACEMENT_MAP.md`).
  static const int nativeListIntervalNews = 5;
  static const int nativeListIntervalAggressive = 4;

  // ── Natural delay before SDK interstitial ──────────────────────────────
  static const int interstitialDelayMinMs = 200;
  static const int interstitialDelayMaxMs = 800;

  // ── Rewards ────────────────────────────────────────────────────────────
  static const int coinsPerRewardedAd = 10;
  static const int dailyLoginCoins = 5;
  static const int hdUnlockMinutes = 10;
  static const int adFreeMinutesAfterVip = 60;
  static const int playerVideoAdSkipSeconds = 10;
  static const int playerVideoAdMaxSeconds = 30;
  static const int playerMidRollIntervalMinutes = 20;
  static const int playerMidRollIntervalAggressiveMinutes = 12;

  static bool get hasAdsterraDirectLink => adsterraDirectLinkRotation.isNotEmpty;
  static bool get hasAdsterraSmartlink => adsterraSmartlinkUrl.trim().isNotEmpty;

  /// At least one Adsterra WebView zone (script + base URL pairs).
  static bool get hasAdsterraWebViewZones =>
      (adsterraPopunderScriptUrl.trim().isNotEmpty &&
          adsterraPopunderBaseUrl.trim().isNotEmpty) ||
      (adsterraNativeInvokeUrl.trim().isNotEmpty &&
          adsterraNativeBaseUrl.trim().isNotEmpty) ||
      (adsterraBanner728InvokeUrl.trim().isNotEmpty &&
          adsterraBanner728BaseUrl.trim().isNotEmpty);

  /// Compile-time keys present for at least one ad stack (LevelPlay and/or Adsterra).
  static bool get hasMonetizationConfig =>
      (hasLevelPlayAppKey && hasLevelPlayAdUnits) ||
      hasAdsterraDirectLink ||
      hasAdsterraWebViewZones;

  static String _flag(String envKey, String value) =>
      '$envKey=${value.trim().isNotEmpty ? '<set>' : '<unset>'}';

  static String _flagBool(String envKey, bool isSet) =>
      '$envKey=${isSet ? '<set>' : '<unset>'}';

  /// Redacted compile-time define audit (values never printed).
  static String dumpRedacted() {
    final lines = <String>[
      '[AdConfig] dump',
      _flagBool('ADS_ENABLED', adsEnabledDefine),
      _flagBool('DIAGNOSTICS_ENABLED', diagnosticsEnabledDefine),
      _flagBool('ADS_TEST_MODE', testMode),
      _flag('LEVELPLAY_APP_KEY', levelPlayAppKey),
      _flag('LEVELPLAY_INTERSTITIAL_AD_UNIT', interstitialAdUnitId),
      _flag('LEVELPLAY_REWARDED_AD_UNIT', rewardedAdUnitId),
      _flag('LEVELPLAY_BANNER_AD_UNIT', bannerAdUnitId),
      _flag('ADSTERRA_DIRECT_LINK', adsterraDirectLink),
      _flag('ADSTERRA_DIRECT_LINKS', adsterraDirectLinksBundle),
      'adsterraDirectLinkRotationCount=${adsterraDirectLinkRotation.length}',
      _flag('ADSTERRA_POPUNDER_SCRIPT_URL', adsterraPopunderScriptUrl),
      _flag('ADSTERRA_POPUNDER_BASE_URL', adsterraPopunderBaseUrl),
      _flag('ADSTERRA_NATIVE_INVOKE_URL', adsterraNativeInvokeUrl),
      _flag('ADSTERRA_NATIVE_BASE_URL', adsterraNativeBaseUrl),
      _flag('ADSTERRA_BANNER728_INVOKE_URL', adsterraBanner728InvokeUrl),
      _flag('ADSTERRA_BANNER728_BASE_URL', adsterraBanner728BaseUrl),
      _flag('CAP_BASE_URL', capBaseUrl),
      _flag('CAP_HMAC_KEY', capHmacKey),
      _flag('ADSTERRA_TELEMETRY_URL', adsterraTelemetryUrl),
      _flag('TOFFEE_SUBSCRIBER_TOKEN', toffeeSubscriberToken),
      'hasMonetizationConfig=${hasMonetizationConfig ? '<set>' : '<unset>'}',
      'hasLevelPlayAppKey=${hasLevelPlayAppKey ? '<set>' : '<unset>'}',
      'hasLevelPlayAdUnits=${hasLevelPlayAdUnits ? '<set>' : '<unset>'}',
      'hasAdsterraDirectLink=${hasAdsterraDirectLink ? '<set>' : '<unset>'}',
      'hasAdsterraWebViewZones=${hasAdsterraWebViewZones ? '<set>' : '<unset>'}',
    ];
    return lines.join(' ');
  }
}
