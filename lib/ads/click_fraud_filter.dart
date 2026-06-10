import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import '../services/firebase_bootstrap.dart';
import 'ad_log.dart';

/// Click fraud filter to detect and block suspicious click patterns.
/// - Max 5 clicks/min per user
/// - Rapid-click pattern detection (>3 clicks in 2s = block)
/// - Logs anomalies to Firebase
class ClickFraudFilter {
  ClickFraudFilter._();
  static final ClickFraudFilter instance = ClickFraudFilter._();

  static const int _maxClicksPerMinute = 5;
  static const int _rapidClickThreshold = 3;
  static const Duration _rapidClickWindow = Duration(seconds: 2);
  static const Duration _minuteWindow = Duration(minutes: 1);

  final List<DateTime> _clickTimestamps = [];
  bool _isBlocked = false;
  DateTime? _blockUntil;

  /// Check if a click should be allowed. Returns true if allowed, false if blocked.
  Future<bool> shouldAllowClick({
    String? placement,
    String? network,
    String? adUnitId,
  }) async {
    if (_isBlocked) {
      // Check if block has expired
      if (_blockUntil != null && DateTime.now().isBefore(_blockUntil!)) {
        adLog('[ClickFraudFilter] click blocked (temporarily blocked)');
        return false;
      } else {
        _isBlocked = false;
        _blockUntil = null;
      }
    }

    final now = DateTime.now();

    // Clean old timestamps
    _clickTimestamps.removeWhere((timestamp) =>
        now.difference(timestamp) > _minuteWindow);

    // Check clicks per minute limit
    if (_clickTimestamps.length >= _maxClicksPerMinute) {
      _logAnomaly(
        reason: 'max_clicks_per_minute',
        placement: placement,
        network: network,
        adUnitId: adUnitId,
        clickCount: _clickTimestamps.length,
      );
      _blockTemporarily();
      return false;
    }

    // Check rapid-click pattern
    final recentClicks = _clickTimestamps.where((timestamp) =>
        now.difference(timestamp) <= _rapidClickWindow).length;

    if (recentClicks >= _rapidClickThreshold) {
      _logAnomaly(
        reason: 'rapid_click_pattern',
        placement: placement,
        network: network,
        adUnitId: adUnitId,
        clickCount: recentClicks,
        windowSeconds: _rapidClickWindow.inSeconds,
      );
      _blockTemporarily();
      return false;
    }

    // Allow the click
    _clickTimestamps.add(now);
    return true;
  }

  /// Temporarily block clicks for 1 minute
  void _blockTemporarily() {
    _isBlocked = true;
    _blockUntil = DateTime.now().add(const Duration(minutes: 1));
    adLog('[ClickFraudFilter] temporarily blocked for 1 minute');
  }

  /// Log anomaly to Firebase Analytics
  Future<void> _logAnomaly({
    required String reason,
    String? placement,
    String? network,
    String? adUnitId,
    int? clickCount,
    int? windowSeconds,
  }) async {
    adLog('[ClickFraudFilter] anomaly detected: $reason');

    if (!FirebaseBootstrap.isInitialized) {
      return;
    }

    try {
      final analytics = FirebaseAnalytics.instance;
      await analytics.logEvent(
        name: 'ad_click_anomaly',
        parameters: {
          'reason': reason,
          if (placement != null) 'placement': placement,
          if (network != null) 'network': network,
          if (adUnitId != null) 'ad_unit_id': adUnitId,
          if (clickCount != null) 'click_count': clickCount,
          if (windowSeconds != null) 'window_seconds': windowSeconds,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      adLog('[ClickFraudFilter] failed to log anomaly: $e');
    }
  }

  /// Get current click count (within last minute)
  int getCurrentClickCount() {
    final now = DateTime.now();
    return _clickTimestamps.where((timestamp) =>
        now.difference(timestamp) <= _minuteWindow).length;
  }

  /// Reset filter state (for testing)
  void reset() {
    _clickTimestamps.clear();
    _isBlocked = false;
    _blockUntil = null;
    adLog('[ClickFraudFilter] reset');
  }

  /// Check if currently blocked
  bool get isBlocked {
    if (_isBlocked && _blockUntil != null) {
      if (DateTime.now().isBefore(_blockUntil!)) {
        return true;
      } else {
        _isBlocked = false;
        _blockUntil = null;
      }
    }
    return false;
  }
}
