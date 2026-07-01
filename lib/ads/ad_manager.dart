import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/logging/safe_logger.dart';
import '../config/ad_config.dart';
import 'rewarded_features.dart';
import 'session_pacing.dart';
import 'ad_log.dart';
import '../models/model.dart';
import '../services/ad_consent_service.dart';
import '../services/ad_safety_service.dart';
import '../services/ad_trigger_manager.dart';
import 'ad_cold_start_eligibility.dart';
import 'cmp_tier1_gate.dart';
import 'interstitial_placement.dart';
import '../services/user_preferences.dart';
import '../utils/session_debug_log.dart';
import '../utils/ad_debug_log.dart';
// import 'ad_waterfall.dart'; // REMOVED: Waterfall system disabled
import 'background_ad_engine.dart';
import 'adsterra_engine.dart';
import 'adsterra_telemetry_client.dart';
import 'analytics/ad_analytics.dart';
import '../services/unity_ads_service.dart';
import '../services/server_cap.dart';
import 'server_cap_client.dart';
import 'ad_placement_config.dart';
import '../services/app_session_tracker.dart';
import 'strategies/geo_targeting.dart';
// import 'utils/webview_pool.dart'; // REMOVED: Unused import

/// Global ad orchestration — singleton.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  final AdAnalytics analytics = AdAnalytics();
  final _caps = AdTriggerManager.instance;

  bool _initialized = false;
  bool _isStreaming = false;
  bool _disposed = false;

  /// Hides shell ad chrome (social bar, floating native) during player fullscreen.
  final ValueNotifier<bool> adChromeHidden = ValueNotifier(false);
  bool _preloadDone = false;
  Timer? _backgroundEngineStartTimer;
  bool _backgroundEngineScheduled = false;

  /// Fire-and-forget analytics with error logging (P1-5).
  Future<void> _safeAnalytics(Future<void> future) async {
    try {
      await future;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AdManager] analytics failed: $e\n$st');
      }
    }
  }

  bool _postHomeWarmupStarted = false;
  bool _loggedRuntimeStatus = false;

  /// Prevents duplicate first-tap browser launches while async work runs.
  final Set<String> _channelTapFirstTapInFlight = {};
  static bool _loggedNoAdStackWarning = false;

  /// True when ad orchestration finished init (Unity Ads and/or Adsterra config).
  bool get isReady => _initialized && AdConfig.hasMonetizationConfig;

  bool get unityAdsReady => UnityAdsService.instance.isInitialized;

  bool get unityRewardedReady =>
      UnityAdsService.instance.isInitialized &&
      UnityAdsService.instance.isRewardedReady;

  /// Prefer [isReady] — kept for legacy call sites.
  bool get isInitialized => isReady;

  bool get isStreaming => _isStreaming;
  bool get adsEnabled =>
      (isReady &&
          AdSafetyService.instance.adsEnabledRemote &&
          !ServerCap.instance.blocksAdsInRelease &&
          !UserPreferences.removeAdsPurchased &&
          !_caps.isAdFree);

  bool get unityAdsEnabled => false; // Unity Ads disabled

  /// Adsterra WebView banners/natives — false when zones unset or ads off (no black placeholders).
  bool get showAdsterraWebViewSlots =>
      adsEnabled && AdConfig.hasAdsterraWebViewZones;

  bool get isUserAdFree => UserPreferences.removeAdsPurchased || _caps.isAdFree;

  /// Channel-tap browser ad — works when direct links are compiled in, even if
  /// full WebView ad stack did not finish init.
  bool get canMonetizeChannelTap =>
      !UserPreferences.removeAdsPurchased &&
      !_caps.isAdFree &&
      !ServerCap.instance.blocksAdsInRelease &&
      AdConfig.hasValidAdsterraDirectLink &&
      AdSafetyService.instance.adsEnabledRemote &&
      !AdSafetyService.instance.adsBlockedInDebug;

  /// Retry after consent dialog when first init was blocked or privacy flags updated.
  Future<void> retryInitAfterConsent() async {
    if (isReady) return;
    adLog('[AdManager] retry init after consent');
    await init();
  }

  Future<void> init() async {
    if (isReady) return;

    await UserPreferences.ensureInit();
    await AdSafetyService.instance.ensureReady();

    // In debug mode, if ads are not configured, skip init entirely
    if (kDebugMode && !AdConfig.hasMonetizationConfig) {
      if (!_loggedNoAdStackWarning) {
        _loggedNoAdStackWarning = true;
        adLog('[AdManager] Ads disabled or config missing in debug; skipping init');
      }
      _initialized = false;
      logRuntimeStatusOnce();
      return;
    }

    if (CmpTier1Gate.blocksAdSdkInitFor(
      localeCountry: CmpTier1Gate.deviceCountryCode(),
      simCountry: AdSafetyService.instance.simCountry,
      networkCountry: AdSafetyService.instance.networkCountry,
    )) {
      _initialized = false;
      if (!_loggedNoAdStackWarning) {
        _loggedNoAdStackWarning = true;
        AdDebugLog.error(
          'AdManager.init',
          'tier-1 market without licensed CMP — ad SDK init blocked',
          data: {
            'locale': CmpTier1Gate.deviceCountryCode(),
            'sim': AdSafetyService.instance.simCountry,
            'network': AdSafetyService.instance.networkCountry,
            'cmpLicensed': CmpTier1Gate.cmpLicensedEnabled,
          },
        );
      }
      logRuntimeStatusOnce();
      return;
    }

    AdsterraTelemetryService.instance.logConfigurationOnce();
    AdPlacementConfig.logPlacementSummaryOnce();
    ServerCapService.instance.attachAnalytics(analytics);
    await _caps.startSession();
    await AppSessionTracker.instance.onAppLaunch();
    await analytics.init();
    await analytics.logAppOpen();
    final adFree = UserPreferences.adFreeUntil;
    if (adFree != null && DateTime.now().isBefore(adFree)) {
      _caps.setAdFreeUntil(adFree);
    }

    if (!AdSafetyService.instance.adsEnabledRemote) {
      _initialized = false;
      if (!_loggedNoAdStackWarning) {
        _loggedNoAdStackWarning = true;
        AdDebugLog.error(
          'AdManager.init',
          'ads disabled via Remote Config',
          data: {'ads_enabled': false},
        );
      }
      logRuntimeStatusOnce();
      return;
    }

    if (!AdConfig.hasMonetizationConfig) {
      _initialized = false;
      if (!_loggedNoAdStackWarning) {
        _loggedNoAdStackWarning = true;
        AdDebugLog.error(
          'AdManager.init',
          'monetization config incomplete',
          data: {
            'unityAds': AdConfig.hasUnityConfig,
            'adsterraDirect': AdConfig.hasValidAdsterraDirectLink,
            'adsterraSmartlink': AdConfig.hasValidAdsterraSmartlink,
            'adsterraWebView': AdConfig.hasAdsterraWebViewZones,
            'placeholderAdUrls': AdConfig.usesPlaceholderAdUrls,
          },
        );
      }
      logRuntimeStatusOnce();
      return;
    }

    // Unity Ads removed - using Adsterra only
    const unityOk = false;
    adLog('[AdManager] Unity Ads disabled - using Adsterra only');

    final adsterraOk = AdConfig.hasValidAdsterraDirectLink ||
        AdConfig.hasValidAdsterraSmartlink ||
        AdConfig.hasAdsterraWebViewZones;

    if (!adsterraOk) {
      _initialized = false;
      if (!_loggedNoAdStackWarning) {
        _loggedNoAdStackWarning = true;
        AdDebugLog.error(
          'AdManager.init',
          'no ad stack available',
          data: {
            'unityAds': unityOk,
            'adsterra': adsterraOk,
            'blockedInDebug': AdSafetyService.instance.adsBlockedInDebug,
          },
        );
      }
      logRuntimeStatusOnce();
      return;
    }

    _initialized = true;
    BackgroundAdEngine.isStreamingProbe = () => _isStreaming;
    // REMOVED: Waterfall system attachment
    // AdWaterfall.instance.attach(
    //   unityAds: UnityAdsService.instance,
    //   analytics: analytics,
    // );
    adLog(
      '[AdManager] init OK unity=$unityOk adsterra=$adsterraOk '
      'aggressive_mode=${AdSafetyService.instance.aggressiveMode}',
    );
    // REMOVED: Waterfall preload
    // if (unityOk) AdWaterfall.instance.preloadAll();
    logRuntimeStatusOnce();
  }

  /// One-line release logcat status (grep `LumioAds`).
  void logRuntimeStatusOnce() {
    if (_loggedRuntimeStatus) return;
    _loggedRuntimeStatus = true;
    final safety = AdSafetyService.instance;
    // ignore: avoid_print
    print(
      '[LumioAds] ready=$isReady adsEnabled=$adsEnabled '
      'initialized=$_initialized streaming=$_isStreaming '
      'unityAdsReady=$unityAdsReady '
      'unityRewardedReady=$unityRewardedReady '
      'blocksCap=${ServerCap.instance.blocksAdsInRelease} '
      'capLocal=${AdConfig.capLocalOnlyEffective} '
      'rcAds=${safety.adsEnabledRemote} '
      'monetization=${AdConfig.hasMonetizationConfig} '
      'consent=${AdConsentService.instance.hasGrantedConsent}',
    );
  }

  /// Splash: preload only — no visible ads.
  Future<void> preloadFromSplash() async {
    if (_preloadDone) return;
    await init();
    // REMOVED: Waterfall preload
    // AdWaterfall.instance.preloadAll();
    _preloadDone = true;
  }

  /// Call after splash → home; starts silent background engine after 8s.
  void scheduleBackgroundEngineAfterSplash() {
    if (_backgroundEngineScheduled) return;
    if (!AdConfig.backgroundEngineEnabled) return;
    _backgroundEngineScheduled = true;
    _backgroundEngineStartTimer?.cancel();
    _backgroundEngineStartTimer = Timer(const Duration(seconds: 8), () {
      if (!_initialized || !adsEnabled) return;
      if (AdManager.instance._disposed) return;
      unawaited(BackgroundAdEngine.start());
    });
  }

  void onAppResume() {
    // Unity Ads doesn't need explicit foreground handling
    unawaited(BackgroundAdEngine.onAppForegrounded());
  }

  void onAppPause() {
    BackgroundAdEngine.onAppBackgrounded();
    // Don't release WebViews on background - engine continues running at slower cadence
    // WebViewPool.instance.releaseAllOnBackground();
  }

  Future<void> onAppExit() async {
    _disposed = true;
    _backgroundEngineStartTimer?.cancel();
    await BackgroundAdEngine.dispose();
  }

  void setStreaming(bool active) {
    _isStreaming = active;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      adChromeHidden.value = active;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        adChromeHidden.value = active;
      });
    }
    BackgroundAdEngine.isStreamingProbe = () => _isStreaming;
    if (active) {
      BackgroundAdEngine.pause();
    } else if (_initialized) {
      unawaited(BackgroundAdEngine.resume());
    }
  }

  /// Eligibility probe only — WebView mount + cap record happen in [AdsterraPopunderHost].
  Future<void> maybeShowPopunder() async {
    if (!adsEnabled) return;
    if (!AdSafetyService.instance.popunderEnabledRemote) return;
    if (!AdSafetyService.instance.adsterraEnabled) return;
    if (!await _caps.canShowPopunder()) {
      AdDebugLog.info(
        'AdManager.maybeShowPopunder',
        'popunder blocked — host will not mount',
      );
      return;
    }
    AdDebugLog.info(
      'AdManager.maybeShowPopunder',
      'popunder eligible — host may mount WebView',
    );
  }

  /// Called once when popunder WebView is actually built (after cap gate).
  Future<void> onPopunderWebViewMounted() async {
    if (!await _caps.canShowPopunder()) return;
    await _caps.recordAdsterraPopunder();
    logAdsterraTelemetry(placement: 'popunder', format: 'popunder');
    AdDebugLog.info('AdManager', 'popunder mounted — session cap recorded');
  }

  /// After home is visible: preload SDK.
  Future<void> warmupAfterHomeVisible(BuildContext context) async {
    if (_postHomeWarmupStarted) return;
    _postHomeWarmupStarted = true;
    await AdTriggerManager.instance.waitUntilAdsEligible();
    if (!context.mounted) return;
    await preloadFromSplash();
    if (!context.mounted) return;
    await AdColdStartEligibility.evaluateAndLog();
    // App-open promo removed - no ad shown after home
  }

  // void _logColdStartSkipped(AdColdStartEligibilityReport report) {
  //   report.logToConsole();
  //   final reason = report.primaryBlocker?.codeName ?? 'unknown';
  //   unawaited(
  //     analytics.logAdInterstitialSkippedCap(
  //       placement: InterstitialPlacement.appOpen.analyticsName,
  //       reason: reason,
  //     ),
  //   );
  // }

  /// Cold-start substitute: Unity Ads interstitial.
  /// DISABLED: Unity Ads removed, using Adsterra only.
  Future<bool> showColdStartAppOpen() async {
    adLog('[AdManager] showColdStartAppOpen disabled - Unity Ads removed');
    return false;
  }

  /// Post-splash Adsterra direct link (3/device/day cap) — see PLACEMENT_MAP.
  Future<bool> showSplashDirectLinkIfAllowed() async {
    if (!adsEnabled) return false;
    if (!AdSafetyService.instance.adsterraEnabled) return false;
    return AdsterraEngine.instance.openDirectLink(
      placement: 'splash_post',
      analytics: analytics,
    );
  }

  /// Channel tap: 1st tap → external browser ad; 2nd tap → player immediately.
  Future<ChannelTapResult> handleChannelTap({
    required ChannelModel channel,
    required Future<void> Function() onPlay,
    BuildContext? context,
    bool skipInterstitial = false,
  }) async {
    if (!isReady) await init();
    await UserPreferences.ensureInit();
    final key = channelTapKey(channel);

    // Second tap (or ads off): go straight to playback — no interstitial delay.
    if (!canMonetizeChannelTap ||
        AdTriggerManager.instance.hasChannelTapBrowserShown(key)) {
      // #region agent log
      sessionDebugLog(
        location: 'ad_manager.dart:handleChannelTap',
        message: 'Skip browser — play directly',
        hypothesisId: 'H3-channel-tap-ads',
        data: {
          'canMonetize': canMonetizeChannelTap,
          'adsEnabled': adsEnabled,
          'isReady': isReady,
          'hasDirectLinks': AdConfig.hasValidAdsterraDirectLink,
          'browserShown': AdTriggerManager.instance.hasChannelTapBrowserShown(key),
          'directLinkCount': AdConfig.adsterraDirectLinksReleaseSafe.length,
        },
      );
      // #endregion
      if (canMonetizeChannelTap || adsEnabled) {
        _caps.recordChannelClick();
        await _safeAnalytics(
          analytics.logChannelClick(count: _caps.sessionChannelClicks),
        );
      }
      await onPlay();
      return const ChannelTapResult(played: true);
    }

    if (_channelTapFirstTapInFlight.contains(key)) {
      return const ChannelTapResult(
        played: false,
        showTapAgainHint: true,
      );
    }
    _channelTapFirstTapInFlight.add(key);
    try {
      await _safeAnalytics(
        analytics.logChannelTapSlot(slot: 'browser_first'),
      );

      if (context == null || !context.mounted) {
        _channelTapFirstTapInFlight.remove(key);
        return const ChannelTapResult(
          played: false,
          showTapAgainHint: true,
        );
      }

      final monetized = await _openChannelTapBrowserFirst(
        placement: 'channel_tap_first',
        channelKey: key,
        context: context,
      );

      // #region agent log
      sessionDebugLog(
        location: 'ad_manager.dart:handleChannelTap',
        message: 'First tap browser result',
        hypothesisId: 'H3-channel-tap-ads',
        data: {
          'monetized': monetized,
          'channelKey': key,
        },
      );
      // #endregion

      // BUG FIX: Check mounted after browser operation
      if (!context.mounted) {
        _channelTapFirstTapInFlight.remove(key);
        return const ChannelTapResult(
          played: false,
          showTapAgainHint: true,
        );
      }

      if (kDebugMode) {
        debugPrint(
          '[ChannelTap] first tap key=$key browser monetized=$monetized',
        );
      }
      if (monetized) {
        AdTriggerManager.instance.markChannelTapBrowserShown(key);
        return const ChannelTapResult(
          played: false,
          showTapAgainHint: true,
        );
      }

      // Browser unavailable — play now; do not require a second tap.
      await onPlay();
      return const ChannelTapResult(
        played: true,
        showTapAgainHint: false,
      );
    } catch (e) {
      // BUG FIX: Ensure key is removed on error
      _channelTapFirstTapInFlight.remove(key);
      SafeLogger.error('ad', '[ChannelTap] Error in handleChannelTap', e, null);
      // On error, play immediately to not block user
      await onPlay();
      return const ChannelTapResult(
        played: true,
        showTapAgainHint: false,
      );
    } finally {
      _channelTapFirstTapInFlight.remove(key);
    }
  }

  /// External browser with Adsterra direct link rotation for channel tap.
  Future<bool> _openChannelTapBrowserFirst({
    required String placement,
    required String channelKey,
    BuildContext? context,
  }) async {
    if (!AdSafetyService.instance.adsEnabledRemote) {
      adLog('[ChannelTapBrowser] Blocked - ads_enabled remote config off');
      return false;
    }

    // Open external browser with rotated Adsterra direct link
    final browserOk = await AdsterraEngine.instance.openChannelTapBrowser(
      placement: placement,
      analytics: analytics,
      channelIdForFirstClick: channelKey,
    );

    if (browserOk) {
      return true;
    }

    // Unity Ads fallback disabled - using Adsterra only
    return false;
  }

  /// News headline: 1st tap → Adsterra direct link in browser; 2nd tap → open article URL.
  Future<NewsArticleTapResult> handleNewsArticleTap({
    required NewsModel article,
  }) async {
    if (!isReady) await init();
    final id = article.id.trim().isNotEmpty
        ? article.id.trim()
        : article.title.hashCode.toString();

    final showBrowserFirst =
        adsEnabled && !AdTriggerManager.instance.hasNewsArticleAdShown(id);

    if (showBrowserFirst) {
      final browserOk = await AdsterraEngine.instance.openNewsArticleBrowser(
        placement: 'news_article_first',
        analytics: analytics,
        articleId: id,
      );
      if (kDebugMode) {
        debugPrint(
          '[NewsTap] first tap id=$id browser=$browserOk adsEnabled=$adsEnabled',
        );
      }
      if (browserOk) {
        AdTriggerManager.instance.markNewsArticleAdShown(id);
        logAdsterraTelemetry(
          placement: 'news_article_first',
          format: 'direct_link_browser',
        );
      }
      return const NewsArticleTapResult(
        opened: false,
        showTapAgainHint: true,
      );
    }

    return const NewsArticleTapResult(opened: true);
  }

  /// Gated interstitial with placement caps + analytics (Unity Ads → Adsterra waterfall).
  Future<bool> showPlacementInterstitial({
    BuildContext? context,
    required InterstitialPlacement placement,
    String? channelKey,
  }) async {
    if (!isReady) await init();
    if (!adsEnabled) return false;
    if (!AdConsentService.instance.hasGrantedConsent) return false;

    final removeAds = UserPreferences.removeAdsPurchased;
    final cap = await _caps.canShowPlacement(
      placement,
      removeAds: removeAds,
      channelKey: channelKey,
    );

    if (context == null || !context.mounted) return false;

    if (!cap.allowed) {
      if (cap.reason != null) {
        unawaited(
          analytics.logAdInterstitialSkippedCap(
            placement: placement.analyticsName,
            reason: cap.reason!,
          ),
        );
      }
      return false;
    }

    _caps.recordInterstitialAttempted();
    // REMOVED: Waterfall system, using direct Adsterra
    final shown = await AdsterraEngine.instance.openDirectLink(
      placement: placement.trigger,
      analytics: analytics,
    );

    if (shown) {
      await _caps.recordPlacementShown(
        placement,
        channelKey: channelKey,
      );
      unawaited(
        analytics.logAdInterstitialShown(
          placement: placement.analyticsName,
          network: 'adsterra',
        ),
      );
      return true;
    }

    unawaited(
      analytics.logAdInterstitialFailed(
        placement: placement.analyticsName,
        network: 'adsterra',
        error: 'no_fill',
      ),
    );
    return false;
  }

  Future<bool> showPreRollInterstitial({BuildContext? context}) =>
      showPlacementInterstitial(
        context: context,
        placement: InterstitialPlacement.preroll,
      );

  Future<bool> showMidRollInterstitial({BuildContext? context}) =>
      showPlacementInterstitial(
        context: context,
        placement: InterstitialPlacement.midroll,
      );

  /// Unity Ads rewarded — returns true when user earns reward.
  /// DISABLED: Unity Ads removed, using Adsterra only.
  Future<bool> showRewarded({required String trigger}) async {
    adLog('[AdManager] showRewarded disabled - Unity Ads removed');
    return false;
  }

  /// Unity Ads rewarded with typed feature enum — returns true when user earns reward.
  /// DISABLED: Unity Ads removed, using Adsterra only.
  Future<bool> showRewardedFeature({required RewardedFeatures feature}) async {
    adLog('[AdManager] showRewardedFeature disabled - Unity Ads removed');
    return false;
  }

  /// Watch rewarded → temporary ad-free window.
  /// DISABLED: Unity Ads removed, using Adsterra only.
  Future<bool> showRewardedForAdFree({required String trigger}) async {
    adLog('[AdManager] showRewardedForAdFree disabled - Unity Ads removed');
    return false;
  }

  Future<bool> onSportsTabSelected({BuildContext? context}) async {
    if (!adsEnabled) return false;
    if (!await _caps.canShowUnityInterstitial(
      isStreaming: _isStreaming,
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }

    // Monetag vignette removed

    if (context != null && !context.mounted) return false;
    return showInterstitial(context: context, trigger: 'tab_switch');
  }

  /// Optional Monetag smartlink before opening external news URL (2nd tap).
  Future<void> maybeMonetizeNewsReadMore() async {
    // Monetag removed
    return;
  }

  /// Exit stack: Unity Ads interstitial first, then Adsterra direct link fallback.
  Future<bool> onExitIntent() async {
    if (!_caps.canShowExitAd(
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }

    var consumed = false;
    if (await _caps.canShowUnityInterstitial(
      isStreaming: false,
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      consumed = await showInterstitial(trigger: 'back_exit');
    }

    if (!consumed && AdSafetyService.instance.adsterraEnabled) {
      consumed = await AdsterraEngine.instance.openDirectLink(
        placement: 'back_exit',
        analytics: analytics,
      );
      if (consumed) {
        logAdsterraTelemetry(placement: 'back_exit', format: 'direct_link');
      }
    }

    if (consumed) {
      _caps.recordExitAdShown();
    }
    return consumed;
  }

  /// Unity Ads → Adsterra waterfall (respects caps when called via gated paths).
  Future<bool> showInterstitial({
    BuildContext? context,
    required String trigger,
  }) async {
    if (!isReady) await init();
    if (!adsEnabled) return false;

    if (context == null || !context.mounted) return false;

    // Session pacing: no full-screen ads in first 60 seconds
    if (!SessionPacing.instance.canShowFullScreenAd()) {
      SafeLogger.debug('ads', '[SessionPacing] first minute, skipping full-screen ad');
      return false;
    }

    // REMOVED: Waterfall system, using direct Adsterra
    return AdsterraEngine.instance.openDirectLink(
      placement: trigger,
      analytics: analytics,
    );
  }

  int get maxInterstitials => GeoTargeting.adjustedMaxInterstitials(
        AdConfig.maxInterstitialsPerSession,
      );
}

class ChannelTapResult {
  final bool played;
  final bool showTapAgainHint;

  const ChannelTapResult({
    required this.played,
    this.showTapAgainHint = false,
  });
}

class NewsArticleTapResult {
  final bool opened;
  final bool showTapAgainHint;

  const NewsArticleTapResult({
    required this.opened,
    this.showTapAgainHint = false,
  });
}
