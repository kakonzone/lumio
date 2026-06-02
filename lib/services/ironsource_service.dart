import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/ad_config.dart';
import '../ads/ad_log.dart';
import '../ads/analytics/ad_analytics.dart';
import 'ad_consent_service.dart';
import 'ad_health_monitor.dart';
import 'ad_safety_service.dart';
import 'ad_trigger_manager.dart';

/// LevelPlay (IronSource) interstitial + banner. Unity Ads via dashboard mediation.
class LevelPlayAdService implements LevelPlayInitListener {
  LevelPlayAdService._();
  static final LevelPlayAdService instance = LevelPlayAdService._();

  AdAnalytics? _analytics;
  String _interstitialTrigger = 'unknown';

  bool _initialized = false;
  bool _interstitialReady = false;
  bool _interstitialLoadInFlight = false;
  bool _rewardedReady = false;
  bool _rewardedLoadInFlight = false;
  bool _rewardedEarnedThisShow = false;
  String _rewardedTrigger = 'unknown';
  DateTime? _initCompletedAt;
  String? _lastInitError;
  LevelPlayAdError? _lastLoadError;

  int _interstitialNoFillStreak = 0;
  DateTime? _interstitialLoadBlockedUntil;

  @visibleForTesting
  static int debugInterstitialLoadCallCount = 0;

  @visibleForTesting
  static Future<void> Function()? testInterstitialLoadInvoker;

  @visibleForTesting
  static void debugResetForTest() {
    debugInterstitialLoadCallCount = 0;
    testInterstitialLoadInvoker = null;
    final s = instance;
    s._interstitialLoadInFlight = false;
    s._interstitialLoadBlockedUntil = null;
    s._initialized = false;
  }

  bool get isInterstitialLoadInFlight => _interstitialLoadInFlight;
  String? get lastInitError => _lastInitError;
  LevelPlayAdError? get lastLoadError => _lastLoadError;
  DateTime? get initCompletedAt => _initCompletedAt;

  Completer<bool>? _interstitialCloseCompleter;
  bool _interstitialDisplayedThisShow = false;
  bool _pendingRecordAsAppOpen = false;
  bool _capRecordedThisShow = false;
  Completer<bool>? _interstitialLoadWaiter;
  Completer<bool>? _rewardedLoadWaiter;
  Completer<bool>? _rewardedCloseCompleter;
  Completer<bool>? _initCompleter;

  late final LevelPlayInterstitialAd _interstitial = LevelPlayInterstitialAd(
    adUnitId: AdConfig.interstitialAdUnitId,
  );
  LevelPlayRewardedAd? _rewarded;

  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;
  bool get isRewardedLoadInFlight => _rewardedLoadInFlight;

  void attachAnalytics(AdAnalytics analytics) => _analytics = analytics;

  void setInterstitialTrigger(String trigger) => _interstitialTrigger = trigger;

  void setRewardedTrigger(String trigger) => _rewardedTrigger = trigger;

  static const _initTimeout = Duration(seconds: 8);
  static const _retryBackoff = Duration(seconds: 2);

  Future<bool> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (_initialized) return true;
    if (AdSafetyService.instance.adsBlockedInDebug) {
      adLog('[LevelPlay] init skipped — pass --dart-define=ADS_ENABLED=true');
      return false;
    }
    if (!AdConfig.hasValidLevelPlayAppKey) {
      adLog(
        '[LevelPlay] init skipped — LEVELPLAY_* missing or still template text in secrets.json',
      );
      return false;
    }
    if (!AdConfig.hasValidLevelPlayAdUnits) {
      adLog(
        '[LevelPlay] init skipped — LEVELPLAY_*_AD_UNIT dart-defines missing',
      );
      return false;
    }

    await AdConsentService.instance.load();
    if (AdConsentService.instance.needsConsentPrompt) {
      adLog('[LevelPlay] init blocked — consent not resolved');
      return false;
    }

    await AdSafetyService.instance.ensureReady();
    if (!AdSafetyService.instance.levelPlayEnabledRemote) {
      adLog('[LevelPlay] init skipped — Remote Config levelplay_enabled=false');
      return false;
    }
    final userId = AdSafetyService.instance.deviceFingerprint;

    try {
      await LevelPlay.setDynamicUserId(userId);
      debugPrint('[LevelPlay] setDynamicUserId before init');
      adLog('[LevelPlay] setDynamicUserId($userId) before init');
    } catch (e) {
      adLog('[LevelPlay] setDynamicUserId failed: $e');
    }

    await AdConsentService.instance.applyToLevelPlaySdk();

    _interstitial.setListener(_InterstitialBridge(this));
    if (AdConfig.hasLevelPlayRewardedUnit) {
      _rewarded = LevelPlayRewardedAd(adUnitId: AdConfig.rewardedAdUnitId);
      _rewarded!.setListener(_RewardedBridge(this));
    }

    final request = LevelPlayInitRequest.builder(AdConfig.levelPlayAppKey)
        .withUserId(userId)
        .build();

    var ok = await _attemptInit(request, attempt: 1);
    if (!ok) {
      await Future<void>.delayed(_retryBackoff);
      ok = await _attemptInit(request, attempt: 2);
    }

    if (ok && _initialized) {
      loadInterstitial();
      loadRewarded();
    }
    return ok;
  }

  Future<bool> _attemptInit(LevelPlayInitRequest request, {required int attempt}) async {
    _initialized = false;
    _initCompleter = Completer<bool>();
    try {
      await LevelPlay.init(initRequest: request, initListener: this);
      final ok = await _initCompleter!.future.timeout(
        _initTimeout,
        onTimeout: () {
          _logInitFailed('timeout', attempt: attempt);
          if (!(_initCompleter?.isCompleted ?? true)) {
            _initCompleter?.complete(false);
          }
          return false;
        },
      );
      return ok && _initialized;
    } catch (e) {
      _logInitFailed('exception:$e', attempt: attempt);
      return false;
    }
  }

  void _logInitFailed(String reason, {required int attempt}) {
    adLog('[LevelPlay] init_failed reason=$reason attempt=$attempt');
  }

  /// Resets no-fill backoff when app returns to foreground.
  void onAppForeground() {
    _interstitialNoFillStreak = 0;
    _interstitialLoadBlockedUntil = null;
    _rewardedLoadInFlight = false;
    adLog('[LevelPlay] backoff reset — app foreground');
  }

  @visibleForTesting
  void debugSetInitializedForTest(bool value) => _initialized = value;

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    _initialized = true;
    _initCompletedAt = DateTime.now();
    _lastInitError = null;
    adLog('[LevelPlay] init success');
    if (!(_initCompleter?.isCompleted ?? true)) {
      _initCompleter?.complete(true);
    }
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    final code = error.errorCode;
    _lastInitError = '${error.errorMessage} (code=$code)';
    adLog(
      '[LevelPlay] init_failed reason=sdk:$code:${error.errorMessage}',
    );
    if (!(_initCompleter?.isCompleted ?? true)) {
      _initCompleter?.complete(false);
    }
  }

  static const _noFillCode = 509;
  static const _backoffSteps = [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 300),
  ];

  void loadInterstitial() {
    if (!_initialized) return;
    final blocked = _interstitialLoadBlockedUntil;
    if (blocked != null && DateTime.now().isBefore(blocked)) {
      adLog('[LevelPlay] interstitial load skipped — backoff until $blocked');
      return;
    }
    if (_interstitialLoadInFlight) {
      adLog('[LevelPlay] interstitial load skipped — already in flight');
      return;
    }
    _interstitialLoadInFlight = true;
    debugPrint('[LevelPlay] interstitial loading...');
    unawaited(() async {
      try {
        await _invokeInterstitialLoad();
      } catch (e) {
        adLog('[LevelPlay] interstitial loadAd exception: $e');
        _interstitialLoadInFlight = false;
      }
    }());
    _emitFillAttempt(format: 'interstitial', result: 'loading', errorCode: null);
  }

  Future<void> _invokeInterstitialLoad() async {
    debugInterstitialLoadCallCount++;
    final invoker = testInterstitialLoadInvoker ?? () => _interstitial.loadAd();
    await invoker();
  }

  Duration _backoffForStreak(int streak) {
    if (streak <= 0) return Duration.zero;
    final idx = (streak - 1).clamp(0, _backoffSteps.length - 1);
    return _backoffSteps[idx];
  }

  void _scheduleNoFillBackoff(int streak) {
    final delay = _backoffForStreak(streak);
    if (delay <= Duration.zero) return;
    _interstitialLoadBlockedUntil = DateTime.now().add(delay);
    adLog(
      '[LevelPlay] interstitial no-fill backoff ${delay.inSeconds}s '
      '(streak=$streak)',
    );
  }

  void _resetNoFillBackoff() {
    _interstitialNoFillStreak = 0;
    _interstitialLoadBlockedUntil = null;
  }

  int _msSinceInit() {
    final t = _initCompletedAt;
    if (t == null) return 0;
    return DateTime.now().difference(t).inMilliseconds;
  }

  void _emitFillAttempt({
    required String format,
    required String result,
    int? errorCode,
    int? attemptN,
  }) {
    AdHealthMonitor.instance.recordAttempt(
      format: format,
      result: result,
      errorCode: errorCode,
    );
    final a = _analytics;
    if (a == null) return;
    unawaited(
      a.logLevelPlayFillAttempt(
        format: format,
        result: result,
        errorCode: errorCode,
        attemptN: attemptN,
        msSinceInit: _msSinceInit(),
      ),
    );
  }

  void _onLoadFailed(LevelPlayAdError error) {
    _lastLoadError = error;
    final code = error.errorCode;
    if (code == _noFillCode) {
      _interstitialNoFillStreak++;
      _scheduleNoFillBackoff(_interstitialNoFillStreak);
      _emitFillAttempt(
        format: 'interstitial',
        result: 'no_fill',
        errorCode: code,
        attemptN: _interstitialNoFillStreak,
      );
    } else {
      _emitFillAttempt(
        format: 'interstitial',
        result: 'error',
        errorCode: code,
      );
    }
  }

  void _onLoadSuccess() {
    _resetNoFillBackoff();
    _emitFillAttempt(format: 'interstitial', result: 'filled', errorCode: null);
  }

  Future<bool> ensureInterstitialReady({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_interstitialReady) return true;
    if (!_initialized) {
      final ok = await init();
      if (!ok || !_initialized) return false;
    }
    final waiter = Completer<bool>();
    _interstitialLoadWaiter = waiter;
    loadInterstitial();
    try {
      return await waiter.future.timeout(
        timeout,
        onTimeout: () => _interstitialReady,
      );
    } finally {
      if (identical(_interstitialLoadWaiter, waiter)) {
        _interstitialLoadWaiter = null;
      }
    }
  }

  /// Cold-start "app open" — interstitial substitute (no native App Open API).
  Future<bool> showAppOpenSubstitute({required bool removeAds}) async {
    if (!await AdTriggerManager.instance
        .canShowAppOpenSubstitute(removeAds: removeAds)) {
      return false;
    }
    setInterstitialTrigger('app_open_substitute');
    return showInterstitial(
      bypassHourlyGate: true,
      recordAsAppOpen: true,
    );
  }

  Future<bool> showInterstitial({
    bool bypassHourlyGate = false,
    bool recordAsAppOpen = false,
  }) async {
    if (!_initialized) return false;
    if (!bypassHourlyGate) {
      await Future<void>.delayed(
        AdTriggerManager.instance.interstitialNaturalDelay,
      );
    }
    if (!_interstitialReady) {
      final ready = await ensureInterstitialReady();
      if (!ready) return false;
    }
    _interstitialDisplayedThisShow = false;
    _capRecordedThisShow = false;
    _pendingRecordAsAppOpen = recordAsAppOpen;
    _interstitialCloseCompleter = Completer<bool>();
    AdTriggerManager.instance.recordInterstitialAttempted();
    try {
      debugPrint('[LevelPlay] interstitial show called');
      await _interstitial.showAd();
      await _interstitialCloseCompleter!.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          _logCapTimeoutNoShow();
          if (!(_interstitialCloseCompleter?.isCompleted ?? true)) {
            _interstitialCloseCompleter?.complete(false);
          }
          return false;
        },
      );
      return _interstitialDisplayedThisShow;
    } catch (e) {
      adLog('[LevelPlay] show interstitial: $e');
      return false;
    } finally {
      _interstitialCloseCompleter = null;
      _pendingRecordAsAppOpen = false;
      loadInterstitial();
    }
  }

  String _capPlacementLabel() =>
      _pendingRecordAsAppOpen ? 'app_open_substitute' : 'interstitial';

  void _logCapShown() {
    adLog(
      '[Cap] shown placement=${_capPlacementLabel()} trigger=$_interstitialTrigger',
    );
  }

  void _logCapTimeoutNoShow() {
    adLog(
      '[Interstitial] timeout — cap not recorded '
      'placement=${_capPlacementLabel()} trigger=$_interstitialTrigger',
    );
  }

  Future<void> _recordCapOnDisplay() async {
    if (_capRecordedThisShow) return;
    _capRecordedThisShow = true;
    if (_pendingRecordAsAppOpen) {
      await AdTriggerManager.instance.recordAppOpenSubstituteShown();
      final a = _analytics;
      if (a != null) unawaited(a.logAppOpenSubstitute());
    } else {
      await AdTriggerManager.instance.recordInterstitialShown();
    }
    _logCapShown();
  }

  void _logImpression(LevelPlayAdInfo adInfo) {
    final a = _analytics;
    if (a == null) return;
    unawaited(a.logLevelPlayImpression(adInfo));
  }

  void _onInterstitialLoaded() {
    _interstitialLoadInFlight = false;
    _interstitialReady = true;
    _onLoadSuccess();
    debugPrint('[LevelPlay] interstitial loaded');
    _interstitialLoadWaiter?.complete(true);
    _interstitialLoadWaiter = null;
  }

  void _onInterstitialLoadFailed(LevelPlayAdError error) {
    _interstitialLoadInFlight = false;
    _interstitialReady = false;
    _onLoadFailed(error);
    debugPrint('[LevelPlay] interstitial load FAILED: $error');
    _interstitialLoadWaiter?.complete(false);
    _interstitialLoadWaiter = null;
  }

  void _onInterstitialDisplayed(LevelPlayAdInfo adInfo) {
    _interstitialDisplayedThisShow = true;
    debugPrint('[LevelPlay] interstitial displayed');
    _logImpression(adInfo);
    final a = _analytics;
    if (a != null) {
      unawaited(a.logInterstitialShown(trigger: _interstitialTrigger));
    }
    unawaited(_recordCapOnDisplay());
  }

  void _onInterstitialClosed() {
    _interstitialReady = false;
    debugPrint('[LevelPlay] interstitial dismissed');
    if (!(_interstitialCloseCompleter?.isCompleted ?? true)) {
      _interstitialCloseCompleter?.complete(_interstitialDisplayedThisShow);
    }
  }

  void _onInterstitialDisplayFailed(LevelPlayAdError error) {
    adLog(
      '[Cap] display_failed placement=${_capPlacementLabel()} '
      'reason=${error.errorMessage}',
    );
    if (!(_interstitialCloseCompleter?.isCompleted ?? true)) {
      _interstitialCloseCompleter?.complete(false);
    }
  }

  // ── Rewarded ───────────────────────────────────────────────────────────

  void loadRewarded() {
    final ad = _rewarded;
    if (!_initialized || ad == null) return;
    if (_rewardedLoadInFlight) {
      adLog('[LevelPlay] rewarded load skipped — already in flight');
      return;
    }
    _rewardedLoadInFlight = true;
    debugPrint('[LevelPlay] rewarded loading...');
    unawaited(() async {
      try {
        await ad.loadAd();
      } catch (e) {
        adLog('[LevelPlay] rewarded loadAd exception: $e');
        _rewardedLoadInFlight = false;
      }
    }());
    _emitFillAttempt(format: 'rewarded', result: 'loading', errorCode: null);
  }

  Future<bool> ensureRewardedReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_rewardedReady) return true;
    if (_rewarded == null || !_initialized) {
      final ok = await init();
      if (!ok || _rewarded == null) return false;
    }
    final waiter = Completer<bool>();
    _rewardedLoadWaiter = waiter;
    loadRewarded();
    try {
      return await waiter.future.timeout(
        timeout,
        onTimeout: () => _rewardedReady,
      );
    } finally {
      if (identical(_rewardedLoadWaiter, waiter)) {
        _rewardedLoadWaiter = null;
      }
    }
  }

  /// Returns true when the user earned the reward ([LevelPlayRewardedAdListener.onAdRewarded]).
  Future<bool> showRewarded({String? placementName}) async {
    final ad = _rewarded;
    if (ad == null || !_initialized) return false;
    if (!_rewardedReady) {
      final ready = await ensureRewardedReady();
      if (!ready) return false;
    }
    _rewardedEarnedThisShow = false;
    _rewardedCloseCompleter = Completer<bool>();
    try {
      debugPrint('[LevelPlay] rewarded show called trigger=$_rewardedTrigger');
      await ad.showAd(placementName: placementName ?? _rewardedTrigger);
      return await _rewardedCloseCompleter!.future.timeout(
        const Duration(seconds: 180),
        onTimeout: () => _rewardedEarnedThisShow,
      );
    } catch (e) {
      adLog('[LevelPlay] show rewarded: $e');
      return false;
    } finally {
      _rewardedCloseCompleter = null;
      loadRewarded();
    }
  }

  void _onRewardedLoaded() {
    _rewardedLoadInFlight = false;
    _rewardedReady = true;
    _emitFillAttempt(format: 'rewarded', result: 'filled', errorCode: null);
    debugPrint('[LevelPlay] rewarded loaded');
    _rewardedLoadWaiter?.complete(true);
    _rewardedLoadWaiter = null;
  }

  void _onRewardedLoadFailed(LevelPlayAdError error) {
    _rewardedLoadInFlight = false;
    _rewardedReady = false;
    final code = error.errorCode;
    _emitFillAttempt(
      format: 'rewarded',
      result: code == _noFillCode ? 'no_fill' : 'error',
      errorCode: code,
    );
    debugPrint('[LevelPlay] rewarded load FAILED: $error');
    _rewardedLoadWaiter?.complete(false);
    _rewardedLoadWaiter = null;
  }

  void _onRewardedDisplayed(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] rewarded displayed');
    _logImpression(adInfo);
    final a = _analytics;
    if (a != null) {
      unawaited(a.logRewardedShown(trigger: _rewardedTrigger));
    }
  }

  void _onRewardedRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _rewardedEarnedThisShow = true;
    debugPrint('[LevelPlay] rewarded earned amount=${reward.amount}');
    final a = _analytics;
    if (a != null) {
      unawaited(
        a.logRewardedComplete(
          trigger: _rewardedTrigger,
          rewardName: reward.name,
        ),
      );
    }
  }

  void _onRewardedClosed() {
    _rewardedReady = false;
    debugPrint('[LevelPlay] rewarded dismissed earned=$_rewardedEarnedThisShow');
    if (!(_rewardedCloseCompleter?.isCompleted ?? true)) {
      _rewardedCloseCompleter?.complete(_rewardedEarnedThisShow);
    }
  }

  void _onRewardedDisplayFailed(LevelPlayAdError error) {
    adLog('[LevelPlay] rewarded display_failed reason=${error.errorMessage}');
    if (!(_rewardedCloseCompleter?.isCompleted ?? true)) {
      _rewardedCloseCompleter?.complete(false);
    }
  }
}

class _RewardedBridge with LevelPlayRewardedAdListener {
  _RewardedBridge(this._host);
  final LevelPlayAdService _host;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _host._onRewardedLoaded();

  @override
  void onAdLoadFailed(LevelPlayAdError error) => _host._onRewardedLoadFailed(error);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) => _host._onRewardedDisplayed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _host._onRewardedDisplayFailed(error);
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    final a = _host._analytics;
    if (a == null) return;
    unawaited(
      a.logClick(
        network: 'levelplay',
        format: 'rewarded',
        placement: _host._rewardedTrigger,
      ),
    );
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _host._onRewardedClosed();

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _host._onRewardedRewarded(reward, adInfo);
  }
}

class _InterstitialBridge with LevelPlayInterstitialAdListener {
  _InterstitialBridge(this._host);
  final LevelPlayAdService _host;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _host._onInterstitialLoaded();

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    _host._onInterstitialLoadFailed(error);
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) =>
      _host._onInterstitialDisplayed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _host._onInterstitialDisplayFailed(error);
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] interstitial clicked');
    final a = _host._analytics;
    if (a == null) return;
    unawaited(
      a.logClick(
        network: 'levelplay',
        format: 'interstitial',
        placement: _host._interstitialTrigger,
      ),
    );
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _host._onInterstitialClosed();

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}
}
