import 'package:flutter/foundation.dart';

import '../config/ad_config.dart';

/// Play Integrity gate — enabled when [AdConfig.playIntegrityCloudProjectNumber] is set.
///
/// TODO(integrity-v2): Roll out server decode + v2 tokens when DAU ≥ 20k
/// (alert ops at 20k). See `docs/integrity_v2_migration.md`.
class PlayIntegrityService {
  PlayIntegrityService._();
  static final PlayIntegrityService instance = PlayIntegrityService._();

  bool get isConfigured =>
      AdConfig.playIntegrityCloudProjectNumber.trim().isNotEmpty;

  /// Returns null when integrity is disabled (Option B default).
  Future<String?> requestToken({String? nonce}) async {
    if (!isConfigured) return null;
    if (kDebugMode) {
      debugPrint(
        '[PlayIntegrity] project=${AdConfig.playIntegrityCloudProjectNumber} '
        '— native bridge pending v1.1',
      );
    }
    return null;
  }
}
