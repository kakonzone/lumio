import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Discovers `.m3u` / `.m3u8` files in a public GitHub repo (GITUN third-party).
class GitunRepoDiscovery {
  GitunRepoDiscovery._();

  static final _datedSnapshot = RegExp(r'\.\d{2}\.\d{2}\.\d{4}\.');

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'LumioTV/1.0',
      },
    ),
  );

  /// GitHub blob URLs for playlist files on [branch] (skips dated snapshot copies).
  static Future<List<String>> discoverPlaylistBlobUrls({
    required String owner,
    required String repo,
    String branch = 'main',
  }) async {
    final api =
        'https://api.github.com/repos/$owner/$repo/contents/?ref=$branch';
    try {
      final res = await _dio.get(api);

      if (res.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('[GITUN] repo list failed $api http=${res.statusCode}');
        }
        return const [];
      }

      final list = res.data as List<dynamic>;
      final urls = <String>[];
      for (final item in list) {
        if (item is! Map) continue;
        final name = (item['name'] as String?)?.trim() ?? '';
        final lower = name.toLowerCase();
        if (!lower.endsWith('.m3u') && !lower.endsWith('.m3u8')) continue;
        if (_datedSnapshot.hasMatch(name)) continue;
        urls.add(
          'https://github.com/$owner/$repo/blob/$branch/$name',
        );
      }
      urls.sort();
      if (kDebugMode) {
        debugPrint(
            '[GITUN] discovered ${urls.length} playlists in $owner/$repo');
      }
      return urls;
    } catch (e) {
      if (kDebugMode) debugPrint('[GITUN] discover error $owner/$repo: $e');
      return const [];
    }
  }
}
