import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../security/encryption_helper.dart';
import '../security/security_config.dart';
import '../security/security_manager.dart';

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

  static Dio create({String? baseUrl}) {
    if (_instance != null) return _instance!;

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? SecurityConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
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
        client.badCertificateCallback = (cert, host, port) {
          if (SecurityConfig.certificatePins.isEmpty) {
            return false;
          }
          return _validatePin(cert);
        };
        return client;
      };
      dio.httpClientAdapter = adapter;
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            await SecurityManager.instance.assertSecureOrThrow();
          } catch (e) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: e,
                message: 'Network Error',
              ),
            );
          }

          if (SecurityConfig.hmacSecret.isNotEmpty) {
            _signRequest(options);
          }
          handler.next(options);
        },
      ),
    );

    _instance = dio;
    return dio;
  }

  static bool _validatePin(X509Certificate cert) {
    final pins = [
      ...SecurityConfig.certificatePins,
      ...SecurityConfig.certificateBackupPins,
    ];
    if (pins.isEmpty) return false;

    final der = cert.der;
    final digest = sha256.convert(der).bytes;
    final b64 = base64Encode(digest);
    return pins.contains(b64);
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
