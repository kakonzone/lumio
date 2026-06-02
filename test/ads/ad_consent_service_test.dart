import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/services/ad_consent_privacy.dart';
import 'package:lumio_tv/services/ad_consent_service.dart';
import 'package:lumio_tv/services/ad_trigger_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdTriggerManager.instance.debugResetConsentGate();
  });

  test('needsConsentPrompt when pref unset', () async {
    await AdConsentService.instance.load();
    expect(AdConsentService.instance.needsConsentPrompt, isTrue);
  });

  test('loads granted consent from prefs', () async {
    SharedPreferences.setMockInitialValues({
      AdConsentService.prefConsentKey: 'granted',
    });
    await AdConsentService.instance.load();
    expect(AdConsentService.instance.hasGrantedConsent, isTrue);
    expect(AdConsentService.instance.needsConsentPrompt, isFalse);
  });

  test('stored granted maps to LevelPlay GDPR=true (not restrictive)', () {
    final flags = AdConsentPrivacyMapping.forConsent('granted');
    expect(flags.gdprLevelPlay, isTrue);
    expect(flags.ccpaOptOut, isFalse);
    final restrictive = AdConsentPrivacyMapping.restrictiveDefaults();
    expect(flags.gdprLevelPlay, isNot(restrictive.gdprLevelPlay));
  });

  test('stored denied maps to LevelPlay GDPR=false and CCPA opt-out', () {
    final flags = AdConsentPrivacyMapping.forConsent('denied');
    expect(flags.gdprLevelPlay, isFalse);
    expect(flags.ccpaOptOut, isTrue);
  });

  test('null consent uses restrictive defaults before first prompt', () {
    final flags = AdConsentPrivacyMapping.forConsent(null);
    final restrictive = AdConsentPrivacyMapping.restrictiveDefaults();
    expect(flags.gdprLevelPlay, restrictive.gdprLevelPlay);
    expect(flags.ccpaOptOut, restrictive.ccpaOptOut);
  });

  test('applyStoredConsentToSdk with granted does not need restrictive path', () async {
    SharedPreferences.setMockInitialValues({
      AdConsentService.prefConsentKey: 'granted',
    });
    await AdConsentService.instance.load();
    await AdConsentService.instance.applyStoredConsentToSdk();
    expect(AdConsentService.instance.hasGrantedConsent, isTrue);
    expect(
      AdConsentPrivacyMapping.forConsent('granted').gdprLevelPlay,
      isTrue,
    );
  });

  test('setConsent persists and starts splashMinMsBeforeAds window', () async {
    await AdConsentService.instance.load();
    await AdConsentService.instance.setConsent(granted: true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AdConsentService.prefConsentKey), 'granted');
    expect(AdConsentService.instance.hasGrantedConsent, isTrue);
    expect(AdTriggerManager.instance.debugIsAdsEligible, isFalse);

    await AdTriggerManager.instance.waitUntilAdsEligible();
    expect(AdTriggerManager.instance.debugIsAdsEligible, isTrue);
    // updated for rc1: splash delay follows capLocalOnlyEffective profile
    expect(AdConfig.splashMinMsBeforeAds, AdConfig.capLocalOnlyEffective ? 400 : 2500);
  });

  test('markSplashConsentGateSatisfied marks ad eligibility', () async {
    SharedPreferences.setMockInitialValues({
      AdConsentService.prefConsentKey: 'granted',
    });
    await AdConsentService.instance.load();
    AdConsentService.instance.markSplashConsentGateSatisfied();
    expect(AdTriggerManager.instance.debugIsAdsEligible, isFalse);
    await AdTriggerManager.instance.waitUntilAdsEligible();
    expect(AdTriggerManager.instance.debugIsAdsEligible, isTrue);
  });
}
