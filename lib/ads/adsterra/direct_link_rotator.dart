import 'dart:math';

import '../../config/ad_config.dart';
import '../../config/monetag_config.dart';

/// Picks a random URL from Adsterra and Monetag direct links per channel-tap browser open.
/// Rotates between Adsterra and Monetag links for better monetization.
class DirectLinkRotator {
  DirectLinkRotator._();

  static final _random = Random();

  static String? pickUrl() {
    // Combine Adsterra and Monetag direct links for rotation
    final pool = <String>[
      ...AdConfig.adsterraDirectLinksReleaseSafe,
      if (MonetagConfig.isConfigured) MonetagConfig.directLinkUrl,
    ];

    // Filter out empty strings
    final validPool = pool.where((url) => url.trim().isNotEmpty).toList();

    if (validPool.isEmpty) return null;
    return validPool[_random.nextInt(validPool.length)];
  }
}
