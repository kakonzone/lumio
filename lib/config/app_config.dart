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

  /// GitHub raw M3U playlist (replaces Cloudflare Worker JSON).
  /// Repository: https://github.com/kakon122/my-media-notes
  static const String remoteChannelsUrl = String.fromEnvironment(
    'REMOTE_CHANNELS_URL',
    defaultValue: 'https://raw.githubusercontent.com/kakon122/my-media-notes/main/my-media-notes.m3u8',
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
    defaultValue: '',
  );

  static const String scannedIptvScanPlaylistUrl = String.fromEnvironment(
    'SCANNED_IPTV_SCAN_PLAYLIST_URL',
    defaultValue: '',
  );

  static const String scannedIptvJioStreamBase = String.fromEnvironment(
    'SCANNED_IPTV_JIO_STREAM_BASE',
    defaultValue: '',
  );

  static bool get hasBackend =>
      backendBaseUrl.trim().isNotEmpty && backendBaseUrl != '__MISSING__';
  static bool get hasBackendKey =>
      backendAppKey.trim().isNotEmpty && backendAppKey != '__MISSING__';
  static bool get hasStreamTokenBaseUrl =>
      streamTokenBaseUrl.trim().isNotEmpty &&
      streamTokenBaseUrl != '__MISSING__';
  static bool get hasScannedIptvJio =>
      scannedIptvJioChannelsUrl.trim().isNotEmpty;
  static bool get hasScannedIptvScan =>
      scannedIptvScanPlaylistUrl.trim().isNotEmpty;

  /// Release requires [streamTokenBaseUrl] unless local cap sideload mode is on.
  /// Disabled for sideload APK builds where dart-defines may not be passed.
  static void assertReleaseStreamTokenConfigured() {
    // DISABLED: stream token infra not deployed for sideload builds yet.
    // To re-enable: change enforceStreamToken to true.
    const enforceStreamToken = false;
    if (!enforceStreamToken) return;

    // ignore: dead_code
    if (!isReleaseBuild) return;
    // ignore: dead_code
    if (hasStreamTokenBaseUrl) return;
    // ignore: dead_code
    const capLocal = bool.fromEnvironment('CAP_LOCAL_ONLY_MODE');
    // ignore: dead_code
    const sideloadDev = bool.fromEnvironment('LUMIO_SIDELOAD_DEV');
    // ignore: dead_code
    if (capLocal || sideloadDev) return;
    // ignore: dead_code
    throw StateError(
      'STREAM_TOKEN_BASE_URL must be set for release builds. '
      'See docs/BUILD.md.',
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
