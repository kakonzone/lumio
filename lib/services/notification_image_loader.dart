import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a remote image for Android Big Picture / iOS attachment notifications.
class NotificationImageLoader {
  NotificationImageLoader._();

  static const _timeout = Duration(seconds: 12);

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: _timeout,
      receiveTimeout: _timeout,
      sendTimeout: _timeout,
      responseType: ResponseType.bytes,
    ),
  );

  /// Returns a temp file path, or null if download fails.
  static Future<String?> downloadToCache(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;

    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200 || (response.data as List).isEmpty) {
        return null;
      }

      final ext = _extensionFromUri(uri, response.headers['content-type']?.first);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/lumio_notif_${uri.hashCode.abs()}.$ext';
      final file = File(path);
      await file.writeAsBytes(response.data as List<int>, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }

  static String _extensionFromUri(Uri uri, String? contentType) {
    final pathExt = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last.split('.').last.toLowerCase()
        : '';
    if (pathExt == 'jpg' ||
        pathExt == 'jpeg' ||
        pathExt == 'png' ||
        pathExt == 'webp' ||
        pathExt == 'gif') {
      return pathExt == 'jpeg' ? 'jpg' : pathExt;
    }
    final ct = contentType?.toLowerCase() ?? '';
    if (ct.contains('png')) return 'png';
    if (ct.contains('webp')) return 'webp';
    if (ct.contains('gif')) return 'gif';
    return 'jpg';
  }
}
