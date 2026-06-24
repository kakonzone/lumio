import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Force-update manifest from Cloudflare Pages (`web/version.json` → lumio.me).
class UpdateService {
  UpdateService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  static const String versionUrl = String.fromEnvironment(
    'FORCE_UPDATE_VERSION_URL',
    defaultValue: 'https://lumio.me/version.json',
  );

  /// Users download APK from the site (not a direct GitHub link in-app).
  static const String downloadPageUrl = String.fromEnvironment(
    'FORCE_UPDATE_DOWNLOAD_PAGE_URL',
    defaultValue: 'https://lumio.me/',
  );

  /// Returns true when the user must update before continuing (dialog shown).
  static Future<bool> blocksNavigation(BuildContext context) async {
    final pending = await _fetchPendingUpdate();
    if (pending == null) return false;
    if (!context.mounted) return false;
    _showForceUpdateDialog(context, pending);
    return true;
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    final pending = await _fetchPendingUpdate();
    if (pending == null) return;
    if (!context.mounted) return;
    _showForceUpdateDialog(context, pending);
  }

  static Future<String?> _fetchPendingUpdate() async {
    try {
      final response = await _dio.get(versionUrl);
      if (response.statusCode != 200) return null;

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;

      final latestVersion = (data['version'] as String? ?? '').trim();
      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      if (!isNewerVersion(latestVersion, packageInfo.version)) return null;

      return latestVersion;
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static bool isNewerVersion(String latest, String current) {
    final l = _parts(latest);
    final c = _parts(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static List<int> _parts(String version) {
    return version
        .split('+')[0] // Remove build number if present
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
  }

  static void _showForceUpdateDialog(BuildContext context, String version) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) SystemNavigator.pop();
        },
        child: AlertDialog(
          title: const Text(
            '⚠️ আপডেট করা আবশ্যক!',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'নতুন Version $version পাওয়া গেছে।\n\n'
            'lumio.me তে গিয়ে ডাউনলোড বাটন চাপুন — তারপর নতুন APK ইনস্টল করুন।',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                final uri = Uri.parse(downloadPageUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text(
                'আপডেট করুন',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> initialize() async {
    // No-op for now, Appwrite integration is done via CI/CD script
  }

  static void dispose() {
    // No-op
  }
}
