/// Appwrite — main channel catalog (home, sports, categories, live).
///
/// Uses **Guests Read** only (no API key in the app). Console → `iptv_main` →
/// `channels` / `app_config` → Permissions → Read → **Guests**.
class AppwriteConfig {
  AppwriteConfig._();

  /// Offline catalog cache TTL when Appwrite is unreachable.
  static const catalogCacheTtl = Duration(hours: 24);

  static const projectId = String.fromEnvironment(
    'APPWRITE_PROJECT_ID',
    defaultValue: '191876000995145',
  );

  static const endpoint = String.fromEnvironment(
    'APPWRITE_ENDPOINT',
    defaultValue: 'https://nyc.cloud.appwrite.io/v1',
  );

  /// Databases → your channel table / collection IDs (override in secrets.json).
  static const databaseId = String.fromEnvironment(
    'APPWRITE_DATABASE_ID',
    defaultValue: 'iptv_main',
  );

  /// One document per channel (preferred for 4k+ rows).
  static const channelsCollectionId = String.fromEnvironment(
    'APPWRITE_CHANNELS_COLLECTION_ID',
    defaultValue: 'channels',
  );

  /// Optional: single document holding full M3U text (fallback).
  static const playlistCollectionId = String.fromEnvironment(
    'APPWRITE_PLAYLIST_COLLECTION_ID',
    defaultValue: 'playlists',
  );

  static const mainPlaylistDocumentId = String.fromEnvironment(
    'APPWRITE_MAIN_PLAYLIST_DOCUMENT_ID',
    defaultValue: 'main',
  );

  /// App config rows: `key`, `json_payload`, `updated_at` (featured cards, etc.).
  static const appConfigCollectionId = String.fromEnvironment(
    'APPWRITE_APP_CONFIG_COLLECTION_ID',
    defaultValue: 'app_config',
  );

  /// Document [key] for World Cup / home featured match cards JSON.
  static const featuredLiveEventsKey = String.fromEnvironment(
    'APPWRITE_FEATURED_LIVE_EVENTS_KEY',
    defaultValue: 'featured_live_events',
  );

  /// Re-fetch featured JSON from Appwrite at most this often (pull-to-refresh bypasses).
  static const featuredLiveEventsCacheTtl = Duration(minutes: 15);

  static const pageSize = 100;

  static bool get isConfigured =>
      projectId.isNotEmpty && endpoint.isNotEmpty && databaseId.isNotEmpty;

  // ── Main project (remote control / global_config) ───────────────────────
  /// Education Pro — future single main project.
  static const mainProjectId = String.fromEnvironment(
    'APPWRITE_MAIN_PROJECT_ID',
    defaultValue: '6a22869200230b1a8bf0',
  );

  static const mainEndpoint = String.fromEnvironment(
    'APPWRITE_MAIN_ENDPOINT',
    defaultValue: 'https://sgp.cloud.appwrite.io/v1',
  );

  static const mainDatabaseId = String.fromEnvironment(
    'APPWRITE_MAIN_DATABASE_ID',
    defaultValue: 'database-iptv_main',
  );

  /// Remote control document in `app_config` (ads, kill switch, updates).
  static const globalConfigDocumentId = 'global_config';

  /// Special Link / GITUN rows (replaces GitHub M3U).
  static const specialLinksCollectionId = String.fromEnvironment(
    'APPWRITE_SPECIAL_LINKS_COLLECTION_ID',
    defaultValue: 'special_links',
  );

  static const globalConfigCacheTtl = Duration(hours: 24);

  static bool get mainProjectConfigured =>
      mainProjectId.isNotEmpty &&
      mainEndpoint.isNotEmpty &&
      mainDatabaseId.isNotEmpty;
}
