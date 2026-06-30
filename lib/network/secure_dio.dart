import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb, visibleForTesting;

import '../security/security_config.dart';
import '../security/encryption_helper.dart';
import '../security/security_manager.dart';
import '../security/ssl_pinning.dart';

/// সার্টিফিকেট-পিনড Dio ক্লায়েন্ট + HMAC সাইনড রিকোয়েস্ট।
///
/// **ব্যবহার:**
/// ```dart
/// final dio = SecureDio.create();
/// final res = await dio.get('/v1/channels');
/// ```
class SecureDio {
  SecureDio._();

  static Dio? _instance;
  static final Map<String, Dio> _pinnedByBase = {};

  /// Default singleton for [SecurityConfig.apiBaseUrl] (HMAC + security assert).
  static Dio create({String? baseUrl}) {
    if (_instance != null) return _instance!;

    final dio = _buildPinnedDio(
      baseUrl: baseUrl ?? SecurityConfig.apiBaseUrl,
      assertSecurity: true,
      signRequests: SecurityConfig.hmacSecret.isNotEmpty,
    );

    _instance = dio;
    return dio;
  }

  /// Per-host pinned client (stream token API, remote channels Worker, etc.).
  static Dio createForBaseUrl(
    String baseUrl, {
    bool assertSecurity = false,
    bool signRequests = false,
  }) {
    final normalized = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final cached = _pinnedByBase[normalized];
    if (cached != null) return cached;

    final dio = _buildPinnedDio(
      baseUrl: normalized,
      assertSecurity: assertSecurity,
      signRequests: signRequests,
    );
    _pinnedByBase[normalized] = dio;
    return dio;
  }

  @visibleForTesting
  static void clearPinnedCacheForTest() {
    _instance = null;
    _pinnedByBase.clear();
  }

  static Dio _buildPinnedDio({
    required String baseUrl,
    required bool assertSecurity,
    required bool signRequests,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (!kIsWeb) {
      final adapter = IOHttpClientAdapter();
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) {
          // Chain validation failures are never accepted.
          return false;
        };
        return client;
      };
      adapter.validateCertificate = (cert, host, port) {
        return SslPinning.validateCertificate(cert, host);
      };
      dio.httpClientAdapter = adapter;
    }

    if (assertSecurity || signRequests) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (assertSecurity) {
              try {
                await SecurityManager.instance.assertSecureOrThrow();
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('[SecureDio] Security check failed for ${options.uri.host}: $e');
                }
                return handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.cancel,
                    error: e,
                    message: 'Network Error',
                  ),
                );
              }
            }

            if (signRequests && SecurityConfig.hmacSecret.isNotEmpty) {
              _signRequest(options);
            }
            handler.next(options);
          },
        ),
      );
    }

    return dio;
  }

  static void _signRequest(RequestOptions options) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final nonce = EncryptionHelper.randomNonce();
    final body = options.data is String
        ? options.data as String
        : options.data != null
            ? jsonEncode(options.data)
            : '';
    final path = options.uri.path;
    final payload = EncryptionHelper.buildSigningPayload(
      timestampMs: ts,
      nonce: nonce,
      method: options.method.toUpperCase(),
      path: path,
      body: body,
    );
    final sig = EncryptionHelper.hmacSha256Hex(
      payload,
      SecurityConfig.hmacSecret,
    );
    options.headers['X-Lumio-Timestamp'] = ts.toString();
    options.headers['X-Lumio-Nonce'] = nonce;
    options.headers['X-Lumio-Signature'] = sig;
  }
}
