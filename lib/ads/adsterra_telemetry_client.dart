import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/ad_config.dart';
import 'ad_log.dart';
import '../services/ad_safety_service.dart';

/// Private Adsterra event — not sent to Firebase.
class AdsterraTelemetryEvent {
  const AdsterraTelemetryEvent({
    required this.installId,
    required this.fingerprint,
    required this.placement,
    required this.format,
    required this.timestampMs,
    this.extra,
  });

  final String installId;
  final String fingerprint;
  final String placement;
  final String format;
  final int timestampMs;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'installId': installId,
      'fingerprint': fingerprint,
      'placement': placement,
      'format': format,
      'timestampMs': timestampMs,
    };
    final ex = extra;
    if (ex != null && ex.isNotEmpty) {
      map['extra'] = ex;
    }
    return map;
  }
}

abstract class AdsterraTelemetryClient {
  Future<void> send(AdsterraTelemetryEvent event);
}

/// Fire-and-forget POST; failures are logged once per process pattern.
class HttpAdsterraTelemetryClient implements AdsterraTelemetryClient {
  HttpAdsterraTelemetryClient({
    Dio? dioClient,
    String? baseUrl,
    String? hmacKey,
  })  : _dio = dioClient ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(milliseconds: 2000),
            receiveTimeout: const Duration(milliseconds: 2000),
            sendTimeout: const Duration(milliseconds: 2000),
          ),
        ),
        _url = (baseUrl ?? AdConfig.adsterraTelemetryUrl).trim(),
        _hmacKey = (hmacKey ?? AdConfig.adsterraTelemetryHmacKey).trim();

  final Dio _dio;
  final String _url;
  final String _hmacKey;

  @override
  Future<void> send(AdsterraTelemetryEvent event) async {
    if (_url.isEmpty || _hmacKey.isEmpty) return;

    final body = jsonEncode(event.toJson());
    final signature = _sign(body);
    final res = await _dio.post(
      _url,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Telemetry-Signature': signature,
        },
      ),
    );

    if (res.statusCode == null || res.statusCode! < 200 || res.statusCode! >= 300) {
      throw AdsterraTelemetryException('http_${res.statusCode}');
    }
  }

  String _sign(String body) => signBody(body, _hmacKey);

  @visibleForTesting
  static String signBody(String body, String hmacKey) {
    final key = utf8.encode(hmacKey);
    return Hmac(sha256, key).convert(utf8.encode(body)).toString();
  }
}

class AdsterraTelemetryException implements Exception {
  AdsterraTelemetryException(this.message);
  final String message;
  @override
  String toString() => 'AdsterraTelemetryException($message)';
}

/// Singleton — [report] never blocks callers.
class AdsterraTelemetryService {
  AdsterraTelemetryService._();
  static final AdsterraTelemetryService instance = AdsterraTelemetryService._();

  AdsterraTelemetryClient client = HttpAdsterraTelemetryClient();

  bool _loggedDisabled = false;
  bool _loggedFailure = false;
  bool _loggedSuccess = false;

  /// Unit tests only — bypass compile-time URL/key checks.
  @visibleForTesting
  bool debugForceConfigured = false;

  /// Unit tests only — skip [AdSafetyService.adsterraEnabled] gate.
  @visibleForTesting
  bool debugSkipAdsterraGate = false;

  bool get isConfigured =>
      debugForceConfigured ||
      (AdConfig.adsterraTelemetryUrl.isNotEmpty &&
          AdConfig.adsterraTelemetryHmacKey.isNotEmpty);

  void logConfigurationOnce() {
    if (_loggedDisabled) return;
    _loggedDisabled = true;
    if (AdConfig.adsterraTelemetryUrl.isEmpty) {
      adLog('[AdsterraTelemetry] disabled reason=ADSTERRA_TELEMETRY_URL unset');
      return;
    }
    if (AdConfig.adsterraTelemetryHmacKey.isEmpty) {
      adLog(
        '[AdsterraTelemetry] disabled reason=ADSTERRA_TELEMETRY_HMAC_KEY unset',
      );
    }
  }

  /// Release + debug when configured. Skips when Adsterra layer is off.
  void report({
    required String placement,
    required String format,
    Map<String, dynamic>? extra,
  }) {
    logConfigurationOnce();
    if (!isConfigured) return;
    if (!debugSkipAdsterraGate && !AdSafetyService.instance.adsterraEnabled) {
      return;
    }

    final event = AdsterraTelemetryEvent(
      installId: AdSafetyService.instance.installId,
      fingerprint: AdSafetyService.instance.deviceFingerprint,
      placement: placement,
      format: format,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      extra: extra,
    );

    unawaited(
      client.send(event).then((_) {
        if (_loggedSuccess) return;
        _loggedSuccess = true;
        adLog(
          '[AdsterraTelemetry] post_ok placement=$placement format=$format',
        );
      }).catchError((Object e) {
        if (_loggedFailure) return;
        _loggedFailure = true;
        adLog(
          '[AdsterraTelemetry] post_failed reason=$e '
          'placement=$placement format=$format',
        );
      }),
    );
  }

  @visibleForTesting
  void debugReset() {
    _loggedDisabled = false;
    _loggedFailure = false;
    _loggedSuccess = false;
    debugForceConfigured = false;
    debugSkipAdsterraGate = false;
  }
}
