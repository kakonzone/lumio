import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/ironsource_service.dart';

void main() {
  setUp(LevelPlayAdService.debugResetForTest);

  test('two loadRewarded calls invoke SDK load once', () {
    final service = LevelPlayAdService.instance;
    service.debugSetInitializedForTest(true);
    LevelPlayAdService.testRewardedLoadInvoker = () async {};

    service.loadRewarded();
    service.loadRewarded();

    expect(LevelPlayAdService.debugRewardedLoadCallCount, 1);
    expect(service.isRewardedLoadInFlight, isTrue);
  });

  test('load failure clears in-flight flag', () {
    final service = LevelPlayAdService.instance;
    service.debugSetInitializedForTest(true);
    LevelPlayAdService.testRewardedLoadInvoker = () async {};

    service.loadRewarded();
    expect(service.isRewardedLoadInFlight, isTrue);

    service.debugSimulateRewardedLoadFailedForTest();
    expect(service.isRewardedLoadInFlight, isFalse);

    service.loadRewarded();
    expect(LevelPlayAdService.debugRewardedLoadCallCount, 2);
  });
}
