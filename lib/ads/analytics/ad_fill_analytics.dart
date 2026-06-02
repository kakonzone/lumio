import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Ad waterfall fill / no-fill telemetry for dashboard queries.
class AdFillAnalytics {
  AdFillAnalytics._();
  static final AdFillAnalytics instance = AdFillAnalytics._();

  Future<void> logWaterfallAttempt({
    required String network,
    required String placement,
    required bool filled,
    int? latencyMs,
    String? reason,
  }) async {
    final params = <String, Object>{
      'network': network,
      'placement': placement,
      'filled': filled ? 1 : 0,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };
    if (kDebugMode) {
      debugPrint('[AdFillAnalytics] $params');
    }
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_waterfall_attempt',
        parameters: params,
      );
    } catch (_) {
      // Analytics optional in tests.
    }
  }

  Future<void> logImpression({
    required String network,
    required String format,
    required String placement,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_impression',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
        },
      );
    } catch (_) {}
  }
}
