import 'dart:async';

import '../services/server_cap.dart';
import 'analytics/ad_analytics.dart';

/// Facade used by [AdTriggerManager] — delegates to [ServerCap] (GET + 5min cache).
class ServerCapService {
  ServerCapService._();
  static final ServerCapService instance = ServerCapService._();

  final ServerCap _cap = ServerCap.instance;
  AdAnalytics? _analytics;

  void attachAnalytics(AdAnalytics analytics) => _analytics = analytics;

  bool get isConfigured => _cap.isConfigured;

  void logConfigurationOnce() => _cap.logConfigurationOnce();

  /// `true` when server allows; `false` when capped or fail-closed (M2).
  Future<bool> allowsPlacement(String placement) async {
    logConfigurationOnce();
    if (_cap.blocksAdsInRelease) return false;
    if (!_cap.isConfigured) return true;
    final allowed = await _cap.allowsPlacement(placement);
    if (!allowed && _cap.isFailClosed) {
      final a = _analytics;
      if (a != null) {
        unawaited(
          a.logCapClientFallback(
            reason: 'server_fail_closed',
            placement: placement,
          ),
        );
      }
    }
    return allowed;
  }
}
