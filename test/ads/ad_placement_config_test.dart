import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_placement_config.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  tearDown(AdPlacementConfig.debugResetSummaryLog);

  test('news interval constants', () {
    expect(AdConfig.nativeListIntervalNews, 5);
    expect(AdConfig.nativeListInterval, 8);
    expect(AdConfig.nativeListIntervalAggressive, 4);
  });

  test('standard intervals when aggressive_mode false', () {
    AdPlacementConfig.debugAggressiveModeOverride = false;
    expect(AdPlacementConfig.newsNativeInterval, 5);
    expect(AdPlacementConfig.channelListNativeInterval, 8);
    expect(AdPlacementConfig.playerMidRollPeriod.inMinutes, 30);
    expect(AdPlacementConfig.showGlobalSocialBarOverlay, isTrue);
  });

  test('aggressive intervals when aggressive_mode true', () {
    AdPlacementConfig.debugAggressiveModeOverride = true;
    expect(AdPlacementConfig.newsNativeInterval, 4);
    expect(AdPlacementConfig.channelListNativeInterval, 4);
    expect(AdPlacementConfig.playerMidRollPeriod.inMinutes, 24);
    expect(AdPlacementConfig.showGlobalSocialBarOverlay, isTrue);
  });
}
