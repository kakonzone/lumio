/// Appwrite — SGP Lumio project only (no API key in the app; Guests Read only).
///
/// **SGP Lumio** — all Appwrite functionality (channels, app_config, global_config, special_links).
library;

import 'package:flutter/foundation.dart';

class AppwriteConfig {
  AppwriteConfig._();

  /// Offline catalog cache TTL when Appwrite is unreachable.
  static const catalogCacheTtl = Duration(hours: 24);

  // ── SGP Lumio Project (Primary Appwrite Instance) ─────────────────────────────
  static const projectId = String.fromEnvironment(
    'APPWRITE_MAIN_PROJECT_ID',
    defaultValue: '',
  );

  static const endpoint = String.fromEnvironment(
    'APPWRITE_MAIN_ENDPOINT',
    defaultValue: '',
  );

  static const databaseId = String.fromEnvironment(
    'APPWRITE_MAIN_DATABASE_ID',
    defaultValue: '',
  );

  /// One document per channel (preferred for 4k+ rows).
  static const channelsCollectionId = String.fromEnvironment(
    'APPWRITE_MAIN_CHANNELS_COLLECTION_ID',
    defaultValue: 'channels',
  );

  /// Optional: single document holding full M3U text (fallback).
  static const playlistCollectionId = String.fromEnvironment(
    'APPWRITE_MAIN_PLAYLIST_COLLECTION_ID',
    defaultValue: 'playlists',
  );

  static const mainPlaylistDocumentId = String.fromEnvironment(
    'APPWRITE_MAIN_PLAYLIST_DOCUMENT_ID',
    defaultValue: 'main',
  );

  /// App config rows: `key`, `json_payload`, `updated_at` (featured cards, etc.).
  static const appConfigCollectionId = String.fromEnvironment(
    'APPWRITE_MAIN_APP_CONFIG_COLLECTION_ID',
    defaultValue: 'app_config',
  );

  /// Document [key] for World Cup / home featured match cards JSON.
  static const featuredLiveEventsKey = String.fromEnvironment(
    'APPWRITE_MAIN_FEATURED_LIVE_EVENTS_KEY',
    defaultValue: 'featured_live_events',
  );

  /// Re-fetch featured JSON from Appwrite at most this often (pull-to-refresh bypasses).
  static const featuredLiveEventsCacheTtl = Duration(minutes: 15);

  static const pageSize = 100;

  /// Remote control document in `app_config` (ads, kill switch, updates).
  static const globalConfigDocumentId = 'global_config';

  /// Special Link / GITUN rows (replaces GitHub M3U).
  static const specialLinksCollectionId = String.fromEnvironment(
    'APPWRITE_MAIN_SPECIAL_LINKS_COLLECTION_ID',
    defaultValue: 'special_links',
  );

  static const globalConfigCacheTtl = Duration(hours: 24);

  static bool get isConfigured =>
      projectId.isNotEmpty && endpoint.isNotEmpty && databaseId.isNotEmpty;

  static void assertReleaseConfigured() {
    if (!kReleaseMode) return;
    if (isConfigured) return;
    throw StateError(
      'Appwrite is not configured for release build.\n'
      'Set APPWRITE_MAIN_PROJECT_ID, APPWRITE_MAIN_ENDPOINT, '
      'and APPWRITE_MAIN_DATABASE_ID via --dart-define. See docs/BUILD.md.',
    );
  }
}
