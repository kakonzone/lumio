import 'package:flutter/foundation.dart';

import 'legal_config.dart';

/// App-level backend configuration loaded via `--dart-define`.
class AppConfig {
  AppConfig._();

  /// `--dart-define=RELEASE_MODE=true` or Flutter release build.
  static const bool releaseModeDefine = bool.fromEnvironment(
    'RELEASE_MODE',
    defaultValue: false,
  );

  static bool get isReleaseBuild => kReleaseMode || releaseModeDefine;

  /// Backend base URL for security/token/creds endpoints.
  static const String backendBaseUrl = String.fromEnvironment(
    'LUMIO_BACKEND_BASE_URL',
    defaultValue: '__MISSING__',
  );

  /// Static app key header (server must rate-limit + rotate if leaked).
  static const String backendAppKey = String.fromEnvironment(
    'LUMIO_BACKEND_APP_KEY',
    defaultValue: '__MISSING__',
  );

  /// Base URL for signed stream token endpoint.
  ///
  /// Server contract (audit): `GET/POST {base}/v1/stream-token` with
  /// `channelId`, `installId`, HMAC headers; returns short-lived `streamUrl`
  /// + `token` + `expiresAt`. Client: [StreamTokenService].
  static const String streamTokenBaseUrl = String.fromEnvironment(
    'STREAM_TOKEN_BASE_URL',
    defaultValue: '__MISSING__',
  );

  /// Cloudflare Worker (or CDN) JSON channel catalog.
  static const String remoteChannelsUrl = String.fromEnvironment(
    'REMOTE_CHANNELS_URL',
    defaultValue: 'https://lumio-channels.kakonzone.workers.dev/channels',
  );

  /// Public-facing legal URLs (delegates to [LegalConfig]).
  static String get privacyPolicyUrl => LegalConfig.privacyPolicyUrl;
  static String get termsOfServiceUrl => LegalConfig.termsOfServiceUrl;
  static String get contactEmail => LegalConfig.contactEmail;
  static String get dataDeletionUrl => LegalConfig.dataDeletionUrl;

  /// JSON manifest: `{ "version": "1.0.1", "apk_url": "https://...", "message": "..." }`
  static const String appUpdateManifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
    defaultValue: '__MISSING__',
  );

  /// Scanned IPTV service URLs (JioTV + scan server).
  static const String scannedIptvJioChannelsUrl = String.fromEnvironment(
    'SCANNED_IPTV_JIO_CHANNELS_URL',
    defaultValue: 'http://103.180.212.191:3500/channels',
  );

  static const String scannedIptvScanPlaylistUrl = String.fromEnvironment(
    'SCANNED_IPTV_SCAN_PLAYLIST_URL',
    defaultValue: 'http://202.70.146.135:8000/playlist.m3u8',
  );

  static const String scannedIptvJioStreamBase = String.fromEnvironment(
    'SCANNED_IPTV_JIO_STREAM_BASE',
    defaultValue: 'http://103.180.212.191:3500/live/{id}.m3u8',
  );

  static bool get hasBackend =>
      backendBaseUrl.trim().isNotEmpty && backendBaseUrl != '__MISSING__';
  static bool get hasBackendKey =>
      backendAppKey.trim().isNotEmpty && backendAppKey != '__MISSING__';
  static bool get hasStreamTokenBaseUrl =>
      streamTokenBaseUrl.trim().isNotEmpty &&
      streamTokenBaseUrl != '__MISSING__';

  /// Release requires [streamTokenBaseUrl] unless local cap sideload mode is on.
  static void assertReleaseStreamTokenConfigured() {
    if (!isReleaseBuild) return;
    if (hasStreamTokenBaseUrl) return;
    // Import cycle avoided — duplicate gate condition from AdConfig.
    const capLocal = bool.fromEnvironment('CAP_LOCAL_ONLY_MODE');
    const sideloadDev = bool.fromEnvironment('LUMIO_SIDELOAD_DEV');
    if (capLocal || sideloadDev) return;
    throw StateError(
      'STREAM_TOKEN_BASE_URL must be set for release builds when '
      'CAP_LOCAL_ONLY_MODE and LUMIO_SIDELOAD_DEV are false (see docs/BUILD.md).',
    );
  }

  static bool get hasPrivacyPolicy => LegalConfig.hasPrivacyPolicy;
  static bool get hasTerms => LegalConfig.hasTerms;
  static bool get hasContactEmail => LegalConfig.hasContactEmail;
  static bool get hasDataDeletion => LegalConfig.hasDataDeletion;
  static bool get hasAppUpdateManifest =>
      appUpdateManifestUrl.trim().isNotEmpty &&
      appUpdateManifestUrl != '__MISSING__';

  @visibleForTesting
  static Uri credsUriForTest(String path) {
    final base = backendBaseUrl.trim();
    final normalized =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized$path');
  }
}
