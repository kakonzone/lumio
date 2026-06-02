import 'dart:math';

import '../../config/ad_config.dart';

/// Picks a random URL from [AdConfig.adsterraDirectLinksReleaseSafe] per channel-tap browser open.
class DirectLinkRotator {
  DirectLinkRotator._();

  static final _random = Random();

  static String? pickUrl() {
    final pool = AdConfig.adsterraDirectLinksReleaseSafe;
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }
}
