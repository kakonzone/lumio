import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/realtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Force-update manifest from Appwrite Database with realtime subscription.
/// Falls back to Cloudflare Pages if Appwrite is not configured.
class UpdateService {
  UpdateService._();

  // Appwrite configuration
  static const String appwriteEndpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: '',
  );
  static const String appwriteProjectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '',
  );
  static const String appwriteDatabaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: '',
  );
  static const String appwriteCollectionId = String.fromEnvironment(
    'APPWRITE_VERSION_COLLECTION_ID',
    defaultValue: '',
  );
  static const String appwriteVersionDocId = String.fromEnvironment(
    'APPWRITE_VERSION_DOC_ID',
    defaultValue: '',
  );

  // Fallback to Cloudflare Pages
  static const String versionUrl = String.fromEnvironment(
    'FORCE_UPDATE_VERSION_URL',
    defaultValue: 'https://lumio.me/version.json',
  );

  /// Users download APK from the site (not a direct GitHub link in-app).
  static const String downloadPageUrl = String.fromEnvironment(
    'FORCE_UPDATE_DOWNLOAD_PAGE_URL',
    defaultValue: 'https://lumio.me/',
  );

  static Client? _appwriteClient;
  static Realtime? _realtime;
  static RealtimeSubscription? _subscription;
  static String? _cachedLatestVersion;
  static String? _cachedDownloadUrl;

  static bool get isAppwriteConfigured =>
      appwriteEndpoint.isNotEmpty &&
      appwriteProjectId.isNotEmpty &&
      appwriteDatabaseId.isNotEmpty &&
      appwriteCollectionId.isNotEmpty &&
      appwriteVersionDocId.isNotEmpty;

  /// Initialize Appwrite realtime subscription for version updates.
  static Future<void> initialize() async {
    if (!isAppwriteConfigured) {
      debugPrint('[UpdateService] Appwrite not configured, using fallback');
      return;
    }

    try {
      _appwriteClient = Client()
        ..setEndpoint(appwriteEndpoint)
        ..setProject(appwriteProjectId);

      _realtime = Realtime(_appwriteClient!);

      // Subscribe to version document updates
      _subscription = _realtime!.subscribe(
        'databases.$appwriteDatabaseId.collections.$appwriteCollectionId.documents.$appwriteVersionDocId',
      );

      // Listen for updates
      _subscription!.stream.listen(
        (event) {
          debugPrint('[UpdateService] Version update received: ${event.payload}');
          _handleVersionUpdate(event.payload);
        },
        onError: (error) {
          debugPrint('[UpdateService] Realtime error: $error');
        },
      );

      // Fetch initial version
      await _fetchVersionFromAppwrite();

      debugPrint('[UpdateService] Appwrite realtime subscription initialized');
    } catch (e) {
      debugPrint('[UpdateService] Failed to initialize Appwrite: $e');
    }
  }

  static Future<void> _fetchVersionFromAppwrite() async {
    if (!isAppwriteConfigured || _appwriteClient == null) return;

    try {
      final databases = Databases(_appwriteClient!);
      final document = await databases.getDocument(
        databaseId: appwriteDatabaseId,
        collectionId: appwriteCollectionId,
        documentId: appwriteVersionDocId,
      );

      final data = document.data;
      _cachedLatestVersion = data['version'] as String?;
      _cachedDownloadUrl = data['downloadUrl'] as String?;

      debugPrint('[UpdateService] Fetched version from Appwrite: $_cachedLatestVersion');
    } catch (e) {
      debugPrint('[UpdateService] Failed to fetch version from Appwrite: $e');
    }
  }

  static void _handleVersionUpdate(Map<String, dynamic> payload) {
    final data = payload;
    final newVersion = data['version'] as String?;
    final newDownloadUrl = data['downloadUrl'] as String?;

    if (newVersion != null && newVersion.isNotEmpty) {
      _cachedLatestVersion = newVersion;
      _cachedDownloadUrl = newDownloadUrl;
      debugPrint('[UpdateService] New version cached: $newVersion');
    }
  }

  static void dispose() {
    _subscription?.close();
    _realtime?.close();
    _subscription = null;
    _realtime = null;
    _appwriteClient = null;
  }

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
    String? latestVersion;

    // Try Appwrite first if configured
    if (isAppwriteConfigured && _cachedLatestVersion != null) {
      latestVersion = _cachedLatestVersion;
    } else if (isAppwriteConfigured) {
      await _fetchVersionFromAppwrite();
      latestVersion = _cachedLatestVersion;
    }

    // Fallback to HTTP if Appwrite not available or fails
    if (latestVersion == null) {
      latestVersion = await _fetchPendingUpdateFromHttp();
    }

    if (latestVersion == null || latestVersion.isEmpty) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    if (!isNewerVersion(latestVersion, packageInfo.version)) return null;

    return latestVersion;
  }

  static Future<String?> _fetchPendingUpdateFromHttp() async {
    try {
      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;

      final latestVersion = (data['version'] as String? ?? '').trim();
      if (latestVersion.isEmpty) return null;

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
    final downloadUrl = _cachedDownloadUrl ?? downloadPageUrl;

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
            'ডাউনলোড করতে নিচের বাটন চাপুন — তারপর নতুন APK ইনস্টল করুন।',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
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
}
