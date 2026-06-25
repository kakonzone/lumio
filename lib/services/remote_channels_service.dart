import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/channel_categories.dart';
import '../models/model.dart';
import '../network/secure_dio.dart';
import '../utils/m3u_merge_parser.dart';
import '../utils/retry.dart';

/// Fetches channel catalog from GitHub M3U playlist (replaces bundled list when available).
class RemoteChannelsService {
  RemoteChannelsService._();

  static const _cacheTtl = Duration(minutes: 30);
  static const _timeout = Duration(seconds: 8);
  static const _maxAttempts = 3;

  static List<ChannelModel>? _cached;
  static DateTime? _cachedAt;
  static DateTime? _lastFetch;
  static String? _etag;

  @visibleForTesting
  static Dio? dioOverrideForTest;

  @visibleForTesting
  static String? urlOverrideForTest;

  static String get channelsUrl =>
      (urlOverrideForTest ?? AppConfig.remoteChannelsUrl).trim();

  static Dio _dio() {
    if (dioOverrideForTest != null) return dioOverrideForTest!;
    final uri = Uri.tryParse(channelsUrl);
    if (uri == null || uri.host.isEmpty) {
      return SecureDio.createForBaseUrl('https://invalid.local');
    }
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return SecureDio.createForBaseUrl(origin);
  }

  /// Returns cached channels when fresh; otherwise fetches from Worker.
  static Future<List<ChannelModel>> fetch({bool force = false}) async {
    if (kDebugMode) {
      debugPrint('[RemoteChannels] Fetching from: $channelsUrl');
      debugPrint('[RemoteChannels] Force refresh: $force');
      debugPrint('[RemoteChannels] Cache fresh: $_cacheFresh');
    }

    // Return cached data if fresh and non-empty
    if (!force && _cacheFresh && _cached != null && _cached!.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[RemoteChannels] Returning ${_cached!.length} cached channels');
      }
      return List<ChannelModel>.from(_cached!);
    }

    final channels = await _fetchOnceWithRetry();

    // Only update cache if fetch succeeded with non-empty list
    if (channels.isNotEmpty) {
      _cached = channels;
      _cachedAt = DateTime.now();
      if (kDebugMode) {
        debugPrint('[RemoteChannels] Cache updated with ${channels.length} channels');
      }
    } else {
      // Fallback to old cache if fetch failed
      if (_cached != null && _cached!.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[RemoteChannels] Fetch failed, returning stale cache (${_cached!.length} channels)');
        }
        return List<ChannelModel>.from(_cached!);
      }
    }

    _lastFetch = DateTime.now();
    return List<ChannelModel>.from(channels);
  }

  static Future<List<ChannelModel>> _fetchOnceWithRetry() async {
    return await RetryHelper.run(
      operation: _fetchOnce,
      maxAttempts: _maxAttempts,
      baseDelay: const Duration(milliseconds: 500),
      maxDelay: const Duration(seconds: 2),
    );
  }

  static Future<List<ChannelModel>> _fetchOnce() async {
    try {
      final uri = Uri.parse(channelsUrl);
      
      // BUG FIX: Use _dio() for SSL pinning instead of plain Dio
      final dio = _dio();

      debugPrint('[RemoteChannels] Fetching from: $channelsUrl');

      final headers = <String, String>{
        'Accept': 'text/plain',
      };
      
      // BUG FIX: Add ETag support for HTTP caching
      if (_etag != null) {
        headers['If-None-Match'] = _etag!;
      }

      final response = await dio.get<dynamic>(
        uri.path,
        queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (code) => code != null && (code == 200 || code == 304),
        ),
      );

      final status = response.statusCode ?? 0;
      
      // BUG FIX: Handle 304 Not Modified (content unchanged)
      if (status == 304 && _cached != null && _cached!.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[RemoteChannels] 304 Not Modified, returning cached channels');
        }
        return List<ChannelModel>.from(_cached!);
      }

      final m3uContent = response.data?.toString() ?? '';

      debugPrint('[RemoteChannels] HTTP status: $status');
      debugPrint('[RemoteChannels] Response length: ${m3uContent.length}');

      if (kDebugMode) {
        debugPrint('[RemoteChannels] Preview: ${m3uContent.substring(0, m3uContent.length > 300 ? 300 : m3uContent.length)}');
      }

      if (m3uContent.trim().isEmpty) {
        debugPrint('[RemoteChannels] Empty response body');
        return const [];
      }

      // BUG FIX: Store ETag from response headers
      final responseEtag = response.headers.value('etag');
      if (responseEtag != null) {
        _etag = responseEtag;
        if (kDebugMode) {
          debugPrint('[RemoteChannels] ETag stored: $_etag');
        }
      }

      // Parse in isolate to avoid blocking UI thread
      final channels = await compute(
        _parseM3uInIsolate,
        _M3uParseParams(
          content: m3uContent,
          idPrefix: 'github',
        ),
      );

      debugPrint('[RemoteChannels] Parser returned ${channels.length} channels');

      return channels;
    } catch (e, st) {
      // Log errors in both debug and release mode for troubleshooting
      debugPrint('[RemoteChannels] Fetch error: $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
      return const [];
    }
  }

  static List<ChannelModel> _parseM3uInIsolate(_M3uParseParams params) {
    return M3uMergeParser.parse(
      params.content,
      idPrefix: params.idPrefix,
      mapCategory: ChannelCategoryRegistry.fromGroupTitle,
    );
  }

  static bool get _cacheFresh =>
      _cached != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  @visibleForTesting
  static void clearCacheForTest() {
    _cached = null;
    _cachedAt = null;
    _lastFetch = null;
    _etag = null;
    dioOverrideForTest = null;
    urlOverrideForTest = null;
  }

  /// Clear cache for debugging GitHub source
  static void clearCache() {
    _cached = null;
    _cachedAt = null;
    _lastFetch = null;
    _etag = null;
  }
}

/// Parameters for M3U parsing in isolate
class _M3uParseParams {
  const _M3uParseParams({
    required this.content,
    required this.idPrefix,
  });

  final String content;
  final String idPrefix;
}
