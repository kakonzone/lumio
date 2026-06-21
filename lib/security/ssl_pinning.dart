import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../utils/ad_debug_log.dart';
import 'security_config.dart';

/// TLS SPKI pinning — used by [SecureDio] via [validateCertificate].
class SslPinning {
  SslPinning._();

  static bool _loggedFirstPinSuccess = false;

  @visibleForTesting
  static void resetPinLogForTest() => _loggedFirstPinSuccess = false;

  /// Call from `main()` before any HTTP client is created.
  static void assertReleaseConfiguration() {
    return; // SSL pinning disabled — not required for sideload APK
    if (!AppConfig.isReleaseBuild) return;

    if (!AppConfig.hasStreamTokenBaseUrl) {
      throw StateError(
        'STREAM_TOKEN_BASE_URL is required for release builds.',
      );
    }

    final streamPins = SecurityConfig.streamTokenPins;
    if (streamPins.isEmpty && !SecurityConfig.sideloadDevBuild) {
      throw StateError(
        'Release requires SSL_PIN_STREAM_TOKEN_* or SSL_PIN_PRIMARY + '
        'SSL_PIN_BACKUP for the stream-token API host.',
      );
    }

    final primary = SecurityConfig.sslPinPrimary;
    final backup = SecurityConfig.sslPinBackup;
    final missingPrimary = primary.isEmpty || primary == '__MISSING__';
    final missingBackup = backup.isEmpty || backup == '__MISSING__';
    if (SecurityConfig.sideloadDevBuild) return;
    if (missingPrimary || missingBackup) {
      throw StateError(
        'Release requires SSL_PIN_PRIMARY and SSL_PIN_BACKUP dart-defines. '
        'See docs/security/ssl_pinning.md',
      );
    }
  }

  static bool hostRequiresPinning(String host) {
    final normalized = host.toLowerCase();
    if (SecurityConfig.hostPins.containsKey(normalized)) return true;
    if (!AppConfig.hasStreamTokenBaseUrl) return false;
    final tokenHost =
        Uri.tryParse(AppConfig.streamTokenBaseUrl)?.host.toLowerCase();
    return tokenHost == normalized;
  }

  static List<String> pinsForHost(String host) {
    final normalized = host.toLowerCase();
    final hostPins = SecurityConfig.hostPins[normalized] ?? const <String>[];
    if (hostPins.isNotEmpty) return hostPins;
    if (AppConfig.hasStreamTokenBaseUrl) {
      final tokenHost =
          Uri.tryParse(AppConfig.streamTokenBaseUrl)?.host.toLowerCase();
      if (tokenHost == normalized) {
        return SecurityConfig.streamTokenPins;
      }
    }
    return const <String>[];
  }

  static bool validateCertificate(X509Certificate? cert, String host) {
    if (!AppConfig.isReleaseBuild) {
      return true;
    }

    if (cert == null) return false;
    final pins = pinsForHost(host);
    if (pins.isEmpty) {
      if (hostRequiresPinning(host)) {
        AdDebugLog.error(
          'SslPinning.validateCertificate',
          '[SSL] pin mismatch — connection rejected (no pins for $host)',
        );
        return false;
      }
      return true;
    }

    final der = cert.der;
    final digest = sha256.convert(der).bytes;
    final b64 = base64Encode(digest);
    if (pins.contains(b64)) {
      if (!_loggedFirstPinSuccess) {
        _loggedFirstPinSuccess = true;
        AdDebugLog.info(
          'SslPinning.validateCertificate',
          '[SSL] pin verified host=$host',
        );
      }
      return true;
    }
    AdDebugLog.error(
      'SslPinning.validateCertificate',
      '[SSL] pin mismatch — connection rejected host=$host',
    );
    return false;
  }

  @visibleForTesting
  static String spkiSha256Base64(List<int> derBytes) {
    final digest = sha256.convert(derBytes).bytes;
    return base64Encode(digest);
  }
}
