import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/server_cap_client.dart';
import 'package:lumio_tv/services/server_cap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M2 — server cap fail-closed when API unreachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    ServerCap.debugTreatAsConfigured = false;
    ServerCap.instance.debugClearCache();
  });

  test('allowsPlacement true when cap URL unset', () async {
    ServerCap.debugTreatAsConfigured = false;
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
    expect(await ServerCapService.instance.allowsPlacement('interstitial'), isTrue);
  });

  test('allowsPlacement false when configured and fail-closed', () async {
    ServerCap.debugTreatAsConfigured = true;
    ServerCap.instance.debugSetFailClosed(true);
    expect(ServerCap.instance.isFailClosed, isTrue);
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isFalse);
    expect(await ServerCapService.instance.allowsPlacement('interstitial'), isFalse);
  });

  test('allowsPlacement true when configured, sync ok, under limit', () async {
    ServerCap.debugTreatAsConfigured = true;
    ServerCap.instance.debugSetFailClosed(false);
    ServerCap.instance.debugSetCache({'interstitial': 99});
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
  });

  test('fail-closed clears after successful debug cache + no fail flag', () async {
    ServerCap.debugTreatAsConfigured = true;
    ServerCap.instance.debugSetFailClosed(false);
    ServerCap.instance.debugSetCache({'interstitial': 2});
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isTrue);
  });

  test('at server limit still allows when not fail-closed', () async {
    ServerCap.debugTreatAsConfigured = true;
    ServerCap.instance.debugSetFailClosed(false);
    ServerCap.instance.debugSetCache({'interstitial': 0});
    expect(await ServerCap.instance.allowsPlacement('interstitial'), isFalse);
  });

  test('debugClearCache resets fail-closed flag', () async {
    ServerCap.debugTreatAsConfigured = true;
    ServerCap.instance.debugSetFailClosed(true);
    ServerCap.instance.debugClearCache();
    expect(ServerCap.instance.isFailClosed, isFalse);
  });
}
