import 'dart:io';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../config/app_update_config.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.apkFileId,
    this.forceUpdate = false,
    this.updatedAt,
  });

  final String version;
  final String apkFileId;
  final bool forceUpdate;
  final DateTime? updatedAt;
}

/// Sideload update via Appwrite `app_version` + Storage bucket (no Play Store).
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  late final Client _client = Client()
      .setEndpoint(AppUpdateConfig.endpoint)
      .setProject(AppUpdateConfig.projectId);

  late final Databases _databases = Databases(_client);

  String? _currentVersion;

  Future<String> currentVersion() async {
    _currentVersion ??= (await PackageInfo.fromPlatform()).version;
    return _currentVersion!;
  }

  Future<AppVersionInfo?> fetchLatestVersion() async {
    if (!AppUpdateConfig.isConfigured) return null;
    try {
      final doc = await _databases.getDocument(
        databaseId: AppUpdateConfig.databaseId,
        collectionId: AppUpdateConfig.collectionId,
        documentId: AppUpdateConfig.versionDocumentId,
      );
      final data = Map<String, dynamic>.from(doc.data);
      final version = _str(data, 'version');
      final apkFileId = _str(data, 'apk_file_id');
      if (version.isEmpty || apkFileId.isEmpty) return null;

      final info = AppVersionInfo(
        version: version,
        apkFileId: apkFileId,
        forceUpdate: data['force_update'] == true,
        updatedAt: _parseDate(data['updated_at']),
      );
      return info;
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('[AppUpdate] fetch failed: ${e.message} (code=${e.code})');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppUpdate] fetch failed: $e');
      return null;
    }
  }

  Future<bool> isUpdateAvailable() async {
    try {
      final remote = await fetchLatestVersion();
      if (remote == null) return false;
      final current = await currentVersion();
      return isNewerVersion(remote.version, current);
    } catch (_) {
      return false;
    }
  }

  String buildDownloadUrl(String fileId) {
    final base = AppUpdateConfig.endpoint.replaceAll(RegExp(r'/+$'), '');
    return '$base/storage/buckets/${AppUpdateConfig.bucketId}/files/$fileId/download'
        '?project=${AppUpdateConfig.projectId}';
  }

  Future<String?> downloadApk(
    String fileId, {
    void Function(double progress)? onProgress,
  }) async {
    if (!Platform.isAndroid) return null;
    final url = buildDownloadUrl(fileId);
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/lumio_update.apk';

    final file = File(savePath);
    if (file.existsSync()) {
      await file.delete();
    }

    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 20),
          headers: const {'Accept': '*/*'},
        ),
      );
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          onProgress?.call(received / total);
        },
      );
      return savePath;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppUpdate] download failed: $e');
      return null;
    }
  }

  Future<bool> installApk(String filePath) async {
    if (!Platform.isAndroid) return false;
    try {
      if (!await _ensureInstallPermission()) return false;
      final result = await OpenFile.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (e) {
      if (kDebugMode) debugPrint('[AppUpdate] install failed: $e');
      return false;
    }
  }

  Future<bool> _ensureInstallPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await ph.Permission.requestInstallPackages.status;
    if (status.isGranted) return true;
    final requested = await ph.Permission.requestInstallPackages.request();
    return requested.isGranted;
  }

  @visibleForTesting
  static bool isNewerVersion(String remote, String current) {
    final r = _parts(remote);
    final c = _parts(current);
    final len = r.length > c.length ? r.length : c.length;
    for (var i = 0; i < len; i++) {
      final rv = i < r.length ? r[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return version
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  static String _str(Map<String, dynamic> data, String key) =>
      (data[key] as String? ?? '').trim();

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
