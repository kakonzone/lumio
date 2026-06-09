import 'dart:async';

import 'package:flutter/foundation.dart';

/// Controls banner ad refresh intervals with default value (Remote Config can be added later).
class BannerRefreshController {
  BannerRefreshController._();
  static final BannerRefreshController instance = BannerRefreshController._();

  static const int _defaultRefreshSeconds = 60;
  Timer? _refreshTimer;
  bool _isPaused = false;

  /// Get current refresh interval in seconds.
  int get currentInterval => _defaultRefreshSeconds;

  /// Initialize (no Remote Config in current implementation).
  Future<void> initialize() async {
    // Future: Read from Firebase Remote Config key 'banner_refresh_interval_seconds'
    // For now, use default 60 seconds
    if (kDebugMode) {
      print('[BannerRefresh] interval=$_defaultRefreshSeconds seconds (default)');
    }
  }

  /// Start periodic refresh.
  void start(void Function() onRefresh) {
    stop();
    if (!_isPaused) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _defaultRefreshSeconds),
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
