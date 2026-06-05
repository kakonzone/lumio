import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_placement_config.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/services/ad_safety_service.dart';
import 'package:lumio_tv/services/ad_trigger_manager.dart';

void main() {
  tearDown(() {
    AdSafetyService.instance.debugSetAggressiveMode(null);
    AdPlacementConfig.debugAggressiveModeOverride = null;
  });

  test('scaledCooldownSeconds tightens by 30% when aggressive', () {
    AdSafetyService.instance.debugSetAggressiveMode(true);
    expect(
      AdTriggerManager.scaledCooldownSeconds(90),
      (90 * 0.7).round(),
    );
    AdSafetyService.instance.debugSetAggressiveMode(false);
    expect(AdTriggerManager.scaledCooldownSeconds(90), 90);
  });

  test('aggressive mode changes placement intervals', () {
    AdPlacementConfig.debugAggressiveModeOverride = true;
    expect(
      AdPlacementConfig.newsNativeInterval,
      AdConfig.nativeListIntervalAggressive,
    );
    AdPlacementConfig.debugAggressiveModeOverride = false;
    expect(
      AdPlacementConfig.newsNativeInterval,
      AdConfig.nativeListInterval,
    );
  });
}
