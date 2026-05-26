import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/adsterra/adsterra_direct_link.dart';
import '../config/ad_config.dart';
import 'analytics/ad_analytics.dart';
import '../services/ad_safety_service.dart';
import '../utils/ad_debug_log.dart';
import '../services/ad_trigger_manager.dart';

/// Visible Adsterra layer — direct link, smartlink (user-initiated / capped).
class AdsterraEngine {
  AdsterraEngine._();
  static final AdsterraEngine instance = AdsterraEngine._();

  /// External browser for channel-tap rotation (Adsterra slot).
  Future<bool> openChannelTapBrowser({
    required String placement,
    AdAnalytics? analytics,
    String? channelIdForFirstClick,
  }) async {
    // Channel-tap browser is user-initiated; do not apply [preferCleanSdkRouting]
    // (that gate is for automated Adsterra WebView / popunder via [adsterraEnabled]).
    if (!AdConfig.hasAdsterraDirectLink) {
      AdDebugLog.info(
        'AdsterraEngine.openChannelTapBrowser',
        'blocked — no ADSTERRA_DIRECT_LINK(S) configured',
      );
      return false;
    }
    if (!AdSafetyService.instance.adsEnabledRemote) {
      AdDebugLog.info(
        'AdsterraEngine.openChannelTapBrowser',
        'blocked — ads_enabled remote config off',
      );
      return false;
    }
    if (!await AdTriggerManager.instance.canShowChannelTapBrowser()) {
      AdDebugLog.info(
        'AdsterraEngine.openChannelTapBrowser',
        'blocked — debug ads gate',
      );
      return false;
    }
    final ok = await AdsterraDirectLink.openChannelTapInBrowser();
    if (!ok) {
      AdDebugLog.info(
        'AdsterraEngine.openChannelTapBrowser',
        'external browser launch failed',
      );
      return false;
    }

    await AdTriggerManager.instance.recordChannelTapBrowser();
    logAdsterraTelemetry(placement: placement, format: 'direct_link_browser');
    final a = analytics;
    if (a != null) {
      unawaited(
        a.logClick(
          network: 'adsterra',
          format: 'direct_link',
          placement: placement,
        ),
      );
      if (channelIdForFirstClick != null && channelIdForFirstClick.isNotEmpty) {
        unawaited(
          a.maybeLogFirstClickBrowser(channelId: channelIdForFirstClick),
        );
      }
    }
    return true;
  }

  /// First news headline tap — rotated Adsterra direct link in external browser.
  Future<bool> openNewsArticleBrowser({
    required String placement,
    AdAnalytics? analytics,
    String? articleId,
  }) async {
    return openChannelTapBrowser(
      placement: placement,
      analytics: analytics,
      channelIdForFirstClick: articleId,
    );
  }

  Future<bool> openDirectLink({
    required String placement,
    AdAnalytics? analytics,
    String? channelIdForFirstClick,
  }) async {
    if (!AdSafetyService.instance.adsterraEnabled) return false;
    if (!await AdTriggerManager.instance.canShowAdsterraDirectLink()) {
      return false;
    }
    final ok = await AdsterraDirectLink.open();
    if (ok) {
      await AdTriggerManager.instance.recordAdsterraDirectLink();
      logAdsterraTelemetry(placement: placement, format: 'direct_link');
      if (analytics != null) {
        unawaited(
          analytics.logClick(
            network: 'adsterra',
            format: 'direct_link',
            placement: placement,
          ),
        );
        if (channelIdForFirstClick != null &&
            channelIdForFirstClick.isNotEmpty) {
          unawaited(
            analytics.maybeLogFirstClickBrowser(
              channelId: channelIdForFirstClick,
            ),
          );
        }
      }
    }
    return ok;
  }

  Future<bool> openSmartlink({
    required String placement,
    required BuildContext context,
  }) async {
    return openDirectLink(placement: placement);
  }
}
