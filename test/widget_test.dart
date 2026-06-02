import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_placement_config.dart';
import 'package:lumio_tv/config/ad_config.dart';

/// Lightweight app sanity (replaces default counter template).
void main() {
  test('ad config constants are pinned', () {
    // updated for rc1: 400ms when local-cap/sideload profile is active
    expect(AdConfig.splashMinMsBeforeAds, AdConfig.capLocalOnlyEffective ? 400 : 2500);
    expect(AdConfig.nativeListIntervalNews, 5);
    expect(AdPlacementConfig.channelListNativeInterval, isNonNegative);
  });
}
