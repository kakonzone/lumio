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

/// LevelPlay (IronSource) + Unity (mediated). [setDynamicUserId] before [init].
class LevelPlayAdService implements LevelPlayInitListener {
  LevelPlayAdService._();
  static final LevelPlayAdService instance = LevelPlayAdService._();

  AdAnalytics? _analytics;
  String _interstitialTrigger = 'unknown';
  String _rewardedPlacement = 'rewarded';

  bool _initialized = false;
  bool _interstitialReady = false;
  bool _rewardedReady = false;
  bool _rewardEarned = false;
  bool _rewardedLoadInFlight = false;
  bool _interstitialLoadInFlight = false;
  DateTime? _initCompletedAt;
  String? _lastInitError;
  LevelPlayAdError? _lastLoadError;

  int _rewardedNoFillStreak = 0;
  int _interstitialNoFillStreak = 0;
  DateTime? _rewardedLoadBlockedUntil;
  DateTime? _interstitialLoadBlockedUntil;

  @visibleForTesting
  static int debugRewardedLoadCallCount = 0;

  @visibleForTesting
  static int debugInterstitialLoadCallCount = 0;

  @visibleForTesting
  static Future<void> Function()? testRewardedLoadInvoker;

  @visibleForTesting
  static Future<void> Function()? testInterstitialLoadInvoker;

  @visibleForTesting
  static void debugResetForTest() {
    debugRewardedLoadCallCount = 0;
    debugInterstitialLoadCallCount = 0;
    testRewardedLoadInvoker = null;
    testInterstitialLoadInvoker = null;
    final s = instance;
    s._rewardedLoadInFlight = false;
    s._interstitialLoadInFlight = false;
    s._rewardedLoadBlockedUntil = null;
    s._interstitialLoadBlockedUntil = null;
    s._initialized = false;
  }

  bool get isRewardedLoadInFlight => _rewardedLoadInFlight;
  bool get isInterstitialLoadInFlight => _interstitialLoadInFlight;
  String? get lastInitError => _lastInitError;
  LevelPlayAdError? get lastLoadError => _lastLoadError;
  DateTime? get initCompletedAt => _initCompletedAt;

  Completer<bool>? _interstitialCloseCompleter;
  bool _interstitialDisplayedThisShow = false;
  bool _pendingRecordAsAppOpen = false;
  bool _capRecordedThisShow = false;
  Completer<bool>? _rewardedCompleter;
  Completer<bool>? _rewardedLoadWaiter;
  Completer<bool>? _interstitialLoadWaiter;
  Completer<bool>? _initCompleter;

  late final LevelPlayInterstitialAd _interstitial = LevelPlayInterstitialAd(
    adUnitId: AdConfig.interstitialAdUnitId,
  );
  late final LevelPlayRewardedAd _rewarded = LevelPlayRewardedAd(
    adUnitId: AdConfig.rewardedAdUnitId,
  );

  bool get isInitialized => _initialized;
  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady => _rewardedReady;

  void attachAnalytics(AdAnalytics analytics) => _analytics = analytics;

  void setInterstitialTrigger(String trigger) => _interstitialTrigger = trigger;

  void setRewardedPlacement(String placement) => _rewardedPlacement = placement;

  static const _initTimeout = Duration(seconds: 8);
  static const _retryBackoff = Duration(seconds: 2);

  Future<bool> init() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    if (_initialized) return true;
    if (AdSafetyService.instance.adsBlockedInDebug) {
      adLog('[LevelPlay] init skipped — pass --dart-define=ADS_ENABLED=true');
      return false;
    }
    if (!AdConfig.hasLevelPlayAppKey) {
      adLog(
        '[LevelPlay] init skipped — LEVELPLAY_APP_KEY empty (pass --dart-define)',
      );
      return false;
    }
    if (!AdConfig.hasLevelPlayAdUnits) {
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
    _rewarded.setListener(_RewardedBridge(this));

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
    _rewardedNoFillStreak = 0;
    _interstitialNoFillStreak = 0;
    _rewardedLoadBlockedUntil = null;
    _interstitialLoadBlockedUntil = null;
    adLog('[LevelPlay] backoff reset — app foreground');
  }

  @visibleForTesting
  void debugSetInitializedForTest(bool value) => _initialized = value;

  @visibleForTesting
  void debugSimulateRewardedLoadFailedForTest() {
    _onRewardedLoadFailed(
      LevelPlayAdError(
        errorMessage: 'test',
        errorCode: 627,
        adUnitId: null,
      ),
    );
  }

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

  void loadInterstitial() => _loadFormat(
        format: 'interstitial',
        inFlight: () => _interstitialLoadInFlight,
        setInFlight: (v) => _interstitialLoadInFlight = v,
        blockedUntil: () => _interstitialLoadBlockedUntil,
        invokeLoad: _invokeInterstitialLoad,
      );

  void loadRewarded() => _loadFormat(
        format: 'rewarded',
        inFlight: () => _rewardedLoadInFlight,
        setInFlight: (v) => _rewardedLoadInFlight = v,
        blockedUntil: () => _rewardedLoadBlockedUntil,
        invokeLoad: _invokeRewardedLoad,
      );

  void _loadFormat({
    required String format,
    required bool Function() inFlight,
    required void Function(bool) setInFlight,
    required DateTime? Function() blockedUntil,
    required Future<void> Function() invokeLoad,
  }) {
    if (!_initialized) return;
    final blocked = blockedUntil();
    if (blocked != null && DateTime.now().isBefore(blocked)) {
      adLog(
        '[LevelPlay] $format load skipped — backoff until $blocked',
      );
      return;
    }
    if (inFlight()) {
      adLog('[LevelPlay] $format load skipped — already in flight');
      return;
    }
    setInFlight(true);
    debugPrint('[LevelPlay] $format loading...');
    unawaited(() async {
      try {
        await invokeLoad();
      } catch (e) {
        adLog('[LevelPlay] $format loadAd exception: $e');
        setInFlight(false);
      }
    }());
    _emitFillAttempt(format: format, result: 'loading', errorCode: null);
  }

  Future<void> _invokeInterstitialLoad() async {
    debugInterstitialLoadCallCount++;
    final invoker = testInterstitialLoadInvoker ?? () => _interstitial.loadAd();
    await invoker();
  }

  Future<void> _invokeRewardedLoad() async {
    debugRewardedLoadCallCount++;
    final invoker = testRewardedLoadInvoker ?? () => _rewarded.loadAd();
    await invoker();
  }

  Duration _backoffForStreak(int streak) {
    if (streak <= 0) return Duration.zero;
    final idx = (streak - 1).clamp(0, _backoffSteps.length - 1);
    return _backoffSteps[idx];
  }

  void _scheduleNoFillBackoff(String format, int streak) {
    final delay = _backoffForStreak(streak);
    if (delay <= Duration.zero) return;
    final until = DateTime.now().add(delay);
    if (format == 'rewarded') {
      _rewardedLoadBlockedUntil = until;
    } else {
      _interstitialLoadBlockedUntil = until;
    }
    adLog(
      '[LevelPlay] $format no-fill backoff ${delay.inSeconds}s '
      '(streak=$streak)',
    );
  }

  void _resetNoFillBackoff(String format) {
    if (format == 'rewarded') {
      _rewardedNoFillStreak = 0;
      _rewardedLoadBlockedUntil = null;
    } else {
      _interstitialNoFillStreak = 0;
      _interstitialLoadBlockedUntil = null;
    }
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

  void _onLoadFailed(String format, LevelPlayAdError error) {
    _lastLoadError = error;
    final code = error.errorCode;
    if (code == _noFillCode) {
      if (format == 'rewarded') {
        _rewardedNoFillStreak++;
        _scheduleNoFillBackoff(format, _rewardedNoFillStreak);
      } else {
        _interstitialNoFillStreak++;
        _scheduleNoFillBackoff(format, _interstitialNoFillStreak);
      }
      _emitFillAttempt(
        format: format,
        result: 'no_fill',
        errorCode: code,
        attemptN: format == 'rewarded'
            ? _rewardedNoFillStreak
            : _interstitialNoFillStreak,
      );
    } else {
      _emitFillAttempt(
        format: format,
        result: 'error',
        errorCode: code,
      );
    }
  }

  void _onLoadSuccess(String format) {
    _resetNoFillBackoff(format);
    _emitFillAttempt(format: format, result: 'filled', errorCode: null);
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

  Future<bool> ensureRewardedReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (_rewardedReady) return true;
    if (!_initialized) {
      final ok = await init();
      if (!ok || !_initialized) return false;
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

  /// Cold-start "app open" — **not** a native App Open ad unit.
  ///
  /// LevelPlay Flutter 9.2.0 exposes interstitial/rewarded/banner only (no App Open API).
  /// This shows a capped interstitial after splash via [showInterstitial] + [AdTriggerManager].
  Future<bool> showAppOpenSubstitute({required bool removeAds}) async {
    if (!await AdTriggerManager.instance
        .canShowAppOpenSubstitute(removeAds: removeAds)) {
      return false;
    }
    setInterstitialTrigger('app_open_substitute');
    final shown = await showInterstitial(
      bypassHourlyGate: true,
      recordAsAppOpen: true,
    );
    return shown;
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

  Future<bool> showRewarded() async {
    if (!_initialized) return false;
    if (!_rewardedReady) {
      final ready = await ensureRewardedReady();
      if (!ready) return false;
    }
    _rewardEarned = false;
    _rewardedCompleter = Completer<bool>();
    try {
      debugPrint('[LevelPlay] rewarded show called');
      await _rewarded.showAd();
      final ok = await _rewardedCompleter!.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          adLog(
            '[Cap] timeout_no_show placement=rewarded trigger=$_rewardedPlacement',
          );
          return false;
        },
      );
      return ok && _rewardEarned;
    } catch (e) {
      adLog('[LevelPlay] show rewarded: $e');
      return false;
    } finally {
      _rewardedCompleter = null;
      _rewardEarned = false;
      loadRewarded();
    }
  }

  void _logImpression(LevelPlayAdInfo adInfo) {
    final a = _analytics;
    if (a == null) return;
    unawaited(a.logLevelPlayImpression(adInfo));
  }

  void _onInterstitialLoaded() {
    _interstitialLoadInFlight = false;
    _interstitialReady = true;
    _onLoadSuccess('interstitial');
    debugPrint('[LevelPlay] interstitial loaded');
    _interstitialLoadWaiter?.complete(true);
    _interstitialLoadWaiter = null;
  }

  void _onInterstitialLoadFailed(LevelPlayAdError error) {
    _interstitialLoadInFlight = false;
    _interstitialReady = false;
    _onLoadFailed('interstitial', error);
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

  void _onRewardedLoaded() {
    _rewardedLoadInFlight = false;
    _rewardedReady = true;
    _onLoadSuccess('rewarded');
    debugPrint('[LevelPlay] rewarded loaded');
    _rewardedLoadWaiter?.complete(true);
    _rewardedLoadWaiter = null;
  }

  void _onRewardedLoadFailed(LevelPlayAdError error) {
    _rewardedLoadInFlight = false;
    _rewardedReady = false;
    _onLoadFailed('rewarded', error);
    debugPrint('[LevelPlay] rewarded load FAILED: $error');
    _rewardedLoadWaiter?.complete(false);
    _rewardedLoadWaiter = null;
  }

  void _onRewardedDisplayed(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] rewarded displayed');
    _logImpression(adInfo);
  }

  void _onRewardedGranted() {
    _rewardEarned = true;
    unawaited(AdTriggerManager.instance.recordRewardedShown());
    adLog('[Cap] shown placement=rewarded trigger=$_rewardedPlacement');
    final a = _analytics;
    if (a != null) {
      unawaited(a.logRewardedComplete(placement: _rewardedPlacement));
    }
    if (!(_rewardedCompleter?.isCompleted ?? true)) {
      _rewardedCompleter?.complete(true);
    }
  }

  void _onRewardedClosed() {
    _rewardedReady = false;
    debugPrint('[LevelPlay] rewarded dismissed');
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!(_rewardedCompleter?.isCompleted ?? true)) {
        _rewardedCompleter?.complete(_rewardEarned);
      }
      _rewardEarned = false;
    });
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

class _RewardedBridge with LevelPlayRewardedAdListener {
  _RewardedBridge(this._host);
  final LevelPlayAdService _host;

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) => _host._onRewardedLoaded();

  @override
  void onAdLoadFailed(LevelPlayAdError error) => _host._onRewardedLoadFailed(error);

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) =>
      _host._onRewardedDisplayed(adInfo);

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _host._rewardedCompleter?.complete(false);
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {
    debugPrint('[LevelPlay] rewarded clicked');
    final a = _host._analytics;
    if (a == null) return;
    unawaited(
      a.logClick(
        network: 'levelplay',
        format: 'rewarded',
        placement: _host._rewardedPlacement,
      ),
    );
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) => _host._onRewardedClosed();

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _host._onRewardedGranted();
  }
}
