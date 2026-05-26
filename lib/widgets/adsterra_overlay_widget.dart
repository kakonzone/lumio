import 'package:flutter/material.dart';

import '../ads/ad_placement_config.dart';
import '../services/ad_safety_service.dart';
import '../services/adsterra_webview_service.dart';

/// Sticky Adsterra social bar — all main tabs when `aggressive_mode` RC is on.
class AdsterraOverlayWidget extends StatelessWidget {
  const AdsterraOverlayWidget({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdPlacementConfig.showGlobalSocialBarOverlay) {
      return const SizedBox.shrink();
    }
    if (!AdSafetyService.instance.adsterraEnabled) {
      return const SizedBox.shrink();
    }
    return AdsterraWebViewService.socialBar();
  }
}
