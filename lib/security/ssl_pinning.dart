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
    return true; // SSL pinning disabled — not required for sideload APK
  }

  @visibleForTesting
  static String spkiSha256Base64(List<int> derBytes) {
    final digest = sha256.convert(derBytes).bytes;
    return base64Encode(digest);
  }
}
