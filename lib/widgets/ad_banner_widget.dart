import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../ads/ad_manager.dart';
import '../config/ad_config.dart';
import '../services/ad_safety_service.dart';

/// LevelPlay banner — HOME bottom anchor.
///
/// Auto-refresh interval: configure [AdConfig.levelPlayBannerDashboardRefreshSeconds]
/// in the LevelPlay dashboard for [AdConfig.bannerAdUnitId] — not settable from Dart
/// (only `pauseAutoRefresh` / `resumeAutoRefresh` in 9.2.0).
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({
    super.key,
    this.placementName = 'home_bottom',
  });

  final String placementName;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with WidgetsBindingObserver {
  final _bannerKey = GlobalKey<LevelPlayBannerAdViewState>();

  late final LevelPlayBannerAdView _banner = LevelPlayBannerAdView(
    key: _bannerKey,
    adUnitId: AdConfig.bannerAdUnitId,
    adSize: LevelPlayAdSize.BANNER,
    placementName: widget.placementName,
    listener: _BannerListener(widget.placementName),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!AdSafetyService.instance.adsBlockedInDebug) {
        debugPrint('[LevelPlay] banner loading...');
        _banner.loadAd();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _banner.destroy();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final banner = _bannerKey.currentState;
    if (banner == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // TODO(verify): API surface inferred, not confirmed against 9.2.0 changelog
        unawaited(banner.pauseAutoRefresh());
      case AppLifecycleState.resumed:
        // TODO(verify): API surface inferred, not confirmed against 9.2.0 changelog
        unawaited(banner.resumeAutoRefresh());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AdSafetyService.instance.adsBlockedInDebug) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: _banner,
    );
  }
}

class _BannerListener with LevelPlayBannerAdViewListener {
  _BannerListener(this.placement);
  final String placement;

  static bool _loggedDashboardHint = false;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] banner loaded');
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('[LevelPlay] banner load FAILED: $error');
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] banner displayed');
    if (!_loggedDashboardHint) {
      _loggedDashboardHint = true;
      if (kDebugMode) {
        debugPrint(
          '[LevelPlay] banner dashboard auto-refresh target='
          '${AdConfig.levelPlayBannerDashboardRefreshSeconds}s '
          'unit=${AdConfig.bannerAdUnitId} (LevelPlay dashboard only)',
        );
      }
    }
    unawaited(
      AdManager.instance.analytics.logBannerImpression(placement: placement),
    );
  }

  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {
    debugPrint('[LevelPlay] banner display FAILED: $error');
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] banner clicked');
    unawaited(
      AdManager.instance.analytics.logClick(
        network: 'levelplay',
        format: 'banner',
        placement: placement,
      ),
    );
  }

  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}

  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}

  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
