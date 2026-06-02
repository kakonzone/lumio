import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.remoteVersion,
    required this.apkUrl,
    this.message = '',
  });

  final String remoteVersion;
  final String apkUrl;
  final String message;
}

/// Sideload update check — no Play Store.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!AppConfig.hasAppUpdateManifest) return null;
    final uri = Uri.tryParse(AppConfig.appUpdateManifestUrl.trim());
    if (uri == null || uri.scheme != 'https') return null;

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final remoteVersion = (decoded['version'] as String? ?? '').trim();
      final apkUrl = (decoded['apk_url'] as String? ?? '').trim();
      if (remoteVersion.isEmpty || apkUrl.isEmpty) return null;

      final package = await PackageInfo.fromPlatform();
      if (!isNewerVersion(remoteVersion, package.version)) return null;

      return AppUpdateInfo(
        remoteVersion: remoteVersion,
        apkUrl: apkUrl,
        message: (decoded['message'] as String? ?? '').trim(),
      );
    } catch (e) {
      debugPrint('[AppUpdate] check failed: $e');
      return null;
    }
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

  Future<void> showUpdateDialogIfNeeded(BuildContext context) async {
    final info = await checkForUpdate();
    if (info == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          info.message.isNotEmpty
              ? info.message
              : 'Version ${info.remoteVersion} is available. Download the latest APK to get fixes and World Cup improvements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.tryParse(info.apkUrl);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Download APK'),
          ),
        ],
      ),
    );
  }
}
