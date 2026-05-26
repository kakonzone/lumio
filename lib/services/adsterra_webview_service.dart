import 'package:flutter/material.dart';

import '../ads/adsterra/adsterra_banner.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../ads/adsterra/adsterra_social_bar.dart';
import '../services/ad_safety_service.dart';

/// Routes Adsterra WebView widgets by zone type.
class AdsterraWebViewService {
  AdsterraWebViewService._();

  static Widget banner728({required String placement}) {
    if (!AdSafetyService.instance.adsterraEnabled) {
      return const SizedBox.shrink();
    }
    return AdsterraBanner728(placement: placement);
  }

  static Widget native({required String placement, double height = 100}) {
    if (!AdSafetyService.instance.adsterraEnabled) {
      return const SizedBox.shrink();
    }
    return AdsterraNativeBanner(height: height, placement: placement);
  }

  static Widget socialBar() {
    if (!AdSafetyService.instance.adsterraEnabled) {
      return const SizedBox.shrink();
    }
    return const AdsterraSocialBar();
  }
}
