import 'dart:convert';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_config.dart';
import '../models/app_config_model.dart';

/// Fetches `global_config` from the main Appwrite project (remote control).
class AppConfigService {
  AppConfigService._();

  static final AppConfigService instance = AppConfigService._();

  static const _prefKey = 'lumio_global_app_config_v1';
  static const _prefCachedAtKey = 'lumio_global_app_config_cached_at_v1';

  late final Client _client = Client()
      .setEndpoint(AppwriteConfig.mainEndpoint)
      .setProject(AppwriteConfig.mainProjectId);

  late final Databases _databases = Databases(_client);

  AppConfigModel _cached = AppConfigModel.defaultConfig();
  bool _loadedFromDisk = false;

  AppConfigModel get cachedConfig => _cached;

  Future<AppConfigModel> fetchConfig({bool forceRefresh = false}) async {
    if (!AppwriteConfig.mainProjectConfigured) {
      if (kDebugMode) {
        debugPrint(
            '[AppConfig] main project not configured — using cache/defaults');
      }
      return _loadCacheOrDefault();
    }

    if (!forceRefresh && _loadedFromDisk) {
      return _cached;
    }

    try {
      final doc = await _databases.TablesDB.getRow(
        databaseId: AppwriteConfig.mainDatabaseId,
        tableId: AppwriteConfig.appConfigCollectionId,
        rowId: AppwriteConfig.globalConfigDocumentId,
      );
      final model = AppConfigModel.fromMap(
        Map<String, dynamic>.from(doc.data),
      );
      _cached = model;
      _loadedFromDisk = true;
      await _persistCache(model);
      if (kDebugMode) {
        debugPrint(
            '[AppConfig] fetched global_config updated_at=${model.updatedAt}');
      }
      return model;
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('[AppConfig] Appwrite error: ${e.message} (code=${e.code})');
      }
      return _loadCacheOrDefault();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppConfig] fetch failed: $e');
      }
      return _loadCacheOrDefault();
    }
  }

  Future<AppConfigModel> _loadCacheOrDefault() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    final cachedAtMs = prefs.getInt(_prefCachedAtKey);

    if (raw != null && raw.isNotEmpty && cachedAtMs != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
      if (age < AppwriteConfig.globalConfigCacheTtl.inMilliseconds) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _cached = AppConfigModel.fromMap(decoded);
            _loadedFromDisk = true;
            if (kDebugMode) {
              debugPrint('[AppConfig] using SharedPreferences cache');
            }
            return _cached;
          }
        } catch (_) {
          // fall through to defaults
        }
      }
    }

    _cached = AppConfigModel.defaultConfig();
    _loadedFromDisk = true;
    return _cached;
  }

  Future<void> _persistCache(AppConfigModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(model.toJson()));
    await prefs.setInt(
      _prefCachedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
