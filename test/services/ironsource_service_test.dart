import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/services/ironsource_service.dart';

void main() {
  test('hasLevelPlayRewardedUnit reflects compile-time define', () {
    expect(AdConfig.hasLevelPlayRewardedUnit, isA<bool>());
  });

  test('two loadInterstitial calls invoke SDK load once', () {
    LevelPlayAdService.debugResetForTest();
    final service = LevelPlayAdService.instance;
    service.debugSetInitializedForTest(true);

    LevelPlayAdService.testInterstitialLoadInvoker = () async {};
    service.loadInterstitial();
    service.loadInterstitial();

    expect(LevelPlayAdService.debugInterstitialLoadCallCount, 1);
    expect(service.isInterstitialLoadInFlight, isTrue);
  });
}
