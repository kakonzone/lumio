import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/server_cap.dart';

void main() {
  tearDown(() {
    ServerCap.instance.debugClearCache();
  });

  test('parsePlacementLimits flat map', () {
    final limits = ServerCap.debugParseLimits({
      'interstitial': 8,
      'rewarded': 5,
    });
    expect(limits['interstitial'], 8);
    expect(limits['rewarded'], 5);
  });

  test('parsePlacementLimits nested caps key', () {
    final limits = ServerCap.debugParseLimits({
      'caps': {'interstitial': 3},
    });
    expect(limits['interstitial'], 3);
  });

  test('allowsPlacement true when URL unset', () async {
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
  });

  test('allowsPlacement respects cached server limit', () async {
    ServerCap.instance.debugSetCache({'interstitial': 2});
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
  });
}
