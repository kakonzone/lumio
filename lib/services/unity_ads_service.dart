import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import '../config/ad_config.dart';
import '../ads/ad_log.dart';
import '../ads/analytics/ad_analytics.dart';
import 'ad_safety_service.dart';

/// Unity Ads — interstitial + rewarded implementation.
class UnityAdsService {
  UnityAdsService._();
  static final UnityAdsService instance = UnityAdsService._();

  AdAnalytics? _analytics;
  String _interstitialTrigger = 'unknown';
  String _rewardedTrigger = 'unknown';

  bool _initialized = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _rewardedEarnedThisShow = false;
  DateTime? _initCompletedAt;
  String? _lastInitError;
  String? _lastLoadError;
  bool _adPodInProgress = false;
  int _currentAdIndex = 0;
  static bool _loggedNetworkErrorOnce = false;

  @visibleForTesting
  static int debugInterstitialLoadCallCount = 0;

  @visibleForTesting
  static void debugResetForTest() {
    debugInterstitialLoadCallCount = 0;
    final s = instance;
    s._interstitialReady = false;
    s._rewardedReady = false;
    s._initialized = false;
  }

  String? get lastInitError => _lastInitError;
  String? get lastLoadError => _lastLoadError;
  DateTime? get initCompletedAt => _initCompletedAt;
  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;
  bool get isAdReady => _rewardedReady;
  bool get isInterstitialLoadInFlight => false;
  bool get isRewardedLoadInFlight => false;

  void attachAnalytics(AdAnalytics a) => _analytics = a;
  void setInterstitialTrigger(String t) => _interstitialTrigger = t;
  void setRewardedTrigger(String t) => _rewardedTrigger = t;

  String get _gameId =>
      Platform.isIOS ? AdConfig.unityGameId : AdConfig.unityGameId;

  String get _interstitialId => Platform.isIOS
      ? AdConfig.unityInterstitialIOS
      : AdConfig.unityInterstitialAndroid;

  String get _rewardedId => Platform.isIOS
      ? AdConfig.unityRewardedIOS
      : AdConfig.unityRewardedAndroid;

  // ── Init ────────────────────────────────────────────────────────────────

  Future<bool> init() async {
    if (_initialized) return true;
    if (AdSafetyService.instance.adsBlockedInDebug) {
      adLog('[Unity] init skipped — ads blocked in debug');
      return false;
    }
    if (!AdConfig.hasUnityConfig) {
      adLog('[Unity] init skipped — UNITY_GAME_ID missing');
      return false;
    }
    try {
      await UnityAds.init(
        gameId: _gameId,
        testMode: AdConfig.unityTestMode,
        onComplete: () {
          _initialized = true;
          _initCompletedAt = DateTime.now();
          adLog('[Unity] initialized gameId=$_gameId');
          unawaited(loadInterstitial());
          unawaited(loadRewarded());
        },
        onFailed: (error, message) {
          _lastInitError = '$error: $message';
          adLog('[Unity] init failed: $error $message');
        },
      );
      return _initialized;
    } catch (e, st) {
      _lastInitError = e.toString();
      adLog('[Unity] init error: $e\n$st');
      return false;
    }
  }

  // ── Interstitial ─────────────────────────────────────────────────────────

  Future<void> loadInterstitial() async {
    if (!_initialized) return;
    try {
      UnityAds.load(
        placementId: _interstitialId,
        onComplete: (id) {
          _interstitialReady = true;
          debugInterstitialLoadCallCount++;
          _loggedNetworkErrorOnce = false; // Reset on success
          adLog('[Unity] interstitial ready: $id');
        },
        onFailed: (id, error, message) {
          _interstitialReady = false;
          _lastLoadError = '$error: $message';
          // Reduce log spam for network errors in debug mode
          if (kDebugMode && 
              (error.toString().contains('Network error') || 
               message.toString().contains('Network error'))) {
            if (!_loggedNetworkErrorOnce) {
              _loggedNetworkErrorOnce = true;
              adLog('[Unity] interstitial load failed: $id $error $message (network error - will not retry in debug)');
            }
          } else {
            adLog('[Unity] interstitial load failed: $id $error $message');
          }
        },
      );
    } catch (e, st) {
      _lastLoadError = e.toString();
      if (kDebugMode && e.toString().contains('Network error')) {
        if (!_loggedNetworkErrorOnce) {
          _loggedNetworkErrorOnce = true;
          adLog('[Unity] interstitial load error: $e (network error - will not retry in debug)');
        }
      } else {
        adLog('[Unity] interstitial load error: $e\n$st');
      }
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
      adLog('[Unity] interstitial not ready');
      return false;
    }

    final completer = Completer<bool>();
    try {
      UnityAds.showVideoAd(
        placementId: _interstitialId,
        onComplete: (id) {
          _interstitialReady = false;
          _analytics?.logAdShown(
            network: 'unity',
            format: 'interstitial',
            placement: _interstitialTrigger,
          );
          adLog('[Unity] interstitial complete: $id');
          unawaited(loadInterstitial());
          if (!completer.isCompleted) completer.complete(true);
        },
        onFailed: (id, error, message) {
          _interstitialReady = false;
          _lastLoadError = '$error: $message';
          adLog('[Unity] interstitial failed: $id $error $message');
          unawaited(loadInterstitial());
          if (!completer.isCompleted) completer.complete(false);
        },
        onSkipped: (id) {
          _interstitialReady = false;
          adLog('[Unity] interstitial skipped: $id');
          unawaited(loadInterstitial());
          if (!completer.isCompleted) completer.complete(true);
        },
        onStart: (id) => adLog('[Unity] interstitial started: $id'),
      );
    } catch (e, st) {
      adLog('[Unity] interstitial show error: $e\n$st');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  // ── Rewarded ─────────────────────────────────────────────────────────────

  Future<void> loadRewarded() async {
    if (!_initialized) return;
    try {
      UnityAds.load(
        placementId: _rewardedId,
        onComplete: (id) {
          _rewardedReady = true;
          _loggedNetworkErrorOnce = false; // Reset on success
          adLog('[Unity] rewarded ready: $id');
        },
        onFailed: (id, error, message) {
          _rewardedReady = false;
          _lastLoadError = '$error: $message';
          // Reduce log spam for network errors in debug mode
          if (kDebugMode && 
              (error.toString().contains('Network error') || 
               message.toString().contains('Network error'))) {
            if (!_loggedNetworkErrorOnce) {
              _loggedNetworkErrorOnce = true;
              adLog('[Unity] rewarded load failed: $id $error $message (network error - will not retry in debug)');
            }
          } else {
            adLog('[Unity] rewarded load failed: $id $error $message');
          }
        },
      );
    } catch (e, st) {
      _lastLoadError = e.toString();
      if (kDebugMode && e.toString().contains('Network error')) {
        if (!_loggedNetworkErrorOnce) {
          _loggedNetworkErrorOnce = true;
          adLog('[Unity] rewarded load error: $e (network error - will not retry in debug)');
        }
      } else {
        adLog('[Unity] rewarded load error: $e\n$st');
      }
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
      adLog('[Unity] rewarded not ready');
      return false;
    }

    _rewardedEarnedThisShow = false;
    final completer = Completer<bool>();
    try {
      UnityAds.showVideoAd(
        placementId: _rewardedId,
        onComplete: (id) {
          _rewardedReady = false;
          _rewardedEarnedThisShow = true;
          _analytics?.logAdShown(
            network: 'unity',
            format: 'rewarded',
            placement: _rewardedTrigger,
          );
          adLog('[Unity] rewarded complete: $id');
          unawaited(loadRewarded());
          if (!completer.isCompleted) completer.complete(true);
        },
        onFailed: (id, error, message) {
          _rewardedReady = false;
          _lastLoadError = '$error: $message';
          adLog('[Unity] rewarded failed: $id $error $message');
          unawaited(loadRewarded());
          if (!completer.isCompleted) completer.complete(false);
        },
        onSkipped: (id) {
          _rewardedReady = false;
          adLog('[Unity] rewarded skipped: $id');
          unawaited(loadRewarded());
          if (!completer.isCompleted) completer.complete(false);
        },
        onStart: (id) => adLog('[Unity] rewarded started: $id'),
      );
    } catch (e, st) {
      adLog('[Unity] rewarded show error: $e\n$st');
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future;
  }

  Future<void> showRewardedAd({
    VoidCallback? onComplete,
    VoidCallback? onSkip,
    Function(String)? onFail,
  }) async {
    if (!_initialized) {
      await init();
      if (!_initialized) {
        onFail?.call('Unity Ads not initialized');
        return;
      }
    }
    if (!_rewardedReady) {
      await loadRewarded();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!_rewardedReady) {
      onFail?.call('Rewarded ad not ready');
      return;
    }

    _rewardedEarnedThisShow = false;
    try {
      UnityAds.showVideoAd(
        placementId: _rewardedId,
        onComplete: (id) {
          _rewardedReady = false;
          _rewardedEarnedThisShow = true;
          unawaited(loadRewarded());
          onComplete?.call();
        },
        onFailed: (id, error, message) {
          _rewardedReady = false;
          unawaited(loadRewarded());
          onFail?.call('$error: $message');
        },
        onSkipped: (id) {
          _rewardedReady = false;
          unawaited(loadRewarded());
          onSkip?.call();
        },
        onStart: (_) {},
      );
    } catch (e, st) {
      adLog('[Unity] showRewardedAd error: $e\n$st');
      onFail?.call(e.toString());
    }
  }

  Future<void> showAdPod({
    required int totalAds,
    required Function(int currentIndex) onAdStart,
    required VoidCallback onPodComplete,
    required Function(String error) onFail,
  }) async {
    if (_adPodInProgress) return;
    _adPodInProgress = true;
    int completedAds = 0;
    try {
      for (int i = 0; i < totalAds; i++) {
        _currentAdIndex = i + 1;
        onAdStart(_currentAdIndex);
        try {
          await showRewardedAd(
            onComplete: () => completedAds++,
            onSkip: () => completedAds++,
            onFail: (_) => completedAds++,
          );
        } catch (_) {
          completedAds++;
        }
      }
      onPodComplete();
    } catch (e) {
      onFail(e.toString());
    } finally {
      _adPodInProgress = false;
      _currentAdIndex = 0;
      unawaited(loadRewarded());
    }
  }

  void setRewardedEarned(bool earned) => _rewardedEarnedThisShow = earned;
  void dispose() {}
}
