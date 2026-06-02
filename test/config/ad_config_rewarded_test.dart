import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('LEVELPLAY_REWARDED_AD_UNIT is wired in AdConfig', () {
    expect(AdConfig.rewardedAdUnitId, isA<String>());
    // Compile-time define empty in test VM unless passed via --dart-define-from-file.
    expect(AdConfig.hasLevelPlayRewardedUnit, isA<bool>());
  });

  test('rewarded caps constants are positive', () {
    expect(AdConfig.rewardedMaxPerHour, greaterThan(0));
    expect(AdConfig.adFreeMinutesAfterRewarded, greaterThan(0));
  });
}
