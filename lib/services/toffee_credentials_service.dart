import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Fetches Toffee Edge-Cache cookies from backend (never store in source).
///
/// Backend contract (example):
/// GET `/api/v1/stream-creds` →
/// `{ "linear": "...", "live": "...", "expires": "2026-05-27T00:00:00Z" }`
class ToffeeCredentialsService {
  ToffeeCredentialsService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      sendTimeout: const Duration(seconds: 6),
    ),
  );

  static String? _linearCookie;
  static String? _liveCookie;
  static DateTime? _expiresAt;
  static bool _loadedPrefs = false;
  static bool _refreshInFlight = false;

  static const _prefsLinear = 'toffee_edge_cookie_linear_v1';
  static const _prefsLive = 'toffee_edge_cookie_live_v1';
  static const _prefsExpires = 'toffee_edge_cookie_expires_v1';

  /// True when we have non-expired cookies in memory.
  static bool get isReady =>
      _linearCookie != null &&
      _liveCookie != null &&
      _expiresAt != null &&
      DateTime.now().isBefore(_expiresAt!);

  static bool get isExpired =>
      _expiresAt == null || DateTime.now().isAfter(_expiresAt!);

  static Future<void> _loadFromPrefsOnce() async {
    if (_loadedPrefs) return;
    _loadedPrefs = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _linearCookie = prefs.getString(_prefsLinear);
      _liveCookie = prefs.getString(_prefsLive);
      final expires = prefs.getString(_prefsExpires);
      _expiresAt = expires != null ? DateTime.tryParse(expires) : null;
    } catch (_) {
      // ignore
    }
  }

  /// Call early (startup) so Toffee channels have cookies before use.
  static Future<void> ensureFresh({bool force = false}) async {
    await _loadFromPrefsOnce();
    if (!force && isReady) return;
    if (!AppConfig.hasBackend || !AppConfig.hasBackendKey) {
      if (kDebugMode) {
        debugPrint(
          '[ToffeeCreds] backend config missing; Toffee Edge cookies unavailable',
        );
      }
      return;
    }
    await refresh();
  }

  static Future<void> refresh() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      final base = AppConfig.backendBaseUrl.trim();
      if (base.isEmpty) return;
      final normalized =
          base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      final uri = Uri.parse('$normalized/api/v1/stream-creds');
      if (!uri.hasScheme || uri.host.isEmpty) {
        if (kDebugMode) {
          debugPrint('[ToffeeCreds] invalid backendBaseUrl: $base');
        }
        return;
      }

      final res = await _dio.get(
        uri.toString(),
        options: Options(
          headers: {
            'Accept': 'application/json',
            'X-App-Key': AppConfig.backendAppKey,
          },
        ),
      );

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[ToffeeCreds] refresh failed http=${res.statusCode}');
        }
        return;
      }

      final decoded = res.data;
      if (decoded is! Map<String, dynamic>) return;

      final linear = decoded['linear'] as String?;
      final live = decoded['live'] as String?;
      final expiresRaw = decoded['expires'];
      DateTime? expiry;
      if (expiresRaw is String) expiry = DateTime.tryParse(expiresRaw);

      if (linear == null ||
          live == null ||
          linear.isEmpty ||
          live.isEmpty ||
          expiry == null) {
        if (kDebugMode) debugPrint('[ToffeeCreds] refresh invalid payload');
        return;
      }

      _linearCookie = linear;
      _liveCookie = live;
      _expiresAt = expiry.toUtc();

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsLinear, linear);
        await prefs.setString(_prefsLive, live);
        await prefs.setString(_prefsExpires, _expiresAt!.toIso8601String());
      } catch (_) {}

      if (kDebugMode) {
        debugPrint(
            '[ToffeeCreds] refreshed; expiresAt=${_expiresAt!.toIso8601String()}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ToffeeCreds] refresh exception: $e');
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Returns cookie to use for a given Toffee stream URL.
  static String cookieForStreamUrl(String streamUrl) {
    if (streamUrl.isEmpty) return '';
    if (!streamUrl.contains('toffeelive.com')) return '';

    // Keep last-known good cookies while refresh runs asynchronously.
    if (isExpired) {
      unawaited(refresh());
    }

    final uri = Uri.tryParse(streamUrl);
    final host = (uri?.host ?? '').toLowerCase();
    final live = host.contains('mprod-cdn.toffeelivelive.com') ||
        host.contains('toffeelivelive.com');
    return live ? (_liveCookie ?? '') : (_linearCookie ?? '');
  }
}
