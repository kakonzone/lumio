import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// Fetches scanned IPTV playlists at runtime (not bundled) to keep APK small.
class ScannedIptvService {
  ScannedIptvService._();

  static const _jioChannelsUrl = AppConfig.scannedIptvJioChannelsUrl;
  static const _scanPlaylistUrl = AppConfig.scannedIptvScanPlaylistUrl;
  static const _jioStreamBase = AppConfig.scannedIptvJioStreamBase;

  static const _timeout = Duration(seconds: 15);
  static const _ua = 'Mozilla/5.0 Lumio/1.0';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      headers: {'User-Agent': _ua},
    ),
  );

  static const _manualM3u = '''
#EXTM3U
#EXTINF:-1 group-title="English" ,National Geographic
http://202.70.146.135:8000/play/a05o/index.m3u8
#EXTINF:-1 group-title="Bangladesh" ,Discovery Bangla
http://202.70.146.135:8000/play/a05z/index.m3u8
#EXTINF:-1 group-title="Sports" ,Star Sports 1 Hindi
http://202.70.146.135:8000/play/a01e/index.m3u8
#EXTINF:-1 group-title="Sports" ,Star Sports Select 1 HD
http://202.70.146.135:8000/play/a03c/index.m3u8
#EXTINF:-1 group-title="Hindi" ,Zee Cafe HD
http://202.70.146.135:8000/play/a04n/index.m3u8
#EXTINF:-1 group-title="Movies" ,Colors Cineplex SD
http://202.70.146.135:8000/play/a01b/index.m3u8
#EXTINF:-1 group-title="Kids" ,Nick
http://202.70.146.135:8000/play/a04c/index.m3u8
''';

  static String? _cachedBody;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(hours: 6);

  /// Combined M3U text from JioTV API + custom scan server (+ manual extras).
  static Future<String?> fetchM3uBody({bool force = false}) async {
    if (!force &&
        _cachedBody != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedBody;
    }

    final parts = <String>[_manualM3u.trim()];

    if (AppConfig.hasScannedIptvScan) {
      try {
        final scan = await _dio.get(_scanPlaylistUrl);
        if (scan.statusCode == 200 && (scan.data as String).contains('#EXTM3U')) {
          parts.add((scan.data as String).trim());
        }
      } catch (_) {}
    }

    if (AppConfig.hasScannedIptvJio) {
      try {
        final jio = await _dio.get(_jioChannelsUrl);
        if (jio.statusCode == 200) {
          final m3u = _jioJsonToM3u(jio.data as String);
          if (m3u.isNotEmpty) parts.add(m3u);
        }
      } catch (_) {}
    }

    if (parts.length <= 1 && parts.first == _manualM3u.trim()) {
      return null;
    }

    final body = parts.join('\n');
    _cachedBody = body;
    _cachedAt = DateTime.now();
    return body;
  }

  static String _jioJsonToM3u(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rows = decoded['result'] as List<dynamic>? ?? [];
      final lines = <String>['#EXTM3U'];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final name = _cleanName('${row['channel_name'] ?? ''}');
        final id = '${row['channel_id'] ?? ''}'.trim();
        if (name.isEmpty || id.isEmpty) continue;
        final group = _jioCategory(row['channelCategoryId']);
        final url = _jioStreamBase.replaceAll('{id}', id);
        lines.add('#EXTINF:-1 group-title="$group" ,$name');
        lines.add(url);
      }
      return lines.length > 1 ? lines.join('\n') : '';
    } catch (_) {
      return '';
    }
  }

  static String _cleanName(String raw) {
    var name = raw.trim();
    name = name.replaceAll(
        RegExp(r'\s*-\s*Rs\s+[\d.]+\s*$', caseSensitive: false), '');
    if (name.startsWith(' ')) name = name.trimLeft();
    return name.trim().replaceFirst(RegExp(r'^\s*&'), '&');
  }

  static String _jioCategory(dynamic catId) {
    switch (catId) {
      case 6:
        return 'Movies';
      case 7:
        return 'Sports';
      case 8:
      case 16:
        return 'News';
      case 9:
        return 'Kids';
      case 12:
        return 'Music';
      default:
        return 'Entertainment';
    }
  }
}
