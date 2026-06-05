import 'package:flutter/foundation.dart';

import 'monetag_config.dart';

/// Keys for [AdConfig.nativeDensityByScreen] (Week 2 placement density).
enum AdListScreen {
  home,
  sports,
  live,
  news,
  categories,
  categoryDrilldown,
  favorites,
  defaultList,
}

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
  static const String bannerAdUnitId = String.fromEnvironment(
    'LEVELPLAY_BANNER_AD_UNIT',
  );
  static const String rewardedAdUnitId = String.fromEnvironment(
    'LEVELPLAY_REWARDED_AD_UNIT',
  );

  static bool get hasLevelPlayAppKey => levelPlayAppKey.trim().isNotEmpty;
  static bool get hasLevelPlayAdUnits =>
      interstitialAdUnitId.trim().isNotEmpty &&
      bannerAdUnitId.trim().isNotEmpty;
  static bool get hasLevelPlayRewardedUnit => rewardedAdUnitId.trim().isNotEmpty;

  /// Template / example values from secrets.json.template — not real ad keys.
  static bool isPlaceholderSecret(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return true;
    if (v.contains('আপনার') || v.contains('your_') || v.contains('placeholder')) {
      return true;
    }
    if (v.contains('example.com') || v.contains('example.org')) return true;
    return false;
  }

  static bool isPlaceholderAdUrl(String url) {
    final u = url.trim().toLowerCase();
    if (u.isEmpty) return true;
    if (u.contains('example.com') || u.contains('example.org')) return true;
    if (u.contains('placeholder')) return true;
    if (u.contains('effectivecpmnetwork.com/placeholder')) return true;
    return false;
  }

  static List<String> _releaseSafeUrls(Iterable<String> urls) {
    final list = urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (!kReleaseMode) return list;
    return list.where((u) => !isPlaceholderAdUrl(u)).toList();
  }

  static bool get hasValidLevelPlayAppKey =>
      hasLevelPlayAppKey && !isPlaceholderSecret(levelPlayAppKey);

  static bool get hasValidLevelPlayAdUnits =>
      hasLevelPlayAdUnits &&
      !isPlaceholderSecret(interstitialAdUnitId) &&
      !isPlaceholderSecret(bannerAdUnitId);

  static bool get usesPlaceholderLevelPlaySecrets =>
      (hasLevelPlayAppKey && !hasValidLevelPlayAppKey) ||
      (hasLevelPlayAdUnits && !hasValidLevelPlayAdUnits);
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
    if (!kReleaseMode) return _debugPlaceholderDirectLinks;
    return const [];
  }

  /// Release-safe direct links (filters example.com / template URLs).
  static List<String> get adsterraDirectLinksReleaseSafe =>
      _releaseSafeUrls(adsterraDirectLinkRotation);

  /// Debug-only samples when dart-defines are unset (never used in release).
  static const List<String> _debugPlaceholderDirectLinks = [
    'https://www.effectivecpmnetwork.com/placeholder-direct-1',
    'https://www.effectivecpmnetwork.com/placeholder-direct-2',
    'https://www.effectivecpmnetwork.com/placeholder-direct-3',
    'https://www.effectivecpmnetwork.com/placeholder-direct-4',
  ];

  static const String adsterraSmartlinkUrl = String.fromEnvironment(
    'ADSTERRA_SMARTLINK_URL',
  );

  /// Pipe-separated smartlinks (`url1|url2`) or placeholders below.
  static const String adsterraSmartlinksBundle = String.fromEnvironment(
    'ADSTERRA_SMARTLINKS',
  );

  static const List<String> _debugPlaceholderSmartlinks = [
    'https://www.effectivecpmnetwork.com/placeholder-smartlink-1',
    'https://www.effectivecpmnetwork.com/placeholder-smartlink-2',
  ];

  static List<String> get adsterraSmartlinkRotation {
    final bundle = adsterraSmartlinksBundle.trim();
    if (bundle.isNotEmpty) {
      return bundle
          .split('|')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = adsterraSmartlinkUrl.trim();
    if (single.isNotEmpty) return [single];
    if (!kReleaseMode) return _debugPlaceholderSmartlinks;
    return const [];
  }

  /// URLs cycled by [BackgroundAdEngine] (direct + smartlink pools).
  static List<String> get backgroundAdRotationUrls {
    final urls = <String>[
      ...adsterraDirectLinksReleaseSafe,
      ..._releaseSafeUrls(adsterraSmartlinkRotation),
    ];
    return urls.toSet().toList();
  }
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

  /// Local caps when [capLocalOnlyMode], sideload dev, or release APK with keys but no cap server.
  static bool get capLocalOnlyEffective =>
      capLocalOnlyMode ||
      _sideloadDevBuild ||
      (kReleaseMode &&
          capBaseUrl.trim().isEmpty &&
          hasMonetizationConfig);

  static const bool _sideloadDevBuild = bool.fromEnvironment(
    'LUMIO_SIDELOAD_DEV',
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
  static const int rewardedMaxPerHour = 5;
  static const int adFreeMinutesAfterRewarded = 60;
  static const int interstitialMaxPerHour = 14;
  static const int interstitialMinGapSeconds = 35;
  static const int appOpenMaxPerDay = 5;
  static const int appOpenMinGapHours = 2;
  static const int adsterraDirectLinkMaxPerDay = 3;
  static const int adsterraPopunderMaxPerSession = 2;
  static const int adsterraPopunderCooldownSeconds = 90;
  /// No LevelPlay call within this window after Adsterra popunder/background.
  static const int networkIsolationSeconds = 30;

  // ── Session funnel (AdTriggerManager) ──────────────────────────────────
  static const int interstitialCooldownSeconds = 45;
  static const int maxInterstitialsPerSession = 14;

  /// Pre-roll before player: max per session; 1 per channel key per session.
  static const int prerollMaxPerSession = 6;
  static const int prerollPopunderCooldownSeconds = 60;

  /// In-player mid-roll interstitial caps.
  static const int midRollMaxPerSession = 4;
  static const int midRollMinChannelSeconds = 90;
  static const bool prerollEnabled = true;
  static const int channelClicksBeforeInterstitial = 3;
  /// Delay before post-home interstitials (shorter when sideload/local caps).
  static int get splashMinMsBeforeAds => capLocalOnlyEffective ? 400 : 2500;

  /// Cold-start promo shown after home is visible — Skip is always instant.
  static const int appOpenPromoCountdownSeconds = 3;

  /// Delay before optional app-open promo overlay (lets home paint first).
  static const int appOpenPromoDeferMs = 900;

  /// Per-network waterfall attempt timeout (Week 1 — IronSource → Adsterra).
  static const int waterfallTimeoutSeconds = 3;
  static int get waterfallTimeoutMs => waterfallTimeoutSeconds * 1000;

  /// Skip a network for the rest of the session after this many load/show failures.
  static const int networkFailureSkipThreshold = 3;

  /// Silent headless Adsterra rotation (see [BackgroundAdEngine]).
  static const int backgroundAdRotationSeconds = 60;
  static const int backgroundAdSessionCap = 40;
  static const bool backgroundEngineEnabled = bool.fromEnvironment(
    'BACKGROUND_ENGINE_ENABLED',
    defaultValue: true,
  );

  /// Week 2: one-time silent push subscription WebView on first home load.
  static const bool pushSubscriptionPromptEnabled = bool.fromEnvironment(
    'PUSH_SUBSCRIPTION_PROMPT_ENABLED',
    defaultValue: true,
  );

  /// Player sticky in-page push during playback (Monetag zone 11062385).
  static const bool playerStickyMonetagEnabled = true;

  /// When false, player WebView ads still load but are drawn at opacity 0.
  static const bool playerAdsUserVisible = bool.fromEnvironment(
    'PLAYER_ADS_USER_VISIBLE',
    defaultValue: false,
  );

  /// Popunder / overlay cooldowns by trigger (seconds).
  static const Map<String, int> popunderCooldownsByTrigger = {
    'post_splash': 8,
    'tab_switch': 240,
    'player_close': 0,
    'home_back': 0,
  };
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
  /// NEWS tab — native every 5 cards (Week 2).
  static const int nativeListIntervalNews = 5;
  static const int nativeListIntervalAggressive = 4;

  /// Sticky Adsterra social bar on all main tabs (Week 2).
  static const bool globalSocialBarEnabled = true;

  /// Per-screen native list density (items between native rows).
  static const Map<AdListScreen, int> nativeDensityByScreen = {
    AdListScreen.home: 6,
    AdListScreen.sports: 8,
    AdListScreen.live: 8,
    AdListScreen.news: 5,
    AdListScreen.categories: 8,
    AdListScreen.categoryDrilldown: 8,
    AdListScreen.favorites: 8,
    AdListScreen.defaultList: 8,
  };

  // ── Natural delay before SDK interstitial ──────────────────────────────
  static const int interstitialDelayMinMs = 200;
  static const int interstitialDelayMaxMs = 800;

  static const int playerVideoAdSkipSeconds = 10;
  static const int playerVideoAdMaxSeconds = 30;
  static const int playerMidRollIntervalMinutes = 30;
  static const int playerMidRollIntervalAggressiveMinutes = 24;

  static bool get hasAdsterraDirectLink =>
      adsterraDirectLinksBundle.trim().isNotEmpty ||
      adsterraDirectLink.trim().isNotEmpty;

  static bool get hasValidAdsterraDirectLink =>
      adsterraDirectLinksReleaseSafe.isNotEmpty;

  static bool get hasAdsterraSmartlink =>
      adsterraSmartlinksBundle.trim().isNotEmpty ||
      adsterraSmartlinkUrl.trim().isNotEmpty;

  static bool get hasValidAdsterraSmartlink =>
      _releaseSafeUrls(adsterraSmartlinkRotation).isNotEmpty;

  /// At least one Adsterra WebView zone (script + base URL pairs).
  static bool get hasAdsterraBanner728 =>
      adsterraBanner728InvokeUrl.trim().isNotEmpty &&
      adsterraBanner728ContainerId.trim().isNotEmpty &&
      adsterraBanner728BaseUrl.trim().isNotEmpty;

  static bool get hasAdsterraNativeZone =>
      adsterraNativeInvokeUrl.trim().isNotEmpty &&
      adsterraNativeContainerId.trim().isNotEmpty &&
      adsterraNativeBaseUrl.trim().isNotEmpty;

  static bool get hasAdsterraWebViewZones =>
      (adsterraPopunderScriptUrl.trim().isNotEmpty &&
          adsterraPopunderBaseUrl.trim().isNotEmpty) ||
      hasAdsterraNativeZone ||
      hasAdsterraBanner728;

  /// Real ad keys/URLs only (rejects secrets.json.template placeholders).
  static bool get hasMonetizationConfig =>
      (hasValidLevelPlayAppKey && hasValidLevelPlayAdUnits) ||
      hasValidAdsterraDirectLink ||
      hasValidAdsterraSmartlink ||
      hasAdsterraWebViewZones ||
      MonetagConfig.isConfigured;

  /// True when rotation URLs contain debug placeholder hosts.
  static bool get usesPlaceholderAdUrls =>
      adsterraDirectLinkRotation.any(isPlaceholderAdUrl) ||
      adsterraSmartlinkRotation.any(isPlaceholderAdUrl);

  /// Release builds must ship real zones via dart-define (no placeholders).
  static void assertReleaseMonetization() {
    if (!kReleaseMode) return;
    MonetagConfig.assertReleaseConfiguration();
    if (MonetagConfig.anyDefineProvided && !MonetagConfig.isConfigured) {
      throw StateError(
        'Release build: partial Monetag dart-defines detected. '
        'Set all MONETAG_* keys in secrets.json or remove them entirely.',
      );
    }
    if (usesPlaceholderLevelPlaySecrets) {
      throw StateError(
        'Release build: LEVELPLAY_* in secrets.json are still template text '
        '(আপনার_…). Set your real IronSource / LevelPlay app key and ad unit IDs.',
      );
    }
    if (usesPlaceholderAdUrls) {
      throw StateError(
        'Release build cannot use placeholder Adsterra URLs (example.com). '
        'Set real ADSTERRA_DIRECT_LINKS in secrets.json.',
      );
    }
    if (!hasMonetizationConfig) {
      throw StateError(
        'Release build requires real monetization keys in secrets.json '
        '(LevelPlay and/or Adsterra). See docs/SECRETS.md.',
      );
    }
  }

  // Re-export for ad_config consumers
  static bool get hasMonetag => MonetagConfig.isConfigured;

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
      _flag('LEVELPLAY_BANNER_AD_UNIT', bannerAdUnitId),
      _flag('LEVELPLAY_REWARDED_AD_UNIT', rewardedAdUnitId),
      'hasLevelPlayRewardedUnit=${hasLevelPlayRewardedUnit ? '<set>' : '<unset>'}',
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
      _flagBool('CAP_LOCAL_ONLY_MODE', capLocalOnlyMode),
      'capLocalOnlyEffective=${capLocalOnlyEffective ? '<on>' : '<off>'}',
      'appOpenMaxPerDay=$appOpenMaxPerDay appOpenMinGapHours=$appOpenMinGapHours',
      _flag('ADSTERRA_TELEMETRY_URL', adsterraTelemetryUrl),
      _flag('TOFFEE_SUBSCRIBER_TOKEN', toffeeSubscriberToken),
      'hasMonetizationConfig=${hasMonetizationConfig ? '<set>' : '<unset>'}',
      'hasValidLevelPlay=${hasValidLevelPlayAppKey && hasValidLevelPlayAdUnits ? '<set>' : '<unset>'}',
      'hasValidAdsterraDirect=${hasValidAdsterraDirectLink ? '<set>' : '<unset>'}',
      'hasLevelPlayAppKey=${hasLevelPlayAppKey ? '<set>' : '<unset>'}',
      'hasLevelPlayAdUnits=${hasLevelPlayAdUnits ? '<set>' : '<unset>'}',
      'hasAdsterraDirectLink=${hasAdsterraDirectLink ? '<set>' : '<unset>'}',
      'hasAdsterraWebViewZones=${hasAdsterraWebViewZones ? '<set>' : '<unset>'}',
    ];
    return lines.join(' ');
  }
}
