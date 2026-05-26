import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/ad_config.dart';
import 'ad_log.dart';
import '../models/model.dart';
import '../services/ad_safety_service.dart';
import '../services/ad_trigger_manager.dart';
import '../services/user_preferences.dart';
import '../utils/channel_tap_key.dart';
import '../utils/ad_debug_log.dart';
import 'adsterra_engine.dart';
import 'adsterra_telemetry_client.dart';
import 'analytics/ad_analytics.dart';
import 'ironsource_service.dart';
import '../services/server_cap.dart';
import 'server_cap_client.dart';
import 'ad_placement_config.dart';
import 'strategies/geo_targeting.dart';
import 'strategies/waterfall_logic.dart';

/// Global ad orchestration — singleton.
class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  final AdAnalytics analytics = AdAnalytics();
  final _caps = AdTriggerManager.instance;
  late final WaterfallLogic _waterfall = WaterfallLogic(
    levelPlay: LevelPlayAdService.instance,
    analytics: analytics,
  );

  bool _initialized = false;
  bool _isStreaming = false;
  bool _preloadDone = false;

  /// True when ad orchestration finished init (LevelPlay and/or Adsterra config).
  bool get isReady => _initialized && AdConfig.hasMonetizationConfig;

  bool get levelPlayReady => LevelPlayAdService.instance.isInitialized;

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
    AdsterraTelemetryService.instance.logConfigurationOnce();
    AdPlacementConfig.logPlacementSummaryOnce();
    ServerCapService.instance.attachAnalytics(analytics);
    await _caps.startSession();
    await analytics.init();
    await analytics.logAppOpen();
    await UserPreferences.grantDailyLoginBonus();

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
      return;
    }

    if (!AdConfig.hasMonetizationConfig) {
      _initialized = false;
      AdDebugLog.error(
        'AdManager.init',
        'monetization config incomplete',
        data: {
          'levelPlayKey': AdConfig.hasLevelPlayAppKey,
          'levelPlayUnits': AdConfig.hasLevelPlayAdUnits,
          'adsterraDirect': AdConfig.hasAdsterraDirectLink,
          'adsterraWebView': AdConfig.hasAdsterraWebViewZones,
        },
      );
      return;
    }

    var lpOk = false;
    if (AdConfig.hasLevelPlayAppKey && AdConfig.hasLevelPlayAdUnits) {
      LevelPlayAdService.instance.attachAnalytics(analytics);
      lpOk = await LevelPlayAdService.instance.init();
    }

    final adsterraOk =
        AdConfig.hasAdsterraDirectLink || AdConfig.hasAdsterraWebViewZones;

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
      return;
    }

    _initialized = true;
    adLog(
      '[AdManager] init OK levelplay=$lpOk adsterra=$adsterraOk '
      'aggressive_mode=${AdSafetyService.instance.aggressiveMode}',
    );
    if (lpOk) _waterfall.preloadAll();
  }

  /// Splash: preload only — no visible ads.
  Future<void> preloadFromSplash() async {
    if (_preloadDone) return;
    await init();
    _waterfall.preloadAll();
    _preloadDone = true;
  }

  void setStreaming(bool active) => _isStreaming = active;

  /// Eligibility probe only — WebView mount + cap record happen in [AdsterraPopunderHost].
  Future<void> maybeShowPopunder() async {
    if (!adsEnabled) return;
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

  /// Cold-start substitute: interstitial on splash — **not** a native App Open ad (see ADS_README).
  Future<bool> showColdStartAppOpen() async {
    if (!levelPlayAdsEnabled) return false;
    return LevelPlayAdService.instance.showAppOpenSubstitute(
      removeAds: UserPreferences.removeAdsPurchased,
    );
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

  /// Channel tap: 1st tap → random direct link in browser; 2nd tap → play.
  Future<ChannelTapResult> handleChannelTap({
    required ChannelModel channel,
    required Future<void> Function() onPlay,
    BuildContext? context,
    bool skipInterstitial = false,
  }) async {
    if (!isReady) await init();
    await UserPreferences.ensureInit();
    final key = channelTapKey(channel);

    final showBrowserFirst = adsEnabled &&
        !AdTriggerManager.instance.hasChannelTapBrowserShown(key);

    if (showBrowserFirst) {
      final browserOk = await AdsterraEngine.instance.openChannelTapBrowser(
        placement: 'channel_tap_first',
        analytics: analytics,
        channelIdForFirstClick: key,
      );
      if (kDebugMode) {
        final safety = AdSafetyService.instance;
        debugPrint(
          '[ChannelTap] first tap key=$key browser=$browserOk '
          'adsEnabled=$adsEnabled adsterraSurfacing=${safety.adsterraEnabled} '
          'preferCleanSdk=${safety.preferCleanSdkRouting}',
        );
      }
      if (browserOk) {
        AdTriggerManager.instance.markChannelTapBrowserShown(key);
        logAdsterraTelemetry(
          placement: 'channel_tap_first',
          format: 'direct_link_browser',
        );
      }
      return const ChannelTapResult(
        played: false,
        showTapAgainHint: true,
      );
    }

    _caps.recordChannelClick();
    unawaited(
      analytics.logChannelClick(count: _caps.sessionChannelClicks),
    );

    // Same channel 2nd tap this session → play without extra interstitial.
    final directPlay = AdTriggerManager.instance.hasChannelTapBrowserShown(key);
    final canInter = !skipInterstitial &&
        !directPlay &&
        adsEnabled &&
        await _caps.canShowIronSourceInterstitial(
          isStreaming: _isStreaming,
          removeAds: UserPreferences.removeAdsPurchased,
        );
    if (canInter) {
      LevelPlayAdService.instance.setInterstitialTrigger('channel_tap');
      await _showCleanInterstitial();
    }

    await onPlay();
    return const ChannelTapResult(played: true);
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

  bool canShowPlayerVideoAd({bool isMidRoll = false}) {
    if (!adsEnabled) return false;
    return _caps.canShowPlayerVideoAd(
      removeAds: UserPreferences.removeAdsPurchased,
      isMidRoll: isMidRoll,
    );
  }

  void recordPlayerVideoAdShown() {
    _caps.recordPlayerVideoAdShown();
    _caps.recordAdsterraSurfaceEvent();
    logAdsterraTelemetry(
      placement: 'player_video',
      format: 'video_overlay',
    );
  }

  Future<bool> showPreRollInterstitial() async {
    if (!adsEnabled || _isStreaming) return false;
    if (!await _caps.canShowIronSourceInterstitial(
      isStreaming: false,
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }
    LevelPlayAdService.instance.setInterstitialTrigger('pre_roll');
    return _showCleanInterstitial();
  }

  Future<bool> onSportsTabSelected() async {
    if (!adsEnabled) return false;
    if (!await _caps.canShowIronSourceInterstitial(
      isStreaming: _isStreaming,
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return false;
    }
    LevelPlayAdService.instance.setInterstitialTrigger('tab_switch');
    return _showCleanInterstitial();
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
      LevelPlayAdService.instance.setInterstitialTrigger('back_exit');
      consumed = await _showCleanInterstitial();
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

  Future<bool> _showCleanInterstitial() async {
    return _waterfall.showInterstitial();
  }

  /// Preload rewarded while user is on player (optional).
  Future<void> preloadRewarded() async {
    if (!isReady) await init();
    if (!LevelPlayAdService.instance.isInitialized) return;
    if (LevelPlayAdService.instance.isRewardedReady) return;
    if (LevelPlayAdService.instance.isRewardedLoadInFlight) return;
    LevelPlayAdService.instance.loadRewarded();
  }

  /// Rewarded: HD unlock, VIP ad-free, coins.
  Future<RewardResult> showRewarded({
    required String trigger,
  }) async {
    if (!isReady) await init();
    if (!await _caps.canShowRewarded(
      removeAds: UserPreferences.removeAdsPurchased,
    )) {
      return RewardResult.failed;
    }
    if (!LevelPlayAdService.instance.isInitialized) {
      adLog('[AdManager] showRewarded skipped — LevelPlay not initialized');
      return RewardResult.failed;
    }
    LevelPlayAdService.instance.setRewardedPlacement(trigger);
    final ok = await _waterfall.showRewarded();

    switch (trigger) {
      case 'hd':
        if (ok) {
          await UserPreferences.grantHdUnlock();
        } else {
          adLog(
            '[AdManager] HD quality without rewarded fill — upgrading stream',
          );
        }
        return RewardResult.hdUnlocked;
      case 'vip':
        if (!ok) return RewardResult.failed;
        await UserPreferences.grantVipAdFree();
        _caps.setAdFreeUntil(UserPreferences.adFreeUntil);
        return RewardResult.vipActivated;
      case 'coins':
      default:
        if (!ok) return RewardResult.failed;
        await UserPreferences.addCoins(AdConfig.coinsPerRewardedAd);
        return RewardResult.coinsGranted;
    }
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

enum RewardResult {
  failed,
  hdUnlocked,
  vipActivated,
  coinsGranted,
}
