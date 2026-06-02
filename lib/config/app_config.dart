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
  static const String streamTokenBaseUrl = String.fromEnvironment(
    'STREAM_TOKEN_BASE_URL',
    defaultValue: '__MISSING__',
  );

  /// Cloudflare Worker (or CDN) JSON channel catalog.
  static const String remoteChannelsUrl = String.fromEnvironment(
    'REMOTE_CHANNELS_URL',
    defaultValue:
        'https://lumio-channels.kakonzone.workers.dev/channels',
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

  static bool get hasBackend =>
      backendBaseUrl.trim().isNotEmpty && backendBaseUrl != '__MISSING__';
  static bool get hasBackendKey =>
      backendAppKey.trim().isNotEmpty && backendAppKey != '__MISSING__';
  static bool get hasStreamTokenBaseUrl =>
      streamTokenBaseUrl.trim().isNotEmpty &&
      streamTokenBaseUrl != '__MISSING__';

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
    final normalized = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$normalized$path');
  }
}

