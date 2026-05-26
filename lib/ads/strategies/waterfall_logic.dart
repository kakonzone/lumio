import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/ad_config.dart';
import '../ad_log.dart';
import '../../services/ad_safety_service.dart';
import '../adsterra_engine.dart';
import '../analytics/ad_analytics.dart';
import '../ironsource_service.dart';

enum AdNetwork { levelPlay, adsterra, none }

/// LevelPlay primary → Adsterra fallback on no-fill / timeout.
class WaterfallLogic {
  WaterfallLogic({
    required LevelPlayAdService levelPlay,
    required AdAnalytics analytics,
  })  : _levelPlay = levelPlay,
        _analytics = analytics;

  final LevelPlayAdService _levelPlay;
  final AdAnalytics _analytics;

  void _logWaterfallStep({
    required String step,
    required String network,
    required String format,
    required String result,
  }) {
    adLog(
      '[waterfall_step] step=$step network=$network format=$format result=$result',
    );
  }

  Future<bool> showInterstitial() async {
    _logWaterfallStep(
      step: 'primary',
      network: 'levelplay',
      format: 'interstitial',
      result: 'attempt',
    );

    final lpOk = await _tryLevelPlayInterstitial().timeout(
      Duration(milliseconds: AdConfig.waterfallTimeoutMs),
      onTimeout: () {
        _logWaterfallStep(
          step: 'primary',
          network: 'levelplay',
          format: 'interstitial',
          result: 'timeout',
        );
        return false;
      },
    );

    if (lpOk) {
      _logWaterfallStep(
        step: 'primary',
        network: 'levelplay',
        format: 'interstitial',
        result: 'fill',
      );
      return true;
    }

    _logWaterfallStep(
      step: 'primary',
      network: 'levelplay',
      format: 'interstitial',
      result: 'no_fill',
    );

    if (!AdSafetyService.instance.adsterraEnabled) {
      unawaited(_analytics.logNoFill(placement: 'interstitial'));
      return false;
    }

    _logWaterfallStep(
      step: 'fallback',
      network: 'adsterra',
      format: 'direct_link',
      result: 'attempt',
    );

    final adsterraOk = await AdsterraEngine.instance.openDirectLink(
      placement: 'waterfall_interstitial_fallback',
      analytics: _analytics,
    );

    _logWaterfallStep(
      step: 'fallback',
      network: 'adsterra',
      format: 'direct_link',
      result: adsterraOk ? 'fill' : 'no_fill',
    );

    if (adsterraOk) {
      unawaited(
        _analytics.logFill(
          network: 'adsterra',
          placement: 'waterfall_interstitial_fallback',
        ),
      );
      return true;
    }

    unawaited(_analytics.logNoFill(placement: 'interstitial'));
    return false;
  }

  Future<bool> _tryLevelPlayInterstitial() async {
    if (!_levelPlay.isInterstitialReady) {
      final ready = await _levelPlay.ensureInterstitialReady();
      if (!ready) return false;
    }

    final ok = await _levelPlay.showInterstitial();
    if (ok) {
      unawaited(
        _analytics.logFill(network: 'levelplay', placement: 'interstitial'),
      );
    }
    return ok;
  }

  Future<bool> showRewarded() async {
    _logWaterfallStep(
      step: 'primary',
      network: 'levelplay',
      format: 'rewarded',
      result: 'attempt',
    );

    if (!_levelPlay.isRewardedReady) {
      final ready = await _levelPlay.ensureRewardedReady();
      if (!ready) {
        _logWaterfallStep(
          step: 'primary',
          network: 'levelplay',
          format: 'rewarded',
          result: 'no_fill',
        );
        unawaited(_analytics.logNoFill(placement: 'rewarded'));
        return false;
      }
    }

    final ok = await _levelPlay.showRewarded().timeout(
      Duration(milliseconds: AdConfig.waterfallTimeoutMs),
      onTimeout: () {
        _logWaterfallStep(
          step: 'primary',
          network: 'levelplay',
          format: 'rewarded',
          result: 'timeout',
        );
        return false;
      },
    );

    if (ok) {
      _logWaterfallStep(
        step: 'primary',
        network: 'levelplay',
        format: 'rewarded',
        result: 'fill',
      );
      unawaited(
        _analytics.logFill(network: 'levelplay', placement: 'rewarded'),
      );
      return true;
    }

    _logWaterfallStep(
      step: 'primary',
      network: 'levelplay',
      format: 'rewarded',
      result: 'no_fill',
    );
    unawaited(_analytics.logNoFill(placement: 'rewarded'));
    return false;
  }

  void preloadAll() {
    _levelPlay.loadInterstitial();
    _levelPlay.loadRewarded();
  }
}
