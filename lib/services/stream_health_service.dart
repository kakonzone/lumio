import 'package:http/http.dart' as http;
import '../models/model.dart';

/// Parallel m3u8 reachability checks for LIVE badges.
class StreamHealthService {
  static const _timeout = Duration(seconds: 5);
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0';

  /// Returns channel id → any stream URL reachable (HTTP 200/206).
  static Future<Map<String, bool>> checkChannels(
    List<ChannelModel> channels,
  ) async {
    if (channels.isEmpty) return {};

    final results = await Future.wait(
      channels.map((ch) async {
        final ok = await isChannelActive(ch);
        return MapEntry(ch.id, ok);
      }),
    );
    return Map.fromEntries(results);
  }

  /// True if primary or any alternate m3u8 responds.
  static Future<bool> isChannelActive(
    ChannelModel channel, {
    Duration timeout = _timeout,
  }) async {
    final links = channel.allStreams;
    if (links.isEmpty) return false;
    for (final link in links) {
      if (link.url.isEmpty) continue;
      if (await isUrlActive(link.url, headers: link.headers, timeout: timeout)) {
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

    final httpHeaders = <String, String>{
      'User-Agent': _ua,
      ...?headers,
    };

    try {
      final head = await http
          .head(uri, headers: httpHeaders)
          .timeout(timeout);
      if (head.statusCode == 200 || head.statusCode == 206) return true;
    } catch (_) {}

    try {
      final get = await http
          .get(
            uri,
            headers: {
              ...httpHeaders,
              'Range': 'bytes=0-0',
            },
          )
          .timeout(timeout);
      return get.statusCode == 200 || get.statusCode == 206;
    } catch (_) {
      return false;
    }
  }
}
