import 'package:dio/dio.dart';
import '../models/model.dart';

/// Parallel m3u8 reachability checks for LIVE badges.
class StreamHealthService {
  static const _timeout = Duration(seconds: 5);
  static const _playerProbeTimeout = Duration(seconds: 2);
  static const _cacheDuration = Duration(minutes: 2);
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: {'User-Agent': _ua},
    ),
  );

  static final Map<String, (bool, DateTime)> _healthCache = {};

  /// Returns channel id → any stream URL reachable (HTTP 200/206).
  static Future<Map<String, bool>> checkChannels(
    List<ChannelModel> channels, {
    Duration timeout = _timeout,
  }) async {
    if (channels.isEmpty) return {};

    final results = await Future.wait(
      channels.map((ch) async {
        final ok = await isChannelActive(ch, timeout: timeout);
        return MapEntry(ch.id, ok);
      }),
    );
    return Map.fromEntries(results);
  }

  /// Lighter checks for player "related" list (shorter timeout).
  static Future<Map<String, bool>> checkChannelsForPlayer(
    List<ChannelModel> channels,
  ) =>
      checkChannels(channels, timeout: _playerProbeTimeout);

  /// True if primary or any alternate m3u8 responds.
  static Future<bool> isChannelActive(
    ChannelModel channel, {
    Duration timeout = _timeout,
  }) async {
    final links = channel.allStreams;
    if (links.isEmpty) return false;
    for (final link in links) {
      if (link.url.isEmpty) continue;
      if (await isUrlActive(link.url,
          headers: link.headers, timeout: timeout)) {
        return true;
      }
    }
    return false;
  }

  static Future<bool> isUrlActive(
    String url, {
    Map<String, String>? headers,
    Duration timeout = _timeout,
  }) async {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    // Check cache first
    final cacheKey = '$url${headers?.toString() ?? ''}';
    final cached = _healthCache[cacheKey];
    if (cached != null) {
      final age = DateTime.now().difference(cached.$2);
      if (age < _cacheDuration) {
        return cached.$1;
      }
    }

    final httpHeaders = <String, String>{
      'User-Agent': _ua,
      ...?headers,
    };

    var result = false;
    try {
      final head = await _dio.head(uri.toString(), options: Options(headers: httpHeaders));
      if (head.statusCode == 200 || head.statusCode == 206) result = true;
    } catch (_) {}

    if (!result) {
      try {
        final get = await _dio.get(
          uri.toString(),
          options: Options(
            headers: {
              ...httpHeaders,
              'Range': 'bytes=0-0',
            },
          ),
        );
        result = get.statusCode == 200 || get.statusCode == 206;
      } catch (_) {}
    }

    // Cache result
    _healthCache[cacheKey] = (result, DateTime.now());
    return result;
  }
}
