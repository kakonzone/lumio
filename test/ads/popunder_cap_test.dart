import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/ad_consent_service.dart';
import 'package:lumio_tv/services/ad_safety_service.dart';
import 'package:lumio_tv/services/ad_trigger_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AdTriggerManager.instance.debugResetPopunderTestState();
    AdTriggerManager.instance.debugIgnoreAdsterraZoneConfig(true);
    AdSafetyService.instance.debugSetAdsterraEnabled(null);
    AdSafetyService.instance.debugSetPopunderSessionCap(null);
    AdSafetyService.instance.debugSetAdsBlockedInDebug(false);
    AdSafetyService.instance.debugSetPreferCleanSdkRouting(false);
    AdConsentService.instance.debugSetConsent('granted');
    await AdTriggerManager.instance.waitUntilAdsEligible();
    await AdTriggerManager.instance.startSession();
    await AdTriggerManager.instance.debugClearPopunderCooldown();
  });

  tearDown(() {
    AdTriggerManager.instance.debugResetPopunderTestState();
    AdSafetyService.instance.debugSetAdsterraEnabled(null);
    AdSafetyService.instance.debugSetPopunderSessionCap(null);
    AdSafetyService.instance.debugSetAdsBlockedInDebug(false);
    AdSafetyService.instance.debugSetPreferCleanSdkRouting(false);
    AdConsentService.instance.debugSetConsent(null);
  });

  test('allows popunder when session under cap', () async {
    AdSafetyService.instance.debugSetPopunderSessionCap(2);
    AdTriggerManager.instance.debugSetSessionPopunders(0);
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isTrue);
  });

  test('blocks popunder when session at cap', () async {
    AdSafetyService.instance.debugSetPopunderSessionCap(1);
    AdTriggerManager.instance.debugSetSessionPopunders(1);
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isFalse);
  });

  test('blocks popunder when RC adsterra_enabled false', () async {
    AdSafetyService.instance.debugSetAdsterraEnabled(false);
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isFalse);
  });

  test('blocks popunder when consent denied', () async {
    AdConsentService.instance.debugSetConsent('denied');
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isFalse);
  });

  test('blocks popunder during consent splash delay', () async {
    AdConsentService.instance.debugSetConsent('granted', startAdsDelay: false);
    AdTriggerManager.instance.markConsentResolved();
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isFalse);
  });

  test('blocks after recordAdsterraPopunder reaches session cap', () async {
    AdSafetyService.instance.debugSetPopunderSessionCap(1);
    await AdTriggerManager.instance.recordAdsterraPopunder();
    expect(await AdTriggerManager.instance.debugCanShowPopunder(), isFalse);
  });
}
