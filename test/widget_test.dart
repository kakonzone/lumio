import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_placement_config.dart';
import 'package:lumio_tv/config/ad_config.dart';

/// Lightweight app sanity (replaces default counter template).
void main() {
  test('ad config constants are pinned', () {
    expect(AdConfig.splashMinMsBeforeAds, 5000);
    expect(AdConfig.nativeListIntervalNews, 5);
    expect(AdPlacementConfig.channelListNativeInterval, isNonNegative);
  });
}
