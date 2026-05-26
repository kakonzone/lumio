import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ads/server_cap_client.dart';
import 'server_cap.dart';
import '../config/ad_config.dart';
import 'ad_consent_service.dart';
import 'ad_safety_service.dart';
import 'user_preferences.dart';

/// Per-device caps, session funnel, and 30s SDK↔Adsterra isolation (single source of truth).
class AdTriggerManager {
  AdTriggerManager._();
  static final AdTriggerManager instance = AdTriggerManager._();

  final _rng = Random();

  DateTime? _sessionStart;
  DateTime? _adsEligibleAfter;
  DateTime? _lastIronSourceInterstitial;
  DateTime? _lastAdsterraSurfaceEvent;
  DateTime? _lastAppOpenSubstitute;
  DateTime? _adFreeUntil;
  int _sessionPopunders = 0;
  bool _debugIgnoreAdsterraZoneConfig = false;
  int _sessionChannelClicks = 0;
  final Set<String> _channelTapBrowserShown = {};
  final Set<String> _newsArticleAdShown = {};
  int _sessionInterstitialsShown = 0;
  int _sessionInterstitialAttempts = 0;
  bool _exitAdShown = false;
  int _playerVideoAdsShown = 0;
  DateTime? _lastPlayerVideoAdAt;

  String _hourKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}-${n.hour}';
  }

  String _dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Starts [splashMinMsBeforeAds] window after user resolves consent (splash).
  void markConsentResolved() {
    _adsEligibleAfter = DateTime.now().add(
      Duration(milliseconds: AdConfig.splashMinMsBeforeAds),
    );
  }

  Future<void> waitUntilAdsEligible() async {
    final deadline = _adsEligibleAfter;
    if (deadline == null) return;
    final remaining = deadline.difference(DateTime.now());
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  @visibleForTesting
  bool get debugIsAdsEligible {
    final deadline = _adsEligibleAfter;
    if (deadline == null) return true;
    return !DateTime.now().isBefore(deadline);
  }

  @visibleForTesting
  void debugResetConsentGate() {
    _adsEligibleAfter = null;
  }

  Future<void> startSession() async {
    ServerCap.instance.logConfigurationOnce();
    ServerCapService.instance.logConfigurationOnce();
    await ServerCap.instance.syncIfStale();
    _sessionStart = DateTime.now();
    _sessionPopunders = 0;
    _sessionChannelClicks = 0;
    _channelTapBrowserShown.clear();
    _newsArticleAdShown.clear();
    _sessionInterstitialsShown = 0;
    _sessionInterstitialAttempts = 0;
    _exitAdShown = false;
    _playerVideoAdsShown = 0;
    _lastPlayerVideoAdAt = null;
    _lastIronSourceInterstitial = null;
    _lastAdsterraSurfaceEvent = null;
  }

  void recordChannelClick() => _sessionChannelClicks++;

  int get sessionChannelClicks => _sessionChannelClicks;

  void setAdFreeUntil(DateTime? until) => _adFreeUntil = until;

  bool get isAdFree =>
      _adFreeUntil != null && DateTime.now().isBefore(_adFreeUntil!);

  /// Adsterra popunder / background / direct link — blocks SDK for 30s.
  void recordAdsterraSurfaceEvent() {
    _lastAdsterraSurfaceEvent = DateTime.now();
  }

  Future<bool> _hourlyCountBelow(String prefix, int max) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${prefix}_${_hourKey()}';
    final count = prefs.getInt(key) ?? 0;
    return count < max;
  }

  Future<void> _incrementHourly(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${prefix}_${_hourKey()}';
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);
  }

  Future<int> _dailyCount(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${prefix}_${_dayKey()}') ?? 0;
  }

  Future<void> _incrementDaily(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${prefix}_${_dayKey()}';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  bool get _networkIsolationActive {
    if (_lastAdsterraSurfaceEvent == null) return false;
    final elapsed = DateTime.now().difference(_lastAdsterraSurfaceEvent!);
    return elapsed.inSeconds < AdConfig.networkIsolationSeconds;
  }

  /// When RC `aggressive_mode` is true, cooldowns are 30% shorter (×0.7).
  static int scaledCooldownSeconds(int baseSeconds) {
    if (!AdSafetyService.instance.aggressiveMode) return baseSeconds;
    return (baseSeconds * 0.7).round().clamp(1, baseSeconds);
  }

  Duration get interstitialNaturalDelay {
    final span =
        AdConfig.interstitialDelayMaxMs - AdConfig.interstitialDelayMinMs;
    final ms = AdConfig.interstitialDelayMinMs + _rng.nextInt(span + 1);
    return Duration(milliseconds: ms);
  }

  @visibleForTesting
  void debugBackdateSessionStart(Duration ago) {
    _sessionStart = DateTime.now().subtract(ago);
  }

  @visibleForTesting
  bool debugSessionAllowsInterstitial({
    required bool isStreaming,
    required bool removeAds,
  }) =>
      _sessionAllowsInterstitial(
        isStreaming: isStreaming,
        removeAds: removeAds,
      );

  /// Session funnel: channel clicks, per-session max, cooldown, ad-free.
  bool _sessionAllowsInterstitial({
    required bool isStreaming,
    required bool removeAds,
  }) {
    if (removeAds || isAdFree) return false;
    if (isStreaming) return false;
    final adsEligibleAfter = _adsEligibleAfter;
    if (adsEligibleAfter != null && DateTime.now().isBefore(adsEligibleAfter)) {
      return false;
    }
    if (_sessionChannelClicks < AdConfig.channelClicksBeforeInterstitial) {
      return false;
    }
    if (_sessionInterstitialsShown >= AdConfig.maxInterstitialsPerSession) {
      return false;
    }
    if (_lastIronSourceInterstitial != null) {
      final gap = DateTime.now().difference(_lastIronSourceInterstitial!);
      if (gap.inSeconds < scaledCooldownSeconds(AdConfig.interstitialCooldownSeconds)) {
        return false;
      }
    }
    return true;
  }

  Future<bool> canShowIronSourceInterstitial({
    required bool isStreaming,
    required bool removeAds,
  }) async {
    if (!_sessionAllowsInterstitial(
      isStreaming: isStreaming,
      removeAds: removeAds,
    )) {
      return false;
    }
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    if (_networkIsolationActive) return false;

    if (_lastIronSourceInterstitial != null) {
      final gap = DateTime.now().difference(_lastIronSourceInterstitial!);
      if (gap.inSeconds < scaledCooldownSeconds(AdConfig.interstitialMinGapSeconds)) {
        return false;
      }
    }

    if (!await _hourlyCountBelow(
      'lumio_is_inter',
      AdConfig.interstitialMaxPerHour,
    )) {
      return false;
    }

    if (!await ServerCapService.instance.allowsPlacement('interstitial')) {
      return false;
    }

    return true;
  }

  /// Show requested (preload / `showAd`) — does **not** debit hourly or session caps.
  void recordInterstitialAttempted() {
    _sessionInterstitialAttempts++;
  }

  @visibleForTesting
  int get debugSessionInterstitialAttempts => _sessionInterstitialAttempts;

  @visibleForTesting
  int get debugSessionInterstitialsShown => _sessionInterstitialsShown;

  /// Call only from LevelPlay `onAdDisplayed` (not on close/timeout).
  Future<void> recordInterstitialShown() async {
    _lastIronSourceInterstitial = DateTime.now();
    _sessionInterstitialsShown++;
    await _incrementHourly('lumio_is_inter');
  }

  /// Alias — prefer [recordInterstitialShown].
  Future<void> recordIronSourceInterstitialShown() => recordInterstitialShown();

  Future<bool> canShowRewarded({required bool removeAds}) async {
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    if (removeAds || isAdFree) return false;
    if (!await _hourlyCountBelow(
      'lumio_is_rewarded',
      AdConfig.rewardedMaxPerHour,
    )) {
      return false;
    }
    return ServerCapService.instance.allowsPlacement('rewarded');
  }

  /// Call only from LevelPlay `onAdRewarded` (not on close/timeout).
  Future<void> recordRewardedShown() async {
    await _incrementHourly('lumio_is_rewarded');
  }

  /// App-open substitute (interstitial) — 3/day, 4h gap.
  Future<bool> canShowAppOpenSubstitute({required bool removeAds}) async {
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    if (removeAds || isAdFree) return false;
    if (_networkIsolationActive) return false;

    final daily = await _dailyCount('lumio_app_open');
    if (daily >= AdConfig.appOpenMaxPerDay) return false;

    if (_lastAppOpenSubstitute != null) {
      final gap = DateTime.now().difference(_lastAppOpenSubstitute!);
      if (gap.inHours < AdConfig.appOpenMinGapHours) return false;
    }

    final adsEligibleAfter = _adsEligibleAfter;
    if (adsEligibleAfter != null && DateTime.now().isBefore(adsEligibleAfter)) {
      return false;
    }

    if (!await _hourlyCountBelow(
      'lumio_is_inter',
      AdConfig.interstitialMaxPerHour,
    )) {
      return false;
    }

    return ServerCapService.instance.allowsPlacement('interstitial');
  }

  /// Call only from LevelPlay `onAdDisplayed` for app-open substitute.
  Future<void> recordAppOpenSubstituteShown() async {
    _lastAppOpenSubstitute = DateTime.now();
    await _incrementDaily('lumio_app_open');
    await recordIronSourceInterstitialShown();
  }

  Future<bool> canShowAdsterraDirectLink() async {
    if (!AdSafetyService.instance.adsterraEnabled) return false;
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    final daily = await _dailyCount('lumio_adsterra_direct');
    return daily < AdConfig.adsterraDirectLinkMaxPerDay;
  }

  /// True after first tap on this channel this app session (browser step done).
  bool hasChannelTapBrowserShown(String channelKey) =>
      _channelTapBrowserShown.contains(channelKey);

  void markChannelTapBrowserShown(String channelKey) {
    if (channelKey.isEmpty) return;
    _channelTapBrowserShown.add(channelKey);
  }

  bool hasNewsArticleAdShown(String articleId) =>
      articleId.isNotEmpty && _newsArticleAdShown.contains(articleId);

  void markNewsArticleAdShown(String articleId) {
    if (articleId.isEmpty) return;
    _newsArticleAdShown.add(articleId);
  }

  /// First channel tap → external browser (not limited by splash 3/day direct-link cap).
  ///
  /// Intentionally ignores [AdSafetyService.preferCleanSdkRouting] — user tapped a channel.
  Future<bool> canShowChannelTapBrowser() async {
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    if (!AdSafetyService.instance.adsEnabledRemote) return false;
    return true;
  }

  Future<void> recordAdsterraDirectLink() async {
    recordAdsterraSurfaceEvent();
    await _incrementDaily('lumio_adsterra_direct');
  }

  Future<void> recordChannelTapBrowser() async {
    recordAdsterraSurfaceEvent();
    await _incrementDaily('lumio_channel_tap_browser');
  }

  /// Popunder mount gate — consent, RC, session cap, cooldown (mirrors interstitial eligibility).
  Future<bool> canShowPopunder({bool? removeAds}) async {
    final purchased = removeAds ?? UserPreferences.removeAdsPurchased;
    if (purchased || isAdFree) return false;
    if (!AdConsentService.instance.hasGrantedConsent) return false;
    if (!debugIsAdsEligible) return false;
    if (!AdSafetyService.instance.adsterraEnabled) return false;
    if (AdSafetyService.instance.adsBlockedInDebug) return false;
    if (!_debugIgnoreAdsterraZoneConfig && !AdConfig.hasAdsterraWebViewZones) {
      return false;
    }
    if (_networkIsolationActive) return false;

    final cap = AdSafetyService.instance.popunderSessionCap;
    if (_sessionPopunders >= cap) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt('lumio_popunder_last_ms');
    if (lastMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      if (DateTime.now().difference(last).inSeconds <
          scaledCooldownSeconds(AdConfig.adsterraPopunderCooldownSeconds)) {
        return false;
      }
    }
    return true;
  }

  /// @deprecated Prefer [canShowPopunder].
  Future<bool> canShowAdsterraPopunder() => canShowPopunder();

  @visibleForTesting
  void debugSetSessionPopunders(int count) => _sessionPopunders = count;

  @visibleForTesting
  Future<void> debugClearPopunderCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lumio_popunder_last_ms');
  }

  @visibleForTesting
  Future<bool> debugCanShowPopunder({bool removeAds = false}) =>
      canShowPopunder(removeAds: removeAds);

  @visibleForTesting
  void debugIgnoreAdsterraZoneConfig(bool value) {
    _debugIgnoreAdsterraZoneConfig = value;
  }

  @visibleForTesting
  void debugResetPopunderTestState() {
    _sessionPopunders = 0;
    _debugIgnoreAdsterraZoneConfig = false;
    _adsEligibleAfter = null;
    _lastAdsterraSurfaceEvent = null;
  }

  Future<void> recordAdsterraPopunder() async {
    recordAdsterraSurfaceEvent();
    _sessionPopunders++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'lumio_popunder_last_ms',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Back-press exit stack — does not require session channel-click funnel.
  bool canShowExitAd({required bool removeAds}) {
    if (removeAds || isAdFree || _exitAdShown) return false;
    if (_networkIsolationActive) return false;
    final adsEligibleAfter = _adsEligibleAfter;
    if (adsEligibleAfter != null && DateTime.now().isBefore(adsEligibleAfter)) {
      return false;
    }
    return true;
  }

  void recordExitAdShown() => _exitAdShown = true;

  bool canShowPlayerVideoAd({
    required bool removeAds,
    bool isMidRoll = false,
  }) {
    if (removeAds || isAdFree) return false;
    if (_playerVideoAdsShown >= AdConfig.maxInterstitialsPerSession) {
      return false;
    }
    if (_lastPlayerVideoAdAt != null) {
      final minGap = isMidRoll
          ? Duration(minutes: AdConfig.playerMidRollIntervalMinutes)
          : const Duration(seconds: 30);
      if (DateTime.now().difference(_lastPlayerVideoAdAt!) < minGap) {
        return false;
      }
    }
    return true;
  }

  void recordPlayerVideoAdShown() {
    _playerVideoAdsShown++;
    _lastPlayerVideoAdAt = DateTime.now();
  }
}
