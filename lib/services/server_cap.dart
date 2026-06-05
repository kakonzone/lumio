import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';
import 'ad_safety_service.dart';

/// GET `{CAP_BASE_URL}/caps/{installId}` — per-placement hourly limits (5min cache).
class ServerCap {
  ServerCap._();
  static final ServerCap instance = ServerCap._();

  static const _cacheTtl = Duration(minutes: 5);
  static const _timeout = Duration(seconds: 5);

  final http.Client _http = http.Client();

  Map<String, int> _limits = {};
  DateTime? _syncedAt;
  bool _loggedDisabled = false;
  bool _loggedReleaseMissing = false;
  bool _failClosed = false;
  bool _loggedFailClosed = false;
  bool _loggedLocalOnly = false;

  @visibleForTesting
  static bool debugTreatAsConfigured = false;

  bool get _usesLocalOnlyCaps =>
      !debugTreatAsConfigured &&
      AdConfig.capLocalOnlyEffective &&
      AdConfig.capBaseUrl.trim().isEmpty;

  bool get isConfigured =>
      debugTreatAsConfigured || AdConfig.capBaseUrl.trim().isNotEmpty;

  /// True when cap API is configured but last sync failed (M2 fail-closed).
  bool get isFailClosed => _failClosed && !_usesLocalOnlyCaps;

  int get cachedPlacementCount => _limits.length;

  /// Release builds without [AdConfig.capBaseUrl] block ads unless local/sideload caps.
  bool get blocksAdsInRelease =>
      kReleaseMode &&
      AdConfig.capBaseUrl.trim().isEmpty &&
      !AdConfig.capLocalOnlyEffective;

  /// Logs once per process when URL unset.
  void logConfigurationOnce() {
    if (_usesLocalOnlyCaps) {
      if (_loggedLocalOnly) return;
      _loggedLocalOnly = true;
      debugPrint(
        '[ServerCap] LOCAL_ONLY_MODE active — using local caps only',
      );
      return;
    }
    if (!isConfigured) {
      if (kReleaseMode) {
        if (_loggedReleaseMissing) return;
        _loggedReleaseMissing = true;
        // ignore: avoid_print
        print(
          '[ServerCap] ERROR CAP_BASE_URL unset in release — ads disabled. '
          'Fix: set CAP_BASE_URL in secrets.json OR use '
          '--dart-define=CAP_LOCAL_ONLY_MODE=true (build_size_apk.sh does this). '
          'Invalid secrets.json also drops all dart-defines — run: python3 -m json.tool secrets.json',
        );
      } else {
        if (_loggedDisabled) return;
        _loggedDisabled = true;
        debugPrint('[ServerCap] CAP_BASE_URL not set — local only');
      }
      return;
    }
  }

  /// Sync when cache older than 5 minutes (no-op if URL unset).
  Future<void> syncIfStale() async {
    if (_usesLocalOnlyCaps) return;
    if (!isConfigured) return;
    final synced = _syncedAt;
    if (synced != null && DateTime.now().difference(synced) < _cacheTtl) {
      return;
    }
    await sync();
  }

  /// GET caps for this device. On failure keeps prior cache or empty → local fallback.
  Future<void> sync() async {
    if (_usesLocalOnlyCaps) return;
    if (!isConfigured) return;

    final installId = AdSafetyService.instance.installId;
    if (installId.isEmpty || installId == 'unknown') {
      _failClosed = true;
      _logFailClosedOnce('installId_unavailable');
      return;
    }

    final uri = _capsUri(installId);
    final headers = <String, String>{'Accept': 'application/json'};
    // INTENTIONALLY OMITTED: Play Integrity disabled, server must rely on HMAC + install-ID dedup
    try {
      final res = await _http.get(uri, headers: headers).timeout(_timeout);

      if (res.statusCode != 200) {
        _failClosed = true;
        _logFailClosedOnce('http_${res.statusCode}');
        return;
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        _failClosed = true;
        _logFailClosedOnce('invalid_json');
        return;
      }

      _limits = _parsePlacementLimits(decoded);
      _syncedAt = DateTime.now();
      _failClosed = false;
      if (kDebugMode) {
        debugPrint(
          '[ServerCap] synced ${_limits.length} placements from server',
        );
      }
    } catch (e) {
      _failClosed = true;
      _logFailClosedOnce('$e');
    }
  }

  void _logFailClosedOnce(String reason) {
    if (_loggedFailClosed) return;
    _loggedFailClosed = true;
    if (kDebugMode) {
      debugPrint('[ServerCap] fail_closed reason=$reason — blocking ads');
    }
  }

  Uri _capsUri(String installId) {
    final base = AdConfig.capBaseUrl.trim();
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse('${normalized}caps/$installId');
  }

  /// Parses `{ "interstitial": 8 }` or `{ "caps": { "interstitial": 8 } }`.
  static Map<String, int> _parsePlacementLimits(Map<String, dynamic> json) {
    final dynamic raw = json['caps'] ?? json['placements'] ?? json;
    if (raw is! Map) return {};

    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is num) {
        out[entry.key.toString()] = value.toInt();
      } else if (value is Map) {
        final limit = value['limit'] ?? value['max'];
        if (limit is num) {
          out[entry.key.toString()] = limit.toInt();
        }
      }
    }
    return out;
  }

  int? limitFor(String placement) => _limits[placement];

  /// Server hourly ceiling for [placement]; `true` if no server rule or under limit.
  Future<bool> allowsPlacement(String placement) async {
    logConfigurationOnce();
    if (_usesLocalOnlyCaps) {
      return true;
    }
    if (!isConfigured) {
      return !kReleaseMode;
    }

    await syncIfStale();

    if (_failClosed) return false;

    final limit = limitFor(placement);
    if (limit == null) return true;

    final usage = await _hourlyUsageForPlacement(placement);
    return usage < limit;
  }

  static String _hourKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}-${n.hour}';
  }

  static Future<int> _hourlyUsageForPlacement(String placement) async {
    final prefix = switch (placement) {
      'app_open_substitute' => 'lumio_is_inter',
      _ => 'lumio_is_inter',
    };
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${prefix}_${_hourKey()}') ?? 0;
  }

  @visibleForTesting
  void debugSetCache(Map<String, int> limits) {
    _limits = Map.from(limits);
    _syncedAt = DateTime.now();
  }

  @visibleForTesting
  void debugClearCache() {
    _limits = {};
    _syncedAt = null;
    _loggedDisabled = false;
    _failClosed = false;
    _loggedFailClosed = false;
  }

  @visibleForTesting
  void debugSetFailClosed(bool value) {
    _failClosed = value;
  }

  @visibleForTesting
  static Map<String, int> debugParseLimits(Map<String, dynamic> json) =>
      _parsePlacementLimits(json);
}
