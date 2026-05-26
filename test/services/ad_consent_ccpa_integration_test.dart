import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/ad_consent_privacy.dart';
import 'package:lumio_tv/services/ad_consent_service.dart';
import 'package:lumio_tv/services/ad_trigger_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// M1 — CCPA opt-out semantics wired to LevelPlay privacy channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const levelPlayChannel = MethodChannel('unity_levelplay_mediation');
  final privacyCalls = <String, Object?>{};

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdTriggerManager.instance.debugResetConsentGate();
    privacyCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(levelPlayChannel, (call) async {
      if (call.method == 'setGDPRConsents' ||
          call.method == 'setCCPA' ||
          call.method == 'setCOPPA') {
        privacyCalls[call.method] = call.arguments;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(levelPlayChannel, null);
  });

  group('AdConsentPrivacyMapping (unit)', () {
    test('Personalized: GDPR granted, CCPA not opted out', () {
      final f = AdConsentPrivacyMapping.forConsent('granted');
      expect(f.gdprLevelPlay, isTrue);
      expect(f.ccpaOptOut, isFalse);
    });

    test('Limited: GDPR denied, CCPA opted out of sale', () {
      final f = AdConsentPrivacyMapping.forConsent('denied');
      expect(f.gdprLevelPlay, isFalse);
      expect(f.ccpaOptOut, isTrue);
    });

    test('Not asked: restrictive defaults', () {
      final f = AdConsentPrivacyMapping.forConsent(null);
      expect(f.gdprLevelPlay, isFalse);
      expect(f.ccpaOptOut, isFalse);
    });
  });

  group('LevelPlay channel integration (M1)', () {
    test('setConsent granted → setCCPA(false), GDPR LevelPlay true', () async {
      await AdConsentService.instance.load();
      await AdConsentService.instance.setConsent(granted: true);
      await AdConsentService.instance.applyToLevelPlaySdk();

      expect(
        privacyCalls['setGDPRConsents'],
        {'networkConsents': {'LevelPlay': true}},
      );
      expect(privacyCalls['setCCPA'], {'value': false});
      expect(privacyCalls['setCOPPA'], {'value': false});
    });

    test('setConsent denied → setCCPA(true) opt-out of sale', () async {
      await AdConsentService.instance.load();
      await AdConsentService.instance.setConsent(granted: false);
      await AdConsentService.instance.applyToLevelPlaySdk();

      expect(
        privacyCalls['setGDPRConsents'],
        {'networkConsents': {'LevelPlay': false}},
      );
      expect(privacyCalls['setCCPA'], {'value': true});
    });

    test('applyRestrictiveDefaults before prompt → CCPA false', () async {
      await AdConsentService.instance.applyRestrictiveDefaults();

      expect(
        privacyCalls['setGDPRConsents'],
        {'networkConsents': {'LevelPlay': false}},
      );
      expect(privacyCalls['setCCPA'], {'value': false});
    });

    test('drawer change Limited → CCPA true on re-apply', () async {
      SharedPreferences.setMockInitialValues({
        'lumio_ads_consent_v1': 'granted',
      });
      await AdConsentService.instance.load();
      await AdConsentService.instance.applyToLevelPlaySdk();
      privacyCalls.clear();

      await AdConsentService.instance.setConsent(granted: false);
      expect(privacyCalls['setCCPA'], {'value': true});
    });
  });
}
