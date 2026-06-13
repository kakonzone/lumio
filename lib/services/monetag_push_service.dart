import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ads/ad_log.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../ads/analytics/ad_analytics.dart';
import '../ads/propeller/propeller_html.dart';
import '../config/ad_config.dart';
import '../config/ad_policy_config.dart';
import '../config/monetag_config.dart';
import 'ad_consent_service.dart';
import 'app_session_tracker.dart';

/// Monetag push monetization — permission on Nth session, zone from Remote Config.
class MonetagPushService {
  MonetagPushService._();
  static final MonetagPushService instance = MonetagPushService._();

  static const _channel = MethodChannel('com.kakonzone.lumio/monetag_push');
  static const _prefSubscribed = 'push_subscribed';
  static const _prefPromptCount = 'push_prompt_count';
  static const _prefLastPromptTs = 'push_last_prompt_ts';

  final AdAnalytics _analytics = AdAnalytics();

  /// Call from [MainShell] after home is visible (replaces first-launch silent pass).
  Future<void> maybePromptOnHomeLoad(BuildContext context) async {
    if (!Platform.isAndroid) return;
    if (!AdConfig.pushSubscriptionPromptEnabled) return;
    final policy = AdPolicyConfig.instance;
    if (!policy.pushMonetizationEnabled) return;
    if (!AdConsentService.instance.hasGrantedConsent) return;

    final zoneId = policy.monetagPushZoneId;
    if (zoneId.isEmpty) {
      if (kDebugMode) {
        debugPrint('[MonetagPush] skip — monetag_push_zone_id empty');
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    if (prefs.getBool(_prefSubscribed) == true) return;

    await AppSessionTracker.instance.onAppLaunch();
    if (!context.mounted) return;
    final session = AppSessionTracker.instance.sessionNumber;
    if (session < policy.pushPromptOnSessionNumber) return;

    final lastPromptMs = prefs.getInt(_prefLastPromptTs);
    if (lastPromptMs != null) {
      final last = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      final retryAfter = Duration(days: policy.pushRetryAfterDays);
      if (DateTime.now().difference(last) < retryAfter) return;
    }

    if (!context.mounted) return;
    await _showPermissionDialog(context, session: session);
  }

  Future<void> _showPermissionDialog(
    BuildContext context, {
    required int session,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final promptCount = (prefs.getInt(_prefPromptCount) ?? 0) + 1;
    await prefs.setInt(_prefPromptCount, promptCount);
    await prefs.setInt(
      _prefLastPromptTs,
      DateTime.now().millisecondsSinceEpoch,
    );
    unawaited(_analytics.logPushPermissionPrompted(sessionNumber: session));

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Match alerts'),
        content: const Text(
          'Get live match and channel reminders. You can turn these off anytime in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (granted == true) {
      final ok = await _requestSystemPermission();
      if (ok) {
        unawaited(_analytics.logPushPermissionGranted());
        await _registerMonetag(
            zoneId: AdPolicyConfig.instance.monetagPushZoneId);
      } else {
        unawaited(_analytics.logPushPermissionDenied());
      }
    } else {
      unawaited(_analytics.logPushPermissionDenied());
    }
  }

  Future<bool> _requestSystemPermission() async {
    if (!Platform.isAndroid) return false;
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  Future<void> _registerMonetag({required String zoneId}) async {
    var ok = false;
    try {
      ok = await _channel.invokeMethod<bool>('register', {
            'zoneId': zoneId,
            'scriptUrl': _pushScriptUrlForZone(zoneId),
          }) ??
          false;
    } catch (e) {
      if (kDebugMode) debugPrint('[MonetagPush] native register: $e');
    }
    if (!ok) {
      ok = await _subscribeViaWebView(zoneId);
    }
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSubscribed, true);
      unawaited(_analytics.logPushSubscribed(provider: 'monetag'));
      adLog('[MonetagPush] subscribed zone=$zoneId');
    }
  }

  String _pushScriptUrlForZone(String zoneId) {
    final template = MonetagConfig.pushScriptUrl.trim();
    if (template.isEmpty) return '';
    if (template.contains('{zone}')) {
      return template.replaceAll('{zone}', zoneId);
    }
    if (template.contains('ZONE_ID')) {
      return template.replaceAll('ZONE_ID', zoneId);
    }
    final uri = Uri.tryParse(template);
    if (uri != null) {
      return uri.replace(
        queryParameters: {...uri.queryParameters, 'zone': zoneId},
      ).toString();
    }
    return template;
  }

  Future<bool> _subscribeViaWebView(String zoneId) async {
    final scriptUrl = _pushScriptUrlForZone(zoneId);
    if (scriptUrl.isEmpty) return false;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000));

    final html = '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<base href="${PropellerHtml.baseUrlForPlacement('push')}">
</head>
<body style="margin:0;background:#000">
<script src="$scriptUrl" data-zone="$zoneId" data-cfasync="false" async></script>
</body>
</html>
''';

    try {
      await controller.loadHtmlString(
        html,
        baseUrl: AdsterraHtml.baseUrlForPlacement('popunder'),
      );
      await Future.delayed(const Duration(seconds: 3));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[MonetagPush] WebView subscribe failed: $e');
      return false;
    }
  }
}
