import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/server_cap.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ServerCap.instance.debugClearCache();
    SharedPreferences.setMockInitialValues({});
  });

  test('parsePlacementLimits flat map', () {
    final limits = ServerCap.debugParseLimits({
      'interstitial': 8,
      'app_open_substitute': 3,
    });
    expect(limits['interstitial'], 8);
    expect(limits['app_open_substitute'], 3);
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
    // Ensure no hourly usage spills from other tests.
    SharedPreferences.setMockInitialValues({});
    ServerCap.instance.debugSetCache({'interstitial': 2});
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
  });
}
