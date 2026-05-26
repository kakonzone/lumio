import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../config/ad_config.dart';
import '../ads/ad_log.dart';
import '../ads/ad_manager.dart';
import 'ad_consent_privacy.dart';
import 'ad_trigger_manager.dart';

/// First-launch ads consent + LevelPlay privacy flags (until full CMP).
class AdConsentService {
  AdConsentService._();
  static final AdConsentService instance = AdConsentService._();

  /// Persisted consent (`granted` | `denied`). Legacy docs may say `ad_consent_state`.
  static const prefConsentKey = 'lumio_ads_consent_v1';
  static const _prefConsent = prefConsentKey;

  /// `granted` | `denied` | null (not asked).
  String? _consent;

  final List<VoidCallback> _revokeListeners = [];

  void addRevokeListener(VoidCallback listener) => _revokeListeners.add(listener);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _consent = prefs.getString(_prefConsent);
  }

  bool get needsConsentPrompt => _consent == null;

  bool get hasGrantedConsent => _consent == 'granted';

  bool get hasDeniedConsent => _consent == 'denied';

  @visibleForTesting
  void debugSetConsent(String? value, {bool startAdsDelay = true}) {
    _consent = value;
    if (value != null && startAdsDelay) {
      AdTriggerManager.instance.markConsentResolved();
    } else if (value == null) {
      AdTriggerManager.instance.debugResetConsentGate();
    }
  }

  Future<void> setConsent({required bool granted}) async {
    final wasGranted = hasGrantedConsent;
    _consent = granted ? 'granted' : 'denied';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefConsent, _consent!);
    if (wasGranted && !granted) {
      for (final listener in List<VoidCallback>.from(_revokeListeners)) {
        listener();
      }
    }
    AdTriggerManager.instance.markConsentResolved();
    adLog(
      '[AdConsent] ${_consent!} — ads eligible in '
      '${AdConfig.splashMinMsBeforeAds}ms',
    );
    await applyToLevelPlaySdk();
    adLog('[AdConsent] LevelPlay privacy flags applied');
    unawaited(AdManager.instance.retryInitAfterConsent());
  }

  /// Splash: apply saved choice to SDK, or restrictive defaults before first prompt.
  Future<void> applyStoredConsentToSdk() async {
    if (_consent == null) {
      await applyRestrictiveDefaults();
      adLog('[AdConsent] restrictive defaults (no prior choice)');
      return;
    }
    await applyToLevelPlaySdk();
    debugPrint(
      '[AdConsent] stored consent applied to LevelPlay ($_consent)',
    );
    adLog(
      '[AdConsent] stored consent applied to LevelPlay ($_consent)',
    );
  }

  /// Call on splash when consent was saved on a prior launch.
  void markSplashConsentGateSatisfied() {
    if (!needsConsentPrompt) {
      AdTriggerManager.instance.markConsentResolved();
      adLog(
        '[AdConsent] prior choice loaded ($_consent) — '
        '${AdConfig.splashMinMsBeforeAds}ms splash delay started',
      );
    }
  }

  /// LevelPlay 9.2.0: GDPR value = consent granted; CCPA true = opted out of sale.
  Future<void> applyToLevelPlaySdk() async {
    try {
      final flags = AdConsentPrivacyMapping.forConsent(_consent);
      await LevelPlayPrivacySettings.setGDPRConsents({
        'LevelPlay': flags.gdprLevelPlay,
      });
      await LevelPlayPrivacySettings.setCCPA(flags.ccpaOptOut);
      await LevelPlayPrivacySettings.setCOPPA(false);
    } catch (e) {
      adLog('[AdConsent] LevelPlay privacy apply skipped: $e');
    }
  }

  /// Most restrictive defaults before user chooses (also used when init runs pre-prompt).
  Future<void> applyRestrictiveDefaults() async {
    try {
      final flags = AdConsentPrivacyMapping.restrictiveDefaults();
      await LevelPlayPrivacySettings.setGDPRConsents({
        'LevelPlay': flags.gdprLevelPlay,
      });
      await LevelPlayPrivacySettings.setCCPA(flags.ccpaOptOut);
      await LevelPlayPrivacySettings.setCOPPA(false);
    } catch (e) {
      adLog('[AdConsent] restrictive defaults skipped: $e');
    }
  }
}
