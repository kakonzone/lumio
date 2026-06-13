import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/channel_categories.dart';
import '../models/model.dart';
import '../network/secure_dio.dart';
import '../utils/m3u_merge_parser.dart';

/// Fetches channel catalog from GitHub M3U playlist (replaces bundled list when available).
class RemoteChannelsService {
  RemoteChannelsService._();

  static const _cacheTtl = Duration(minutes: 30);
  static const _timeout = Duration(seconds: 10);
  static const _maxAttempts = 3;

  static List<ChannelModel>? _cached;
  static DateTime? _cachedAt;
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
    if (!force && _cacheFresh) return List<ChannelModel>.from(_cached!);

    final uri = Uri.tryParse(channelsUrl);
    if (uri == null || uri.scheme != 'https') {
      if (kDebugMode) {
        debugPrint('[RemoteChannels] invalid REMOTE_CHANNELS_URL');
      }
      return const [];
    }

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final channels = await _fetchOnce(uri);
        if (channels.isNotEmpty) {
          _cached = channels;
          _cachedAt = DateTime.now();
          return List<ChannelModel>.from(channels);
        }
        return const [];
      } catch (e) {
        if (attempt == _maxAttempts - 1) {
          if (kDebugMode) debugPrint('[RemoteChannels] fetch exception: $e');
          return const [];
        }
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    return const [];
  }

  static Future<List<ChannelModel>> _fetchOnce(Uri uri) async {
    final dio = _dio();
    final path = uri.path.isEmpty ? '/' : uri.path;
    final headers = <String, dynamic>{'Accept': 'text/plain'};
    if (_etag != null && _etag!.isNotEmpty) {
      headers['If-None-Match'] = _etag!;
    }

    final response = await dio.get<dynamic>(
      path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
      options: Options(
        headers: headers,
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        validateStatus: (code) => code != null && (code == 200 || code == 304),
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 304 && _cached != null) {
      _cachedAt = DateTime.now();
      return List<ChannelModel>.from(_cached!);
    }
    if (status != 200) {
      if (kDebugMode) {
        debugPrint('[RemoteChannels] fetch failed http=$status');
      }
      return const [];
    }

    final etagHeader = response.headers.value('etag');
    if (etagHeader != null && etagHeader.isNotEmpty) {
      _etag = etagHeader;
    }

    if (response.data is! String) {
      if (kDebugMode) debugPrint('[RemoteChannels] expected M3U text');
      return const [];
    }

    // Parse M3U using existing M3uMergeParser
    final m3uContent = response.data as String;
    try {
      final channels = M3uMergeParser.parse(
        m3uContent,
        idPrefix: 'github',
        mapCategory: ChannelCategoryRegistry.fromGroupTitle,
      );
      return channels;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RemoteChannels] M3U parse error: $e');
      }
      return const [];
    }
  }

  static bool get _cacheFresh =>
      _cached != null &&
      _cachedAt != null &&
      DateTime.now().difference(_cachedAt!) < _cacheTtl;

  @visibleForTesting
  static void clearCacheForTest() {
    _cached = null;
    _cachedAt = null;
    _etag = null;
    dioOverrideForTest = null;
    urlOverrideForTest = null;
  }
}
