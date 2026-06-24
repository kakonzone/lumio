import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/model.dart';

/// Result of probing a URL for HTTPS availability.
class StreamProbeResult {
  final String originalUrl;
  final String? upgradedUrl;
  final StreamSecurity security;
  final bool isHttpsAvailable;
  final String? contentType;
  final DateTime probedAt;

  const StreamProbeResult({
    required this.originalUrl,
    this.upgradedUrl,
    required this.security,
    required this.isHttpsAvailable,
    this.contentType,
    required this.probedAt,
  });

  factory StreamProbeResult.unknown(String url) => StreamProbeResult(
        originalUrl: url,
        security: StreamSecurity.unknown,
        isHttpsAvailable: false,
        probedAt: DateTime.now(),
      );
}

/// Probes stream URLs to test HTTPS availability and content type.
class StreamSecurityProber {
  StreamSecurityProber._();

  static const _timeout = Duration(seconds: 10);
  static const _ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: {'User-Agent': _ua},
    ),
  );

  static const _streamContentTypes = [
    'application/x-mpegURL',
    'application/vnd.apple.mpegurl',
    'video/mp2t',
    'video/MP2T',
    'application/octet-stream',
    'text/plain',
  ];

  /// Probes a URL to check if HTTPS is available.
  ///
  /// For HTTP URLs, attempts to upgrade to HTTPS and validate:
  /// - 200 OK status
  /// - Content-Type matches stream MIME types
  ///
  /// Returns [StreamProbeResult] with security status.
  static Future<StreamProbeResult> probeUrl(String url) async {
    if (url.isEmpty) {
      return StreamProbeResult.unknown(url);
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return StreamProbeResult.unknown(url);
    }

    // Already HTTPS - just verify it's accessible
    if (uri.scheme == 'https') {
      return await _probeHttps(url);
    }

    // HTTP - try to upgrade to HTTPS
    if (uri.scheme == 'http') {
      return await _probeHttpUpgrade(url);
    }

    // Other schemes (rtmp, etc.) - mark as unknown
    return StreamProbeResult.unknown(url);
  }

  /// Probes an HTTPS URL to verify accessibility and content type.
  static Future<StreamProbeResult> _probeHttps(String url) async {
    try {
      final response = await _dio.head(url);

      final contentType = response.headers['content-type'];
      final isValidStream = _isValidStreamContentType(contentType);

      return StreamProbeResult(
        originalUrl: url,
        upgradedUrl: url,
        security: StreamSecurity.secure,
        isHttpsAvailable: response.statusCode == 200 && isValidStream,
        contentType: contentType,
        probedAt: DateTime.now(),
      );
    } catch (_) {
      // HTTPS probe failed - keep as secure but mark unavailable
      return StreamProbeResult(
        originalUrl: url,
        upgradedUrl: url,
        security: StreamSecurity.secure,
        isHttpsAvailable: false,
        probedAt: DateTime.now(),
      );
    }
  }

  /// Probes an HTTP URL by attempting HTTPS upgrade.
  static Future<StreamProbeResult> _probeHttpUpgrade(String httpUrl) async {
    final uri = Uri.parse(httpUrl);
    final httpsUrl = uri.replace(scheme: 'https').toString();

    try {
      final response = await http
          .head(Uri.parse(httpsUrl), headers: {'User-Agent': _ua})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'];
        final isValidStream = _isValidStreamContentType(contentType);

        if (isValidStream) {
          // HTTPS upgrade successful
          return StreamProbeResult(
            originalUrl: httpUrl,
            upgradedUrl: httpsUrl,
            security: StreamSecurity.secure,
            isHttpsAvailable: true,
            contentType: contentType,
            probedAt: DateTime.now(),
          );
        }
      }
    } catch (_) {
      // HTTPS upgrade failed
    }

    // HTTPS not available - mark as cleartext for manual review
    return StreamProbeResult(
      originalUrl: httpUrl,
      security: StreamSecurity.cleartext,
      isHttpsAvailable: false,
      probedAt: DateTime.now(),
    );
  }

  /// Checks if content type is valid for streaming.
  static bool _isValidStreamContentType(String? contentType) {
    if (contentType == null) return true; // Assume valid if missing

    final lower = contentType.toLowerCase();
    return _streamContentTypes.any((type) => lower.contains(type.toLowerCase()));
  }

  /// Bulk probe multiple URLs with concurrency limit.
  ///
  /// Returns map of original URL to probe result.
  static Future<Map<String, StreamProbeResult>> probeUrls(
    List<String> urls, {
    int concurrency = 5,
  }) async {
    final results = <String, StreamProbeResult>{};

    // Process in batches to limit concurrency
    for (int i = 0; i < urls.length; i += concurrency) {
      final batch = urls.skip(i).take(concurrency);
      final futures = batch.map((url) async {
        final result = await probeUrl(url);
        results[url] = result;
      });

      await Future.wait(futures);
    }

    return results;
  }

  /// Extracts all HTTP URLs from M3U playlist content.
  static List<String> extractHttpUrlsFromM3u(String m3uContent) {
    final urls = <String>[];
    final lines = LineSplitter.split(m3uContent);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('http://') && !trimmed.startsWith('#')) {
        urls.add(trimmed);
      }
    }

    return urls;
  }

  /// Upgrades HTTP URLs to HTTPS if probe confirms availability.
  ///
  /// Returns map of original URL to upgraded URL (or original if upgrade failed).
  static Future<Map<String, String>> upgradeHttpUrls(
    List<String> urls,
  ) async {
    final results = <String, String>{};
    final probeResults = await probeUrls(urls);

    for (final url in urls) {
      final result = probeResults[url];
      if (result != null && result.isHttpsAvailable && result.upgradedUrl != null) {
        results[url] = result.upgradedUrl!;
      } else {
        results[url] = url; // Keep original if upgrade failed
      }
    }

    return results;
  }
}
