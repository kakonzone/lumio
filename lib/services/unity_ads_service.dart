import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../config/ad_config.dart';
import '../ads/ad_log.dart';
import '../ads/analytics/ad_analytics.dart';
import 'ad_consent_service.dart';
import 'ad_safety_service.dart';
import 'ad_trigger_manager.dart';

/// Unity Ads interstitial + rewarded implementation.
class UnityAdsService {
  UnityAdsService._();
  static final UnityAdsService instance = UnityAdsService._();

  AdAnalytics? _analytics;
  String _interstitialTrigger = 'unknown';

  bool _initialized = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _rewardedEarnedThisShow = false;
  String _rewardedTrigger = 'unknown';
  DateTime? _initCompletedAt;
  String? _lastInitError;
  String? _lastLoadError;

  int _interstitialNoFillStreak = 0;
  DateTime? _interstitialLoadBlockedUntil;

  // Ad pod state
  bool _adPodInProgress = false;
  int _currentAdIndex = 0;
  DateTime? _adStartTime;

  @visibleForTesting
  static int debugInterstitialLoadCallCount = 0;

  @visibleForTesting
  static void debugResetForTest() {
    debugInterstitialLoadCallCount = 0;
    final s = instance;
    s._interstitialReady = false;
    s._rewardedReady = false;
    s._initialized = false;
    s._interstitialNoFillStreak = 0;
    s._interstitialLoadBlockedUntil = null;
  }

  String? get lastInitError => _lastInitError;
  String? get lastLoadError => _lastLoadError;
  DateTime? get initCompletedAt => _initCompletedAt;

  void attachAnalytics(AdAnalytics analytics) => _analytics = analytics;

  void setInterstitialTrigger(String trigger) => _interstitialTrigger = trigger;

  void setRewardedTrigger(String trigger) => _rewardedTrigger = trigger;

  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;
  bool get isInterstitialLoadInFlight => false;
  bool get isRewardedLoadInFlight => false;

  Future<bool> init() async {
    if (_initialized) return true;
    if (AdSafetyService.instance.adsBlockedInDebug) {
      adLog('[UnityAds] init skipped — pass --dart-define=ADS_ENABLED=true');
      return false;
    }
    if (!AdConfig.hasUnityConfig) {
      adLog(
        '[UnityAds] init skipped — UNITY_* missing in ci_defines.json',
      );
      return false;
    }

    try {
      final initialized = await UnityAds.init(
        gameId: AdConfig.unityGameId,
        testMode: !kReleaseMode,
        onComplete: () {
          _initialized = true;
          _initCompletedAt = DateTime.now();
          adLog('[UnityAds] initialized successfully with Game ID: ${AdConfig.unityGameId}');
        },
        onFailed: (error) {
          _lastInitError = error.toString();
          adLog('[UnityAds] init failed: $error');
        },
      );
      return initialized;
    } catch (e, st) {
      _lastInitError = e.toString();
      adLog('[UnityAds] init error: $e\n$st');
      return false;
    }
  }

  Future<void> loadInterstitial() async {
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    if (_interstitialLoadBlockedUntil != null &&
        DateTime.now().isBefore(_interstitialLoadBlockedUntil!)) {
      return;
    }

    try {
      final loaded = await UnityAds.load(
        placementId: AdConfig.unityInterstitial,
      );
      
      if (loaded) {
        _interstitialReady = true;
        _interstitialNoFillStreak = 0;
        adLog('[UnityAds] interstitial loaded successfully');
        _analytics?.logAdLoaded(
          network: 'unity',
          format: 'interstitial',
          placement: _interstitialTrigger,
        );
      } else {
        _interstitialReady = false;
        _interstitialNoFillStreak++;
        _lastLoadError = 'Load failed';
        adLog('[UnityAds] interstitial load failed (no fill)');
        _analytics?.logAdFailed(
          network: 'unity',
          format: 'interstitial',
          placement: _interstitialTrigger,
          error: 'no_fill',
        );
        
        // Backoff on repeated failures
        if (_interstitialNoFillStreak >= 3) {
          _interstitialLoadBlockedUntil = DateTime.now().add(const Duration(minutes: 5));
          adLog('[UnityAds] interstitial load blocked for 5 minutes due to repeated failures');
        }
      }
    } catch (e, st) {
      _lastLoadError = e.toString();
      adLog('[UnityAds] interstitial load error: $e\n$st');
      _analytics?.logAdFailed(
        network: 'unity',
        format: 'interstitial',
        placement: _interstitialTrigger,
        error: e.toString(),
      );
    }
  }

  Future<bool> showInterstitial() async {
    if (!_initialized) {
      await init();
      if (!_initialized) return false;
    }

    if (!_interstitialReady) {
      await loadInterstitial();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_interstitialReady) {
      adLog('[UnityAds] showInterstitial called but ad not ready');
      return false;
    }

    try {
      final shown = await UnityAds.show(
        placementId: AdConfig.unityInterstitial,
      );
      
      if (shown) {
        _analytics?.logAdShown(
          network: 'unity',
          format: 'interstitial',
          placement: _interstitialTrigger,
        );
        adLog('[UnityAds] interstitial shown for $_interstitialTrigger');
        
        // Reload for next show
        _interstitialReady = false;
        unawaited(loadInterstitial());
        
        return true;
      }
      
      adLog('[UnityAds] interstitial show failed');
      return false;
    } catch (e, st) {
      adLog('[UnityAds] interstitial show error: $e\n$st');
      return false;
    }
  }

  Future<void> loadRewarded() async {
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    try {
      final loaded = await UnityAds.load(
        placementId: AdConfig.unityRewarded,
      );
      
      if (loaded) {
        _rewardedReady = true;
        adLog('[UnityAds] rewarded ad loaded successfully');
        _analytics?.logAdLoaded(
          network: 'unity',
          format: 'rewarded',
          placement: _rewardedTrigger,
        );
      } else {
        _rewardedReady = false;
        _lastLoadError = 'Rewarded load failed';
        adLog('[UnityAds] rewarded ad load failed');
        _analytics?.logAdFailed(
          network: 'unity',
          format: 'rewarded',
          placement: _rewardedTrigger,
          error: 'no_fill',
        );
      }
    } catch (e, st) {
      _lastLoadError = e.toString();
      adLog('[UnityAds] rewarded load error: $e\n$st');
      _analytics?.logAdFailed(
        network: 'unity',
        format: 'rewarded',
        placement: _rewardedTrigger,
        error: e.toString(),
      );
    }
  }

  Future<bool> showRewarded() async {
    if (!_initialized) {
      await init();
      if (!_initialized) return false;
    }

    if (!_rewardedReady) {
      await loadRewarded();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_rewardedReady) {
      adLog('[UnityAds] showRewarded called but ad not ready');
      return false;
    }

    try {
      final shown = await UnityAds.show(
        placementId: AdConfig.unityRewarded,
      );
      
      if (shown) {
        _analytics?.logAdShown(
          network: 'unity',
          format: 'rewarded',
          placement: _rewardedTrigger,
        );
        adLog('[UnityAds] rewarded ad shown for $_rewardedTrigger');
        
        // Reload for next show
        _rewardedReady = false;
        unawaited(loadRewarded());
        
        return _rewardedEarnedThisShow;
      }
      
      adLog('[UnityAds] rewarded ad show failed');
      return false;
    } catch (e, st) {
      adLog('[UnityAds] rewarded show error: $e\n$st');
      return false;
    }
  }

  void setRewardedEarned(bool earned) {
    _rewardedEarnedThisShow = earned;
    if (earned) {
      _analytics?.logRewardEarned(
        network: 'unity',
        placement: _rewardedTrigger,
      );
      adLog('[UnityAds] reward earned for $_rewardedTrigger');
    }
  }

  // ── Ad Pod Functionality ───────────────────────────────────────────────────

  /// Check if an ad is ready to show
  bool get isAdReady => _rewardedReady;

  /// Preload the next rewarded ad in background
  Future<void> _preloadNext() async {
    if (!_initialized) return;
    adLog('[UnityAds] Preloading next rewarded ad');
    await loadRewarded();
  }

  /// Show a single rewarded ad with callbacks
  Future<void> showRewardedAd({
    VoidCallback? onComplete,
    VoidCallback? onSkip,
    Function(String)? onFail,
  }) async {
    if (!_initialized) {
      await init();
      if (!_initialized) {
        onFail?.('Unity Ads not initialized');
        return;
      }
    }

    if (!_rewardedReady) {
      await loadRewarded();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!_rewardedReady) {
      adLog('[UnityAds] Rewarded ad not ready');
      onFail?.('Ad not ready');
      return;
    }

    _adStartTime = DateTime.now();
    try {
      final shown = await UnityAds.show(
        placementId: AdConfig.unityRewardedPlacement,
      );

      if (shown) {
        _analytics?.logAdShown(
          network: 'unity',
          format: 'rewarded',
          placement: _rewardedTrigger,
        );
        adLog('[UnityAds] Rewarded ad shown');

        final duration = _adStartTime != null
            ? DateTime.now().difference(_adStartTime!).inSeconds
            : 0;

        _analytics?.logAdCompleted(
          network: 'unity',
          format: 'rewarded',
          placement: _rewardedTrigger,
          duration: duration,
        );

        onComplete?.();
      } else {
        adLog('[UnityAds] Rewarded ad show failed');
        onFail?.('Show failed');
      }
    } catch (e, st) {
      adLog('[UnityAds] Rewarded ad show error: $e\n$st');
      onFail?.(e.toString());
    } finally {
      // Reload for next show
      _rewardedReady = false;
      unawaited(loadRewarded());
    }
  }

  /// Show an ad pod (multiple ads in sequence)
  Future<void> showAdPod({
    required int totalAds,
    required Function(int currentIndex) onAdStart,
    required VoidCallback onPodComplete,
    required Function(String error) onFail,
  }) async {
    if (_adPodInProgress) {
      adLog('[UnityAds] Ad pod already in progress');
      return;
    }

    _adPodInProgress = true;
    int completedAds = 0;

    try {
      _analytics?.logEvent('unity_ad_pod_started', {
        'pod_size': totalAds,
      });

      for (int i = 0; i < totalAds; i++) {
        _currentAdIndex = i + 1;
        onAdStart(_currentAdIndex);

        _analytics?.logEvent('unity_ad_index', {
          'current': _currentAdIndex,
          'total': totalAds,
        });

        // Preload next ad while current is playing (except for last ad)
        if (i < totalAds - 1) {
          unawaited(_preloadNext());
        }

        try {
          await showRewardedAd(
            onComplete: () {
              completedAds++;
              adLog('[UnityAds] Ad $_currentAdIndex of $totalAds completed');
            },
            onSkip: () {
              completedAds++;
              adLog('[UnityAds] Ad $_currentAdIndex of $totalAds skipped');
            },
            onFail: (error) {
              adLog('[UnityAds] Ad $_currentAdIndex of $totalAds failed: $error');
              // Continue to next ad even if current fails (silent skip)
              completedAds++;
            },
          );
        } catch (e) {
          adLog('[UnityAds] Ad $_currentAdIndex error, skipping: $e');
          completedAds++; // Count as completed to continue pod
        }
      }

      if (completedAds == totalAds) {
        _analytics?.logEvent('unity_ad_pod_completed');
      } else if (completedAds > 0) {
        _analytics?.logEvent('unity_ad_pod_partial', {
          'completed_count': completedAds,
          'total_count': totalAds,
        });
      }

      onPodComplete();
    } catch (e) {
      adLog('[UnityAds] Ad pod error: $e');
      _analytics?.logEvent('unity_ad_failed', {
        'error_code': e.toString(),
      });
      onFail(e.toString());
    } finally {
      _adPodInProgress = false;
      _currentAdIndex = 0;
      // Preload for next pod
      unawaited(_preloadNext());
    }
  }

  void dispose() {
    // Unity Ads doesn't need explicit dispose
  }
}