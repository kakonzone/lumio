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

    if (!force && _cacheFresh && _cached != null) {
      if (kDebugMode) {
        debugPrint('[RemoteChannels] Returning ${_cached!.length} cached channels');
      }
      return List<ChannelModel>.from(_cached!);
    }

    final channels = await _fetchOnceWithRetry();

    if (kDebugMode) {
      debugPrint('[RemoteChannels] Fresh fetch returned ${channels.length} channels');
    }

    _cached = channels;
    _cachedAt = DateTime.now(); // BUG FIX: Set cache timestamp
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
      final dio = Dio(BaseOptions(
        baseUrl: '${uri.scheme}://${uri.host}',
      ));

      debugPrint('[RemoteChannels] Fetching from: $channelsUrl');

      final response = await dio.get<dynamic>(
        uri.path,
        queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'text/plain',
          },
          sendTimeout: _timeout,
          receiveTimeout: _timeout,
          validateStatus: (code) => code != null && (code == 200 || code == 304),
        ),
      );

      final status = response.statusCode ?? 0;
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
