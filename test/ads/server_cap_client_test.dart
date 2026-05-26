import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/server_cap_client.dart';
import 'package:lumio_tv/services/server_cap.dart';

void main() {
  tearDown(() {
    ServerCap.instance.debugClearCache();
  });

  test('allowsPlacement uses local caps when CAP_BASE_URL unset', () async {
    expect(await ServerCapService.instance.allowsPlacement('interstitial'), isTrue);
  });

  test('logConfigurationOnce prints disabled when URL unset', () {
    ServerCap.instance.debugClearCache();
    ServerCap.instance.logConfigurationOnce();
    expect(ServerCap.instance.isConfigured, isFalse);
  });
}
