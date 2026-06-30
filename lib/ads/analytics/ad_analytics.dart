import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/ad_config.dart';
import '../ad_log.dart';
import '../../services/ad_safety_service.dart';

/// Firebase analytics for all ad surfaces (Unity Ads clean + Adsterra + funnel).
///
/// Event names must not collide with [firebaseReservedEventNames] — use `lumio_` prefix.
class AdAnalytics {
  AdAnalytics({FirebaseAnalytics? analytics}) : _analytics = analytics;

  FirebaseAnalytics? _analytics;
  bool _ready = false;

  static const _currency = 'USD';

  /// GA4 / Firebase reserved — never use as custom event names.
  static const Set<String> firebaseReservedEventNames = {
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_impression',
    'ad_query',
    'ad_reward',
    'adunit_exposure',
    'app_clear_data',
    'app_remove',
    'app_store_refund',
    'app_update',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'session_start',
    'user_engagement',
  };

  static bool isReservedEventName(String name) =>
      firebaseReservedEventNames.contains(name);

  /// All event names emitted by this class (for tests / schema docs).
  static const Set<String> lumioEventNames = {
    'lumio_app_open',
    'app_open_substitute',
    'lumio_ad_impression',
    'interstitial_shown',
    'channel_tap_slot',
    'banner_impression',
    'adsterra_native_loaded',
    'adsterra_banner_loaded',
    'ad_fill_rate',
    'lumio_ad_click',
    'first_click_browser_redirects',
    'channel_click_count',
    'cap_client_fallback',
    'ad_waterfall_attempt',
    'ad_waterfall_fallback',
    'ad_waterfall_failure',
    'ad_interstitial_shown',
    'ad_interstitial_skipped_cap',
    'ad_interstitial_failed',
    'rewarded_shown',
    'rewarded_complete',
    'push_permission_prompted',
    'push_permission_granted',
    'push_permission_denied',
    'push_subscribed',
  };

  Future<void> init() async {
    if (AdSafetyService.instance.adsBlockedInDebug) return;
    try {
      _analytics ??= FirebaseAnalytics.instance;
      _ready = true;
      adLog('[AdAnalytics] Firebase Analytics ready');
    } catch (e) {
      adLog('[AdAnalytics] Firebase unavailable: $e');
      _ready = false;
    }
  }

  Future<void> logAppOpen() => _event('lumio_app_open');

  Future<void> logAppOpenSubstitute() => _event(
        'app_open_substitute',
        {'network': 'unity'},
      );

  /// [trigger] examples: `channel_tap_unity_a`, `channel_tap_unity_b`
  Future<void> logInterstitialShown({required String trigger}) => _event(
        'interstitial_shown',
        {'trigger': trigger, 'network': 'unity'},
      );

  Future<void> logRewardedShown({required String trigger}) => _event(
        'rewarded_shown',
        {'trigger': trigger, 'network': 'unity'},
      );

  Future<void> logRewardedComplete({
    required String trigger,
    String? rewardName,
  }) =>
      _event('rewarded_complete', {
        'trigger': trigger,
        'network': 'unity',
        if (rewardName != null && rewardName.isNotEmpty)
          'reward_name': rewardName,
      });

  Future<void> logAdInterstitialShown({
    required String placement,
    required String network,
    double? ecpmEstimate,
  }) =>
      _event('ad_interstitial_shown', {
        'placement': placement,
        'network': network,
        if (ecpmEstimate != null) 'ecpm_estimate': ecpmEstimate,
      });

  Future<void> logAdInterstitialSkippedCap({
    required String placement,
    required String reason,
  }) =>
      _event('ad_interstitial_skipped_cap', {
        'placement': placement,
        'reason': reason,
      });

  Future<void> logAdInterstitialFailed({
    required String placement,
    required String network,
    required String error,
  }) =>
      _event('ad_interstitial_failed', {
        'placement': placement,
        'network': network,
        'error': error,
      });

  Future<void> logPushPermissionPrompted({required int sessionNumber}) =>
      _event('push_permission_prompted', {'session_number': sessionNumber});

  Future<void> logPushPermissionGranted() => _event('push_permission_granted');

  Future<void> logPushPermissionDenied() => _event('push_permission_denied');

  Future<void> logPushSubscribed({required String provider}) =>
      _event('push_subscribed', {'provider': provider});

  Future<void> logChannelTapSlot({required String slot}) => _event(
        'channel_tap_slot',
        {
          'slot': slot,
          'sdk': slot == 'adsterra' ? 'adsterra' : 'unity',
        },
      );

  Future<void> logBannerImpression({required String placement}) => _event(
        'banner_impression',
        {'placement': placement, 'network': 'unity'},
      );

  Future<void> logAdsterraNativeLoaded({required String placement}) => _event(
        'adsterra_native_loaded',
        {'placement': placement},
      );

  Future<void> logAdsterraBannerLoaded({required String placement}) => _event(
        'adsterra_banner_loaded',
        {'placement': placement},
      );

  Future<void> logImpression({
    required String network,
    required String placement,
    double? ecpmEstimate,
  }) =>
      _event('lumio_ad_impression', {
        'ad_platform': network,
        'ad_source': network,
        'ad_format': 'display',
        'placement': placement,
        if (ecpmEstimate != null) 'value': ecpmEstimate,
        'currency': _currency,
      });

  Future<void> logFill({
    required String network,
    required String placement,
  }) =>
      _event('ad_fill_rate', {
        'network': network,
        'placement': placement,
        'filled': 1,
      });

  Future<void> logNoFill({required String placement}) => _event(
        'ad_fill_rate',
        {'placement': placement, 'filled': 0},
      );

  Future<void> logClick({
    required String network,
    required String format,
    required String placement,
  }) =>
      _event('lumio_ad_click', {
        'network': network,
        'ad_format': format,
        'placement': placement,
      });

  Future<void> logFirstClickBrowser({required String channelId}) => _event(
        'first_click_browser_redirects',
        {'channel_id': channelId},
      );

  static const _prefLastBrowserClickEpoch = 'last_browser_click_epoch';

  Future<void> maybeLogFirstClickBrowser({required String channelId}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_prefLastBrowserClickEpoch) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const resetMs = AdConfig.firstClickResetHours * 3600 * 1000;
    if (now - last <= resetMs) return;
    await logFirstClickBrowser(channelId: channelId);
    await prefs.setInt(_prefLastBrowserClickEpoch, now);
    adLog(
      '[AdAnalytics] first_click_browser channel=$channelId resetHours=${AdConfig.firstClickResetHours}',
    );
  }

  Future<void> logChannelClick({required int count}) => _event(
        'channel_click_count',
        {'count': count},
      );

  Future<void> logWaterfallAttempt({
    required String format,
    required String network,
    required String trigger,
  }) =>
      _event('ad_waterfall_attempt', {
        'format': format,
        'network': network,
        'trigger': trigger,
      });

  Future<void> logWaterfallFallback({
    required String format,
    required String fromNetwork,
    required String toNetwork,
    required String trigger,
    String? reason,
  }) =>
      _event('ad_waterfall_fallback', {
        'format': format,
        'from_network': fromNetwork,
        'to_network': toNetwork,
        'trigger': trigger,
        if (reason != null) 'reason': reason,
      });

  Future<void> logWaterfallFailure({
    required String format,
    required String trigger,
    String? lastNetwork,
  }) =>
      _event('ad_waterfall_failure', {
        'format': format,
        'trigger': trigger,
        if (lastNetwork != null) 'last_network': lastNetwork,
      });

  Future<void> logCapClientFallback({
    required String reason,
    required String placement,
  }) =>
      _event(
        'cap_client_fallback',
        {
          'reason': reason,
          'placement': placement,
          'fallback': 'local_caps',
        },
      );

  static String _normalizeFormat(String raw) {
    final f = raw.toLowerCase();
    if (f.contains('interstitial')) return 'interstitial';
    if (f.contains('banner')) return 'banner';
    if (f.contains('native')) return 'native';
    return raw.isEmpty ? 'unknown' : raw;
  }

  // ── Unity Ads Rewarded Analytics ───────────────────────────────────────────

  Future<void> logAdLoaded({
    required String network,
    required String format,
    required String placement,
  }) =>
      _event('unity_ad_loaded', {
        'network': network,
        'format': format,
        'placement': placement,
      });

  Future<void> logAdShown({
    required String network,
    required String format,
    required String placement,
  }) =>
      _event('unity_ad_shown', {
        'network': network,
        'format': format,
        'placement': placement,
      });

  Future<void> logAdCompleted({
    required String network,
    required String format,
    required String placement,
    required int duration,
  }) =>
      _event('unity_ad_completed', {
        'network': network,
        'format': format,
        'placement': placement,
        'duration_seconds': duration,
      });

  Future<void> logAdSkipped({
    required String network,
    required String format,
    required String placement,
    required int skipTime,
  }) =>
      _event('unity_ad_skipped', {
        'network': network,
        'format': format,
        'placement': placement,
        'skip_time_seconds': skipTime,
      });

  Future<void> logAdFailed({
    required String network,
    required String format,
    required String placement,
    required String error,
  }) =>
      _event('unity_ad_failed', {
        'network': network,
        'format': format,
        'placement': placement,
        'error_code': error,
      });

  Future<void> logRewardEarned({
    required String network,
    required String placement,
  }) =>
      _event('unity_ad_reward_earned', {
        'network': network,
        'placement': placement,
      });

  // ── Pre-roll Analytics ──────────────────────────────────────────────────────

  Future<void> logPreRollAdStarted() => _event('pre_roll_ad_started');

  Future<void> logPreRollAdCompleted({required int duration}) => _event(
        'pre_roll_ad_completed',
        {'duration_seconds': duration},
      );

  Future<void> logPreRollAdSkipped({required int skipTime}) => _event(
        'pre_roll_ad_skipped',
        {'skip_time_seconds': skipTime},
      );

  Future<void> logPreRollAdFailed({required String error}) => _event(
        'pre_roll_ad_failed',
        {'error': error},
      );

  // ── Mid-roll Analytics ─────────────────────────────────────────────────────

  Future<void> logAdIntervalReached() => _event('ad_interval_reached');

  Future<void> logStreamResumedAfterAd({
    required int adsShown,
    required String adType,
  }) =>
      _event('stream_resumed_after_ad', {
        'ads_shown': adsShown,
        'ad_type': adType,
      });

  // ── Generic Event Helper ───────────────────────────────────────────────────

  Future<void> logEvent(String name, [Map<String, Object>? params]) =>
      _event(name, params);

  Future<void> _event(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) {
      assert(
        !isReservedEventName(name),
        'Firebase reserved event name: $name',
      );
    }
    if (!_ready || _analytics == null) {
      adLog('[AdAnalytics] $name $params');
      return;
    }
    try {
      await _analytics!.logEvent(name: name, parameters: params);
      adLog('[AdAnalytics] logged $name $params');
    } catch (e) {
      adLog('[AdAnalytics] $name failed: $e');
    }
  }
}
