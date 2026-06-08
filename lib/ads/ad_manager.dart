import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
import '../utils/channel_tap_key.dart';
import '../utils/ad_debug_log.dart';
import 'ad_waterfall.dart';
import 'background_ad_engine.dart';
import 'adsterra_engine.dart';
import 'adsterra_telemetry_client.dart';
import 'analytics/ad_analytics.dart';
import 'ironsource_service.dart';
import '../services/server_cap.dart';
import 'server_cap_client.dart';
import 'ad_placement_config.dart';
import 'propeller/propeller_engine.dart';
import '../config/monetag_config.dart';
import '../services/app_session_tracker.dart';
import 'strategies/geo_targeting.dart';
import 'utils/webview_pool.dart';
import '../screens/app_open_promo_screen.dart';

/// Global ad orchestration — singleton.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  final AdAnalytics analytics = AdAnalytics();
  final _caps = AdTriggerManager.instance;

  bool _initialized = false;
  bool _isStreaming = false;

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

  /// True when ad orchestration finished init (LevelPlay and/or Adsterra config).
  bool get isReady => _initialized && AdConfig.hasMonetizationConfig;

  bool get levelPlayReady => LevelPlayAdService.instance.isInitialized;

  bool get levelPlayRewardedReady =>
      LevelPlayAdService.instance.isInitialized &&
      AdConfig.hasLevelPlayRewardedUnit &&
      LevelPlayAdService.instance.isRewardedReady;

  /// Prefer [isReady] — kept for legacy call sites.
  bool get isInitialized => isReady;

  bool get isStreaming => _isStreaming;
  bool get adsEnabled =>
      isReady &&
      AdSafetyService.instance.adsEnabledRemote &&
      !ServerCap.instance.blocksAdsInRelease &&
      !UserPreferences.removeAdsPurchased &&
      !_caps.isAdFree;

  bool get levelPlayAdsEnabled =>
      adsEnabled && AdSafetyService.instance.levelPlayEnabledRemote;

  /// Adsterra WebView banners/natives — false when zones unset or ads off (no black placeholders).
  bool get showAdsterraWebViewSlots =>
      adsEnabled && AdConfig.hasAdsterraWebViewZones;

  bool get isUserAdFree =>
      UserPreferences.removeAdsPurchased || _caps.isAdFree;

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

    if (CmpTier1Gate.blocksAdSdkInitFor(
      localeCountry: CmpTier1Gate.deviceCountryCode(),
      simCountry: AdSafetyService.instance.simCountry,
      networkCountry: AdSafetyService.instance.networkCountry,
    )) {
      _initialized = false;
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
      AdDebugLog.error(
        'AdManager.init',
        'ads disabled via Remote Config',
        data: {'ads_enabled': false},
      );
      logRuntimeStatusOnce();
      return;
    }

    if (!AdConfig.hasMonetizationConfig) {
      _initialized = false;
      AdDebugLog.error(
        'AdManager.init',
        'monetization config incomplete',
        data: {
          'levelPlayKey': AdConfig.hasValidLevelPlayAppKey,
          'levelPlayUnits': AdConfig.hasValidLevelPlayAdUnits,
          'adsterraDirect': AdConfig.hasValidAdsterraDirectLink,
          'adsterraSmartlink': AdConfig.hasValidAdsterraSmartlink,
          'adsterraWebView': AdConfig.hasAdsterraWebViewZones,
          'placeholderLevelPlay': AdConfig.usesPlaceholderLevelPlaySecrets,
          'placeholderAdUrls': AdConfig.usesPlaceholderAdUrls,
        },
      );
      logRuntimeStatusOnce();
      return;
    }

    var lpOk = false;
    if (AdConfig.hasValidLevelPlayAppKey && AdConfig.hasValidLevelPlayAdUnits) {
      LevelPlayAdService.instance.attachAnalytics(analytics);
      lpOk = await LevelPlayAdService.instance.init();
    }

    final adsterraOk =
        AdConfig.hasValidAdsterraDirectLink ||
        AdConfig.hasValidAdsterraSmartlink ||
        AdConfig.hasAdsterraWebViewZones;

    if (!lpOk && !adsterraOk) {
      _initialized = false;
      AdDebugLog.error(
        'AdManager.init',
        'no ad stack available',
        data: {
          'levelPlay': lpOk,
          'adsterra': adsterraOk,
          'blockedInDebug': AdSafetyService.instance.adsBlockedInDebug,
        },
      );
      logRuntimeStatusOnce();
      return;
    }

    _initialized = true;
    BackgroundAdEngine.isStreamingProbe = () => _isStreaming;
    AdWaterfall.instance.attach(
      levelPlay: LevelPlayAdService.instance,
      analytics: analytics,
    );
    adLog(
      '[AdManager] init OK levelplay=$lpOk adsterra=$adsterraOk '
      'aggressive_mode=${AdSafetyService.instance.aggressiveMode}',
    );
    if (lpOk) AdWaterfall.instance.preloadAll();
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
      'levelPlayReady=$levelPlayReady '
      'rewardedReady=$levelPlayRewardedReady '
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
    AdWaterfall.instance.preloadAll();
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
      unawaited(BackgroundAdEngine.start());
    });
  }

  void onAppResume() {
    LevelPlayAdService.instance.onAppForeground();
    unawaited(BackgroundAdEngine.onAppForegrounded());
  }

  void onAppPause() {
    BackgroundAdEngine.onAppBackgrounded();
    WebViewPool.instance.releaseAllOnBackground();
  }

  Future<void> onAppExit() async {
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

  /// After home is visible: preload SDK → LevelPlay interstitial → Adsterra promo.
  Future<void> warmupAfterHomeVisible(BuildContext context) async {
    if (_postHomeWarmupStarted) return;
    _postHomeWarmupStarted = true;
    await AdTriggerManager.instance.waitUntilAdsEligible();
    if (!context.mounted) return;
    await preloadFromSplash();
    if (!context.mounted) return;
    await AdColdStartEligibility.evaluateAndLog();
    if (!context.mounted) return;
    await Future.delayed(
      Duration(milliseconds: AdConfig.appOpenPromoDeferMs),
    );
    if (!context.mounted) return;
    await presentColdStartPromoIfEligible(context);
  }

  /// LevelPlay interstitial first, then in-app Adsterra WebView promo.
  Future<bool> presentColdStartPromoIfEligible(BuildContext context) async {
    final report = await AdColdStartEligibility.evaluate();
    if (!report.canShowAnyPromo) {
      _logColdStartSkipped(report);
      return false;
    }
    if (!context.mounted) return false;

    if (report.canShowLevelPlay) {
      final lpShown = await showColdStartAppOpen();
      if (lpShown) return true;
    }

    final showPromoScreen =
        report.canShowAdsterra || report.canShowHousePromo;
    if (!showPromoScreen) {
      unawaited(
        analytics.logAdInterstitialFailed(
          placement: InterstitialPlacement.appOpen.analyticsName,
          network: 'cold_start',
          error: AdColdStartBlockerCode.noThirdPartyFill.name,
        ),
      );
      report.logToConsole();
      return false;
    }
    if (!context.mounted) return false;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AppOpenPromoScreen(),
        fullscreenDialog: true,
      ),
    );
    return true;
  }

  void _logColdStartSkipped(AdColdStartEligibilityReport report) {
    report.logToConsole();
    final reason = report.primaryBlocker?.codeName ?? 'unknown';
    unawaited(
      analytics.logAdInterstitialSkippedCap(
        placement: InterstitialPlacement.appOpen.analyticsName,
        reason: reason,
      ),
    );
  }

  /// Cold-start substitute: LevelPlay interstitial (legacy — prefer [presentColdStartPromoIfEligible]).
  Future<bool> showColdStartAppOpen() async {
    if (!levelPlayAdsEnabled) return false;
    if (!AdConsentService.instance.hasGrantedConsent) return false;
    final cap = await _caps.canShowPlacement(
      InterstitialPlacement.appOpen,
      removeAds: UserPreferences.removeAdsPurchased,
    );
    if (!cap.allowed) {
      if (cap.reason != null) {
        unawaited(
          analytics.logAdInterstitialSkippedCap(
            placement: InterstitialPlacement.appOpen.analyticsName,
            reason: cap.reason!,
          ),
        );
      }
      return false;
    }
    final ok = await LevelPlayAdService.instance.showAppOpenSubstitute(
      removeAds: UserPreferences.removeAdsPurchased,
    );
    if (ok) {
      unawaited(
        analytics.logAdInterstitialShown(
          placement: InterstitialPlacement.appOpen.analyticsName,
          network: 'levelplay',
        ),
      );
    } else {
      unawaited(
        analytics.logAdInterstitialFailed(
          placement: InterstitialPlacement.appOpen.analyticsName,
          network: 'levelplay',
          error: 'no_fill',
        ),
      );
    }
    return ok;
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
    if (!adsEnabled ||
        AdTriggerManager.instance.hasChannelTapBrowserShown(key)) {
      if (adsEnabled) {
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

      final monetized = await _openChannelTapBrowserFirst(
        placement: 'channel_tap_first',
        channelKey: key,
        context: context,
      );

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
    } finally {
      _channelTapFirstTapInFlight.remove(key);
    }
  }

  /// Adsterra direct link → Monetag smartlink → optional in-app interstitial.
  Future<bool> _openChannelTapBrowserFirst({
    required String placement,
    required String channelKey,
    BuildContext? context,
  }) async {
    if (AdConfig.hasValidAdsterraDirectLink &&
        AdSafetyService.instance.adsEnabledRemote &&
        await AdTriggerManager.instance.canShowChannelTapBrowser()) {
      final ok = await AdsterraEngine.instance.openChannelTapBrowser(
        placement: placement,
        analytics: analytics,
        channelIdForFirstClick: channelKey,
      );
      if (ok) {
        logAdsterraTelemetry(
          placement: placement,
          format: 'direct_link_browser',
        );
        return true;
      }
    }

    if (MonetagConfig.isConfigured) {
      final ok = await PropellerEngine.instance.openSmartlink(
        placement: placement,
        analytics: analytics,
      );
      if (ok) {
        AdTriggerManager.instance.recordAdsterraSurfaceEvent();
        return true;
      }
    }

    if (context != null &&
        context.mounted &&
        levelPlayAdsEnabled &&
        !AdSafetyService.instance.preferCleanSdkRouting) {
      return showInterstitial(context: context, trigger: 'channel_tap_first');
    }
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

    final showBrowserFirst = adsEnabled &&
        !AdTriggerManager.instance.hasNewsArticleAdShown(id);

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

  Future<void> _playWithPreroll({
    BuildContext? context,
    required String channelKey,
    required Future<void> Function() onPlay,
  }) async {
    if (adsEnabled && context != null && context.mounted) {
      await showPlacementInterstitial(
        context: context,
        placement: InterstitialPlacement.preroll,
        channelKey: channelKey,
      );
    }
    await onPlay();
  }

  /// Gated interstitial with placement caps + analytics (LevelPlay → Adsterra waterfall).
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
    final shown = await AdWaterfall.instance.showInterstitial(
      context,
      trigger: placement.trigger,
    );

    if (shown) {
      await _caps.recordPlacementShown(
        placement,
        channelKey: channelKey,
      );
      unawaited(
        analytics.logAdInterstitialShown(
          placement: placement.analyticsName,
          network: 'waterfall',
        ),
      );
      return true;
    }

    unawaited(
      analytics.logAdInterstitialFailed(
        placement: placement.analyticsName,
        network: 'waterfall',
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

  /// LevelPlay rewarded — returns true when user earns reward.
  Future<bool> showRewarded({required String trigger}) async {
    if (!adsEnabled || !levelPlayAdsEnabled) return false;
    if (!AdConfig.hasLevelPlayRewardedUnit) return false;
    if (!await _caps.canShowRewarded(
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }
    final earned = await AdWaterfall.instance.showRewarded(trigger: trigger);
    if (earned) {
      await _caps.recordRewardedShown();
    }
    return earned;
  }

  /// LevelPlay rewarded with typed feature enum — returns true when user earns reward.
  Future<bool> showRewardedFeature({required RewardedFeatures feature}) async {
    return showRewarded(trigger: feature.toTrigger());
  }

  /// Watch rewarded → temporary ad-free window.
  Future<bool> showRewardedForAdFree({required String trigger}) async {
    final earned = await showRewarded(trigger: trigger);
    if (!earned) return false;
    final until = DateTime.now().add(
      Duration(minutes: AdConfig.adFreeMinutesAfterRewarded),
    );
    await UserPreferences.setAdFreeUntil(until);
    _caps.setAdFreeUntil(until);
    adLog(
      '[AdManager] rewarded ad-free until $until (${AdConfig.adFreeMinutesAfterRewarded}m)',
    );
    return true;
  }

  Future<bool> onSportsTabSelected({BuildContext? context}) async {
    if (!adsEnabled) return false;
    if (!await _caps.canShowIronSourceInterstitial(
      isStreaming: _isStreaming,
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }

    if (context != null &&
        context.mounted &&
        AdSafetyService.instance.adsterraEnabled) {
      final monetag = await PropellerEngine.instance.showVignetteDialog(
        context,
        placement: 'tab_switch_monetag',
        minSeconds: 5,
      );
      if (monetag) return true;
    }

    return showInterstitial(context: context, trigger: 'tab_switch');
  }

  /// Optional Monetag smartlink before opening external news URL (2nd tap).
  Future<void> maybeMonetizeNewsReadMore() async {
    if (!adsEnabled) return;
    await PropellerEngine.instance.openSmartlink(
      placement: 'news_read_more',
      analytics: analytics,
    );
  }

  /// Exit stack: LevelPlay interstitial first, then Adsterra direct link fallback.
  Future<bool> onExitIntent() async {
    if (!_caps.canShowExitAd(
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }

    var consumed = false;
    if (await _caps.canShowIronSourceInterstitial(
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

  /// LevelPlay → Adsterra waterfall (respects caps when called via gated paths).
  Future<bool> showInterstitial({
    BuildContext? context,
    required String trigger,
  }) async {
    if (!isReady) await init();
    if (!adsEnabled) return false;
    
    // Session pacing: no full-screen ads in first 60 seconds
    if (!SessionPacing.instance.canShowFullScreenAd()) {
      if (kDebugMode) {
        print('[SessionPacing] first minute, skipping full-screen ad');
      }
      return false;
    }
    
    return AdWaterfall.instance.showInterstitial(
      context,
      trigger: trigger,
    );
  }

  int get maxInterstitials =>
      GeoTargeting.adjustedMaxInterstitials(
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
