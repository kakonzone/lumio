import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../security/security_config.dart';
import '../security/security_manager.dart';
import '../utils/retry.dart';
import 'secure_dio.dart';

/// স্বাক্ষরিত, স্বল্পমেয়াদি স্ট্রিম URL রিজলভার।
///
/// সরাসরি M3U8 ক্লায়েন্টে রাখবেন না — সার্ভার থেকে টোকেন নিয়ে প্লেয়ারে দিন।
///
/// **সার্ভার কন্ট্রাক্ট (উদাহরণ):**
/// `POST /v1/stream/token` → `{ "url": "https://cdn.../index.m3u8?token=...", "expiresAt": 123 }`
class StreamResolver {
  StreamResolver({Dio? dio}) : _dio = dio ?? SecureDio.create();

  final Dio _dio;

  /// চ্যানেল/ইভেন্ট আইডি দিয়ে স্বাক্ষরিত প্লেব্যাক URL
  Future<ResolvedStream> resolve({
    required String channelId,
    String? deviceId,
    Map<String, String>? extra,
  }) async {
    await SecurityManager.instance.assertSecureOrThrow();

    try {
      final result = await RetryHelper.retry(
        fn: () => _fetchStreamToken(channelId, deviceId, extra),
        maxAttempts: 3,
        initialDelayMs: 1000,
        maxDelayMs: 10000,
        jitterFactor: 0.2,
        onRetry: (attempt, delay, error) {
          if (kDebugMode) {
            debugPrint('[StreamResolver] Retry attempt $attempt in ${delay}ms: $error');
          }
        },
        retryIf: RetryHelper.defaultRetryPredicate,
      );

      final data = result.data;
      if (data == null) throw const StreamResolverException('Network Error');

      final url = data['url'] as String?;
      final expiresAt = data['expiresAt'];
      if (url == null || url.isEmpty) {
        throw const StreamResolverException('Network Error');
      }

      DateTime? expiry;
      if (expiresAt is int) {
        expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt);
      } else if (expiresAt is String) {
        expiry = DateTime.tryParse(expiresAt);
      }

      return ResolvedStream(
        playbackUrl: url,
        expiresAt: expiry ?? DateTime.now().add(const Duration(minutes: 5)),
      );
    } on DioException catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[StreamResolver] $e\n$stack');
      }
      
      // Convert to appropriate error type
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw TimeoutError('Stream token request timed out');
      }
      
      if (e.type == DioExceptionType.connectionError) {
        throw HttpError('Network connection failed');
      }
      
      throw const StreamResolverException('Network Error');
    }
  }

  Future<Response<Map<String, dynamic>>> _fetchStreamToken(
    String channelId,
    String? deviceId,
    Map<String, String>? extra,
  ) async {
    return await _dio.post<Map<String, dynamic>>(
      SecurityConfig.streamTokenPath,
      data: {
        'channelId': channelId,
        if (deviceId != null) 'deviceId': deviceId,
        if (extra != null) 'meta': extra,
      },
    );
  }

  /// লোকাল/এমবেডেড চ্যানেল — টোকেন API না থাকলে ফলব্যাক (মাইগ্রেশন পর্যন্ত)
  Future<String> resolveOrFallback({
    required String channelId,
    required String embeddedUrl,
    String? deviceId,
  }) async {
    if (SecurityConfig.apiBaseUrl.contains('example.com')) {
      return embeddedUrl;
    }
    try {
      final resolved = await resolve(channelId: channelId, deviceId: deviceId);
      return resolved.playbackUrl;
    } catch (_) {
      return embeddedUrl;
    }
  }
}

class ResolvedStream {
  final String playbackUrl;
  final DateTime expiresAt;

  const ResolvedStream({
    required this.playbackUrl,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class StreamResolverException implements Exception {
  final String message;
  const StreamResolverException(this.message);

  @override
  String toString() => message;
}
