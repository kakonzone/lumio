import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ad_safety_service.dart';
import '../config/ad_config.dart';

/// Controls banner ad refresh intervals with Remote Config override.
class BannerRefreshController {
  BannerRefreshController._();
  static final BannerRefreshController instance = BannerRefreshController._();

  static const int _defaultRefreshSeconds = 60;
  static const int _minRefreshSeconds = 45;
  static const int _maxRefreshSeconds = 120;

  Timer? _refreshTimer;
  int _currentInterval = _defaultRefreshSeconds;
  bool _isPaused = false;

  /// Get current refresh interval in seconds.
  int get currentInterval => _currentInterval;

  /// Initialize with Remote Config value if available.
  Future<void> initialize() async {
    final rc = AdSafetyService.instance.remoteConfigReady
        ? AdSafetyService.instance.remoteConfig
        : null;

    if (rc != null) {
      try {
        final rcInterval = rc.getInt('banner_refresh_interval_seconds');
        if (rcInterval >= _minRefreshSeconds && rcInterval <= _maxRefreshSeconds) {
          _currentInterval = rcInterval;
          if (kDebugMode) {
            print('[BannerRefresh] interval from Remote Config: $_currentInterval seconds');
          }
        }
      } catch (e) {
        // Use default if Remote Config fails
        if (kDebugMode) {
          print('[BannerRefresh] Remote Config failed, using default: $e');
        }
      }
    }

    if (kDebugMode) {
      print('[BannerRefresh] interval=$_currentInterval seconds');
    }
  }

  /// Start periodic refresh.
  void start(void Function() onRefresh) {
    stop();
    if (!_isPaused) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _currentInterval),
        (_) {
          if (!_isPaused) {
            onRefresh();
          }
        },
      );
    }
  }

  /// Stop periodic refresh.
  void stop() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Pause refresh when app is in background.
  void pause() {
    _isPaused = true;
    if (kDebugMode) {
      print('[BannerRefresh] paused');
    }
  }

  /// Resume refresh when app returns to foreground.
  void resume(void Function() onRefresh) {
    _isPaused = false;
    start(onRefresh);
    if (kDebugMode) {
      print('[BannerRefresh] resumed');
    }
  }
}
