import '../core/logging/safe_logger.dart';

/// Session pacing controls — prevents ad overload in first minute.
class SessionPacing {
  SessionPacing._();
  static final SessionPacing instance = SessionPacing._();

  DateTime? _sessionStartTime;

  /// Call this when app launches (e.g., in main() before runApp).
  void initialize() {
    _sessionStartTime = DateTime.now();
    SafeLogger.debug('ads', '[SessionPacing] initialized');
  }

  /// Returns true during first 60 seconds after app open.
  bool isFirstMinute() {
    if (_sessionStartTime == null) {
      // If not initialized, assume safe to show (fail-open)
      return false;
    }
    final elapsed = DateTime.now().difference(_sessionStartTime!);
    return elapsed.inSeconds < 60;
  }

  /// Returns false during first minute (zero ads in first 60s).
  bool canShowFullScreenAd() {
    return !isFirstMinute();
  }

  /// Reset session start time (for testing or special cases).
  void reset() {
    _sessionStartTime = DateTime.now();
  }
}
