import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Ad waterfall fill / no-fill telemetry for dashboard queries.
class AdFillAnalytics {
  AdFillAnalytics._();
  static final AdFillAnalytics instance = AdFillAnalytics._();

  // Static eCPM table by geography (USD per 1000 impressions)
  static const Map<String, double> _ecpmByGeography = {
    'BD': 0.80,
    'IN': 1.20,
    'PK': 1.20,
    'GB': 4.00,
    'US': 4.00,
    'UK': 4.00,
  };

  static const double _defaultEcpm = 1.00;

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
      
      // Log revenue estimate
      await _logRevenueEstimate(placement);
    } catch (_) {}
  }

  Future<void> _logRevenueEstimate(String placement) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final key = 'revenue_estimate_${today}_$placement';
      
      final ecpm = _getEcpmForGeography();
      final revenueEstimate = ecpm / 1000; // Per impression (eCPM is per 1000)
      
      final currentRevenue = prefs.getDouble(key) ?? 0.0;
      await prefs.setDouble(key, currentRevenue + revenueEstimate);
      
      if (kDebugMode) {
        debugPrint('[AdFillAnalytics] Revenue estimate for $placement: $revenueEstimate (eCPM: $ecpm)');
      }
    } catch (e) {
      debugPrint('[AdFillAnalytics] Revenue logging error: $e');
    }
  }

  double _getEcpmForGeography() {
    // In a real implementation, this would check vpn_signal_service or device locale
    // For now, default to a reasonable value
    return _ecpmByGeography['BD'] ?? _defaultEcpm;
  }

  Future<void> logRequest({
    required String network,
    required String format,
    required String placement,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_request',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
        },
      );
    } catch (_) {}
  }

  Future<void> logFill({
    required String network,
    required String format,
    required String placement,
    required int latencyMs,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_fill',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
          'latency_ms': latencyMs,
        },
      );
    } catch (_) {}
  }

  Future<void> logClick({
    required String network,
    required String format,
    required String placement,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_click',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
        },
      );
    } catch (_) {}
  }

  Future<void> logDismiss({
    required String network,
    required String format,
    required String placement,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_dismiss',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
        },
      );
    } catch (_) {}
  }

  Future<void> logError({
    required String network,
    required String format,
    required String placement,
    required String errorCode,
  }) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'ad_error',
        parameters: {
          'network': network,
          'format': format,
          'placement': placement,
          'error_code': errorCode,
        },
      );
    } catch (_) {}
  }
}
