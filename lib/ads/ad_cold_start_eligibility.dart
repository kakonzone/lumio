import 'package:flutter/foundation.dart';

import '../config/ad_config.dart';
import '../services/ad_consent_service.dart';
import '../services/ad_safety_service.dart';
import '../services/ad_trigger_manager.dart';
import '../services/server_cap.dart';
import '../services/user_preferences.dart';
import 'ad_log.dart';
import 'ad_manager.dart';
import 'interstitial_placement.dart';

/// Why post-splash (cold-start) promo may not run — grep `LumioAdsColdStart`.
enum AdColdStartBlockerCode {
  noMonetizationConfig,
  serverCapBlocksRelease,
  adsDisabledRemote,
  adManagerNotReady,
  removeAdsPurchased,
  adFreeWindow,
  consentDenied,
  consentTimerPending,
  appOpenDailyCap,
  appOpenGapHours,
  networkIsolation,
  interstitialHourlyCap,
  serverCapPlacementDenied,
  vpnAdsterraDisabled,
  levelPlayDisabledRemote,
  noThirdPartyFill,
}

/// One gate in the cold-start funnel.
class AdColdStartBlocker {
  const AdColdStartBlocker({
    required this.code,
    required this.message,
    this.blocksThirdParty = true,
    this.blocksHousePromo = false,
  });

  final AdColdStartBlockerCode code;
  final String message;

  /// Blocks LevelPlay + Adsterra.
  final bool blocksThirdParty;

  /// Blocks in-app promo screen entirely (rare).
  final bool blocksHousePromo;

  String get codeName => code.name;
}

/// Result of evaluating all cold-start gates (splash → home promo).
class AdColdStartEligibilityReport {
  const AdColdStartEligibilityReport({
    required this.blockers,
    required this.canShowLevelPlay,
    required this.canShowAdsterra,
    required this.canShowHousePromo,
    this.capReason,
  });

  final List<AdColdStartBlocker> blockers;
  final bool canShowLevelPlay;
  final bool canShowAdsterra;
  final bool canShowHousePromo;
  final String? capReason;

  bool get canShowAnyPromo =>
      canShowLevelPlay || canShowAdsterra || canShowHousePromo;

  AdColdStartBlocker? get primaryBlocker {
    for (final b in blockers) {
      if (b.blocksHousePromo) return b;
    }
    for (final b in blockers) {
      if (b.blocksThirdParty) return b;
    }
    return blockers.isNotEmpty ? blockers.first : null;
  }

  String get logSummary {
    if (canShowAnyPromo) {
      final parts = <String>[
        if (canShowLevelPlay) 'levelplay',
        if (canShowAdsterra) 'adsterra',
        if (canShowHousePromo) 'house',
      ];
      final warn = blockers
          .where((b) => !b.blocksHousePromo)
          .map((b) => b.codeName)
          .join(',');
      return 'eligible networks=${parts.join("+")}'
          '${warn.isEmpty ? "" : " warnings=$warn"}';
    }
    final codes = blockers.map((b) => b.codeName).join(',');
    return 'blocked${capReason != null ? " cap=$capReason" : ""} reasons=$codes';
  }

  void logToConsole() {
    // ignore: avoid_print
    print('[LumioAdsColdStart] $logSummary');
    for (final b in blockers) {
      adLog('[LumioAdsColdStart] ${b.codeName}: ${b.message}');
    }
  }
}

/// Central cold-start gate audit (monetization, cap, consent, VPN, frequency).
class AdColdStartEligibility {
  AdColdStartEligibility._();

  static bool _loggedThisProcess = false;

  static Future<AdColdStartEligibilityReport> evaluate() async {
    final blockers = <AdColdStartBlocker>[];
    final safety = AdSafetyService.instance;
    final caps = AdTriggerManager.instance;
    final manager = AdManager.instance;

    if (!AdConfig.hasMonetizationConfig) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.noMonetizationConfig,
          message:
              'Release APK missing LEVELPLAY / Adsterra dart-defines — rebuild with secrets.json',
          blocksHousePromo: true,
        ),
      );
    }

    if (ServerCap.instance.blocksAdsInRelease) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.serverCapBlocksRelease,
          message:
              'CAP_BASE_URL empty and CAP_LOCAL_ONLY_MODE off — set CAP_LOCAL_ONLY_MODE=true in secrets.json',
          blocksHousePromo: true,
        ),
      );
    }

    if (!safety.adsEnabledRemote) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.adsDisabledRemote,
          message: 'Firebase Remote Config ads_enabled=false',
          blocksHousePromo: true,
        ),
      );
    }

    if (!manager.isReady) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.adManagerNotReady,
          message: 'AdManager.init() did not complete — check LumioAds logcat line',
          blocksHousePromo: true,
        ),
      );
    }

    if (UserPreferences.removeAdsPurchased) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.removeAdsPurchased,
          message: 'User purchased remove-ads',
          blocksHousePromo: true,
        ),
      );
    }

    if (caps.isAdFree) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.adFreeWindow,
          message: 'Rewarded ad-free window active',
          blocksHousePromo: true,
        ),
      );
    }

    if (AdConsentService.instance.hasDeniedConsent) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.consentDenied,
          message:
              'Privacy consent denied — third-party ads off; house promo may still show',
          blocksThirdParty: true,
          blocksHousePromo: false,
        ),
      );
    } else if (!AdConsentService.instance.hasGrantedConsent &&
        AdConsentService.instance.needsConsentPrompt) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.consentTimerPending,
          message: 'Waiting for first-launch consent on splash',
          blocksThirdParty: true,
          blocksHousePromo: true,
        ),
      );
    } else if (!caps.isSplashAdsDelaySatisfied) {
      blockers.add(
        AdColdStartBlocker(
          code: AdColdStartBlockerCode.consentTimerPending,
          message:
              'Splash ads delay (${AdConfig.splashMinMsBeforeAds}ms) not finished',
          blocksThirdParty: true,
          blocksHousePromo: false,
        ),
      );
    }

    String? capReason;
    final cap = await caps.canShowPlacement(
      InterstitialPlacement.appOpen,
      removeAds: UserPreferences.removeAdsPurchased,
    );
    if (!cap.allowed) {
      capReason = cap.reason;
      final code = _capBlockerCode(cap.reason);
      blockers.add(
        AdColdStartBlocker(
          code: code,
          message: _capBlockerMessage(code, cap.reason),
          blocksThirdParty: true,
          blocksHousePromo: false,
        ),
      );
    }

    if (safety.preferCleanSdkRouting) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.vpnAdsterraDisabled,
          message:
              'VPN/geo signals — Adsterra limited on popunder/banners; app-open promo still allowed',
          blocksThirdParty: false,
          blocksHousePromo: false,
        ),
      );
    }

    if (!safety.levelPlayEnabledRemote) {
      blockers.add(
        const AdColdStartBlocker(
          code: AdColdStartBlockerCode.levelPlayDisabledRemote,
          message: 'Remote Config levelplay_enabled=false',
          blocksThirdParty: true,
          blocksHousePromo: false,
        ),
      );
    }

    final blocksAll = blockers.any((b) => b.blocksHousePromo);
    final blocksThirdParty =
        blockers.any((b) => b.blocksThirdParty) || blocksAll;

    final canLevelPlay = !blocksThirdParty &&
        manager.levelPlayAdsEnabled &&
        AdConfig.hasValidLevelPlayAppKey &&
        AdConfig.hasValidLevelPlayAdUnits;

    final canAdsterra = !blocksThirdParty &&
        safety.adsterraEnabledForColdStart &&
        (AdConfig.hasAdsterraWebViewZones ||
            AdConfig.hasValidAdsterraDirectLink ||
            AdConfig.hasValidAdsterraSmartlink);

    final canHouse = !blocksAll &&
        !UserPreferences.removeAdsPurchased &&
        !caps.isAdFree &&
        manager.isReady;

    return AdColdStartEligibilityReport(
      blockers: blockers,
      canShowLevelPlay: canLevelPlay,
      canShowAdsterra: canAdsterra,
      canShowHousePromo: canHouse,
      capReason: capReason,
    );
  }

  static AdColdStartBlockerCode _capBlockerCode(String? reason) {
    switch (reason) {
      case 'app_open_cap':
        return AdColdStartBlockerCode.appOpenDailyCap;
      default:
        if (reason != null && reason.contains('gap')) {
          return AdColdStartBlockerCode.appOpenGapHours;
        }
        if (reason == 'network_isolation') {
          return AdColdStartBlockerCode.networkIsolation;
        }
        if (reason != null && reason.contains('hour')) {
          return AdColdStartBlockerCode.interstitialHourlyCap;
        }
        return AdColdStartBlockerCode.serverCapPlacementDenied;
    }
  }

  static String _capBlockerMessage(AdColdStartBlockerCode code, String? reason) {
    return switch (code) {
      AdColdStartBlockerCode.appOpenDailyCap =>
        'App-open shown ${AdConfig.appOpenMaxPerDay}x today — try tomorrow',
      AdColdStartBlockerCode.appOpenGapHours =>
        'App-open min gap ${AdConfig.appOpenMinGapHours}h — wait and reopen',
      AdColdStartBlockerCode.networkIsolation =>
        'Adsterra surface recently — SDK paused ${AdConfig.networkIsolationSeconds}s',
      AdColdStartBlockerCode.interstitialHourlyCap =>
        'Hourly interstitial cap (${AdConfig.interstitialMaxPerHour}/h)',
      _ => 'Placement cap: ${reason ?? "unknown"}',
    };
  }

  /// Logs once per process unless [force].
  static Future<AdColdStartEligibilityReport> evaluateAndLog({
    bool force = false,
  }) async {
    final report = await evaluate();
    if (force || !_loggedThisProcess) {
      _loggedThisProcess = true;
      report.logToConsole();
    }
    return report;
  }

  @visibleForTesting
  static void debugResetLogOnce() => _loggedThisProcess = false;
}
