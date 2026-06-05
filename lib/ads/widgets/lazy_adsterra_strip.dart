import 'package:flutter/material.dart';

import '../ad_manager.dart';
import '../adsterra/adsterra_banner.dart';
import '../adsterra/adsterra_native.dart';
import '../utils/lazy_ad_viewport.dart';

/// Top/list ad strip: zero layout gap until near viewport (Home pattern).
class LazyAdsterraBanner728 extends StatelessWidget {
  const LazyAdsterraBanner728({
    super.key,
    required this.placement,
    this.preloadPx = 320,
  });

  final String placement;
  final double preloadPx;

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.showAdsterraWebViewSlots) {
      return const SizedBox.shrink();
    }
    return LazyAdViewport(
      placeholderHeight: 0,
      preloadPx: preloadPx,
      builder: () => AdsterraBanner728(placement: placement),
    );
  }
}

class LazyAdsterraNativeBanner extends StatelessWidget {
  const LazyAdsterraNativeBanner({
    super.key,
    required this.placement,
    this.height = 100,
    this.preloadPx = 320,
  });

  final String placement;
  final double height;
  final double preloadPx;

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.showAdsterraWebViewSlots) {
      return const SizedBox.shrink();
    }
    return LazyAdViewport(
      placeholderHeight: 0,
      preloadPx: preloadPx,
      builder: () => AdsterraNativeBanner(
        placement: placement,
        height: height,
      ),
    );
  }
}
