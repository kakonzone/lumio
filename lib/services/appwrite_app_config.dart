import 'dart:convert';

import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:flutter/foundation.dart';

import '../config/appwrite_config.dart';
import 'appwrite_service.dart';

/// One `app_config` row — single network round-trip for payload + timestamp.
class AppConfigEntry {
  const AppConfigEntry({
    this.payload,
    this.updatedAt,
    this.errorMessage,
    this.errorCode,
  });

  final Map<String, dynamic>? payload;
  final String? updatedAt;
  final String? errorMessage;
  final int? errorCode;
}

/// Reads `app_config` rows (`key`, `json_payload`, `updated_at`) from Appwrite.
class AppwriteAppConfig {
  AppwriteAppConfig._();

  static final AppwriteAppConfig instance = AppwriteAppConfig._();

  Databases get _databases => AppwriteService.instance.databases;

  /// Fetches row once (payload + `updated_at` + error info).
  Future<AppConfigEntry?> fetchEntry(String key) async {
    final result = await _fetchRowResult(key);
    if (result.row == null) {
      return AppConfigEntry(
        errorMessage: result.errorMessage,
        errorCode: result.errorCode,
      );
    }
    final row = result.row!;
    return AppConfigEntry(
      payload: _parseJsonPayload(row),
      updatedAt: _readUpdatedAt(row),
      errorMessage: result.errorMessage,
      errorCode: result.errorCode,
    );
  }

  /// Parsed JSON object from `json_payload` for [key], or null if missing/invalid.
  Future<Map<String, dynamic>?> fetchJsonPayload(String key) async {
    final entry = await fetchEntry(key);
    return entry?.payload;
  }

  Future<_AppConfigRowResult> _fetchRowResult(String key) async {
    if (!AppwriteConfig.isConfigured) {
      return const _AppConfigRowResult(
        errorMessage: 'Appwrite project/database not configured',
      );
    }
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return const _AppConfigRowResult(errorMessage: 'app_config key is empty');
    }

    try {
      final page = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.appConfigCollectionId,
        queries: [
          Query.equal('key', trimmed),
          Query.limit(1),
        ],
      );
      if (page.documents.isNotEmpty) {
        return _AppConfigRowResult(
          row: Map<String, dynamic>.from(page.documents.first.data),
        );
      }

      // Fallback: document ID may match `key` (e.g. $id = featured_live_events).
      try {
        final doc = await _databases.getDocument(
          databaseId: AppwriteConfig.databaseId,
          collectionId: AppwriteConfig.appConfigCollectionId,
          documentId: trimmed,
        );
        return _AppConfigRowResult(
          row: Map<String, dynamic>.from(doc.data),
        );
      } on AppwriteException catch (e) {
        return _AppConfigRowResult(
          errorMessage: _friendlyConfigError(e, trimmed),
          errorCode: e.code,
        );
      }
    } on AppwriteException catch (e) {
      if (kDebugMode) {
        debugPrint('[Appwrite] app_config $key: ${e.message} (code=${e.code})');
      }
      return _AppConfigRowResult(
        errorMessage: _friendlyConfigError(e, trimmed),
        errorCode: e.code,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Appwrite] app_config $key failed: $e');
      }
      return _AppConfigRowResult(errorMessage: e.toString());
    }
  }

  static String _friendlyConfigError(AppwriteException e, String key) {
    if (e.code == 401) {
      return 'Appwrite app_config: permission denied (401). '
          'Console → iptv_main → app_config → Permissions → Read for Guests. '
          'Row key or document id: $key';
    }
    if (e.code == 402 || e.type == 'limit_databases_reads_exceeded') {
      return 'Appwrite rate limit exceeded. Using cached data or bundled fallback.';
    }
    return e.message ?? 'Appwrite app_config error (code=${e.code})';
  }

  Map<String, dynamic>? _parseJsonPayload(Map<String, dynamic> row) {
    final raw = row['json_payload'] ?? row['jsonPayload'];
    if (raw == null) return null;

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String? _readUpdatedAt(Map<String, dynamic> row) {
    final raw = row['updated_at'] ?? row['updatedAt'];
    if (raw == null) return null;
    return raw.toString().trim();
  }
}

class _AppConfigRowResult {
  const _AppConfigRowResult({this.row, this.errorMessage, this.errorCode});

  final Map<String, dynamic>? row;
  final String? errorMessage;
  final int? errorCode;
}
