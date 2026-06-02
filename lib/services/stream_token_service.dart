import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../network/secure_dio.dart';
import '../security/security_config.dart';
import '../services/ad_safety_service.dart';
import '../utils/ad_debug_log.dart';
import 'firebase_bootstrap.dart';

class StreamTokenResult {
  const StreamTokenResult({
    required this.token,
    required this.streamUrl,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  final String token;
  final String streamUrl;
  final DateTime expiresAt;
  final int expiresInSeconds;
}

/// Signed stream URLs for protected catalog entries (starshare, credentialed hosts).
class StreamTokenService {
  StreamTokenService._();
  static final StreamTokenService instance = StreamTokenService._();

  static const Duration _cacheSkew = Duration(seconds: 30);
  static const Duration _maxCacheTtl = Duration(minutes: 4);
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maxAttempts = 3;

  @visibleForTesting
  http.Client? httpClientOverride;

  @visibleForTesting
  Dio? dioOverrideForTest;

  @visibleForTesting
  String? baseUrlOverrideForTest;

  final Map<String, StreamTokenResult> _cache = {};
  bool _loggedMissingBase = false;

  http.Client get _http => httpClientOverride ?? http.Client();

  Uri? _tokenEndpointUri() {
    final base = (baseUrlOverrideForTest ?? AppConfig.streamTokenBaseUrl).trim();
    if (base.isEmpty || base == '__MISSING__') {
      if (!_loggedMissingBase) {
        _loggedMissingBase = true;
        AdDebugLog.info(
          'StreamTokenService',
          '[StreamToken] BASE_URL not set — protected channels disabled',
        );
      }
      return null;
    }
    final parsed = Uri.tryParse(base);
    if (parsed == null || parsed.scheme != 'https') return null;

    final path = parsed.path.toLowerCase();
    if (path.endsWith('/v1/stream-token') || path.endsWith('/v1/stream/token')) {
      return parsed;
    }
    final prefix = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
    return parsed.replace(path: '${prefix}v1/stream-token');
  }

  Dio _dioFor(Uri tokenUri) {
    if (dioOverrideForTest != null) return dioOverrideForTest!;
    final origin =
        '${tokenUri.scheme}://${tokenUri.host}${tokenUri.hasPort ? ':${tokenUri.port}' : ''}';
    return SecureDio.createForBaseUrl(origin);
  }

  /// Returns signed stream URL or null when protected channel cannot be tokenized.
  Future<String?> fetchToken(
    String channelId, {
    String? originalUrl,
  }) async {
    final result = await fetchTokenResult(
      channelId: channelId,
      originalUrl: originalUrl,
    );
    return result?.streamUrl;
  }

  /// POST body: `{channelId, installId, fingerprint}` → `{token, expiresIn, streamUrl}`.
  Future<StreamTokenResult?> fetchTokenResult({
    required String channelId,
    String? originalUrl,
  }) async {
    final cacheKey = channelId;
    final cached = _cache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }

    // Sideload QA: skip token API when host is unreachable (use embedded URL).
    if (SecurityConfig.sideloadDevBuild &&
        originalUrl != null &&
        originalUrl.trim().isNotEmpty) {
      // ignore: avoid_print
      print(
        '[StreamToken] sideload embedded fallback channel=$channelId',
      );
      final result = StreamTokenResult(
        token: '',
        streamUrl: originalUrl.trim(),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
        expiresInSeconds: 12 * 3600,
      );
      _cache[cacheKey] = result;
      return result;
    }

    final tokenUri = _tokenEndpointUri();
    if (tokenUri == null) return null;

    final safety = AdSafetyService.instance;
    try {
      await safety.ensureReady();
    } catch (_) {
      // Platform plugins unavailable (e.g. unit tests).
    }
    final installId = safety.installId == 'unknown'
        ? 'test_install'
        : safety.installId;
    final fingerprint = safety.deviceFingerprint == 'unknown'
        ? 'test_fingerprint'
        : safety.deviceFingerprint;

    final body = <String, dynamic>{
      'channelId': channelId,
      'channel_id': channelId,
      if (originalUrl != null && originalUrl.isNotEmpty) 'source_url': originalUrl,
      'installId': installId,
      'fingerprint': fingerprint,
    };

    Response<dynamic>? response;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        response = await _postToken(tokenUri, body);
        break;
      } catch (e, st) {
        final isLast = attempt == _maxAttempts - 1;
        if (isLast) {
          AdDebugLog.error(
            'StreamTokenService.fetchToken',
            '[StreamToken] network error channel=$channelId err=$e',
          );
          if (FirebaseBootstrap.crashlyticsWired) {
            await FirebaseCrashlytics.instance.recordError(
              e,
              st,
              reason: 'Stream token fetch failed',
              information: ['channel_id=$channelId'],
            );
          }
          return null;
        }
        await Future<void>.delayed(Duration(milliseconds: 200 * (attempt + 1)));
      }
    }

    if (response == null) return null;

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401 || statusCode == 403) {
      _cache.remove(cacheKey);
      AdDebugLog.error(
        'StreamTokenService.fetchToken',
        '[StreamToken] auth failed $statusCode channel=$channelId',
      );
      if (FirebaseBootstrap.crashlyticsWired) {
        await FirebaseCrashlytics.instance.recordError(
          Exception('stream_token_auth_failed'),
          StackTrace.current,
          reason: 'Stream token endpoint returned $statusCode',
          information: ['channel_id=$channelId'],
        );
      }
      return null;
    }
    if (statusCode < 200 || statusCode >= 300) {
      if (statusCode >= 500 && statusCode < 600) {
        AdDebugLog.error(
          'StreamTokenService.fetchToken',
          '[StreamToken] server error $statusCode channel=$channelId',
        );
      } else {
        AdDebugLog.error(
          'StreamTokenService.fetchToken',
          '[StreamToken] HTTP $statusCode channel=$channelId',
        );
      }
      return null;
    }

    final decoded = response.data;
    final Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else if (decoded is String) {
      final parsed = jsonDecode(decoded);
      map = parsed is Map<String, dynamic> ? parsed : null;
    } else {
      map = null;
    }
    if (map == null) return null;

    final token = (map['token'] as String? ?? '').trim();
    var streamUrl =
        (map['streamUrl'] as String? ?? map['url'] as String? ?? '').trim();
    if (streamUrl.isEmpty) return null;
    final streamUri = Uri.tryParse(streamUrl);
    if (streamUri == null || !streamUri.hasScheme) return null;

    final expiresIn = map['expiresIn'] is int
        ? map['expiresIn'] as int
        : int.tryParse('${map['expiresIn']}') ?? 3600;
    final serverTtl =
        expiresIn > 60 ? expiresIn - _cacheSkew.inSeconds : 300;
    final ttlSeconds = serverTtl < _maxCacheTtl.inSeconds
        ? serverTtl
        : _maxCacheTtl.inSeconds;
    final expiresAt = DateTime.now().add(Duration(seconds: ttlSeconds));

    final result = StreamTokenResult(
      token: token,
      streamUrl: streamUrl,
      expiresAt: expiresAt,
      expiresInSeconds: expiresIn,
    );
    _cache[cacheKey] = result;
    AdDebugLog.info(
      'StreamTokenService.fetchTokenResult',
      '[StreamToken] fetched channelId=$channelId ttl=${ttlSeconds}s',
    );
    return result;
  }

  Future<Response<dynamic>> _postToken(
    Uri tokenUri,
    Map<String, dynamic> body,
  ) async {
    if (httpClientOverride != null) {
      final httpResponse = await _http
          .post(
            tokenUri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return Response<dynamic>(
        requestOptions: RequestOptions(path: tokenUri.path),
        data: httpResponse.body,
        statusCode: httpResponse.statusCode,
      );
    }

    final dio = _dioFor(tokenUri);
    final path = tokenUri.path.isEmpty ? '/' : tokenUri.path;
    return dio.post<dynamic>(
      path,
      data: body,
      queryParameters: tokenUri.queryParameters.isEmpty
          ? null
          : tokenUri.queryParameters,
      options: Options(
        headers: const {'Content-Type': 'application/json'},
        sendTimeout: _requestTimeout,
        receiveTimeout: _requestTimeout,
      ),
    );
  }

  Future<String?> getSignedUrl({
    required String channelId,
    required String originalUrl,
  }) async {
    final result = await fetchTokenResult(
      channelId: channelId,
      originalUrl: originalUrl,
    );
    return result?.streamUrl;
  }

  @visibleForTesting
  void clearCacheForTest() => _cache.clear();
}
