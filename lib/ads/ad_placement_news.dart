import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ad_manager.dart';
import 'ad_placement_config.dart';
import 'adsterra/adsterra_banner.dart';
import '../widgets/ad_list_injector.dart';

/// Injects Adsterra natives into NEWS article list (every 5, or 4 aggressive).
class AdPlacementNews {
  AdPlacementNews._();

  @visibleForTesting
  static bool shouldInjectAdAt(
    int index,
    int interval, {
    required bool adsOn,
  }) {
    if (!adsOn || interval <= 0) return false;
    return index > 0 && (index + 1) % interval == 0;
  }

  @visibleForTesting
  static int countInjectedAds({
    required int articleCount,
    required int interval,
    required bool adsOn,
  }) {
    if (!adsOn || articleCount <= 0 || interval <= 0) return 0;
    var count = 0;
    for (var i = 0; i < articleCount; i++) {
      if (shouldInjectAdAt(i, interval, adsOn: adsOn)) count++;
    }
    return count;
  }

  static List<Widget> buildArticleList({
    required Widget Function(int index) buildArticleAt,
    required int articleCount,
  }) {
    if (articleCount <= 0) return [];
    final interval = AdPlacementConfig.newsNativeInterval;
    final adsOn = AdManager.instance.showAdsterraWebViewSlots;
    final out = <Widget>[];
    for (var i = 0; i < articleCount; i++) {
      if (adsOn && i == 2) {
        out.add(
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AdsterraBanner728(placement: 'news_mid_banner'),
          ),
        );
      }
      if (shouldInjectAdAt(i, interval, adsOn: adsOn)) {
        final slot = (i + 1) ~/ interval;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AdListInjector.nativeAd(
              key: ValueKey('news_native_$slot'),
              placement: 'news_inline_$slot',
            ),
          ),
        );
      }
      out.add(buildArticleAt(i));
    }
    return out;
  }
}
