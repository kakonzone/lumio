import 'package:flutter/material.dart';

import '../../services/ad_safety_service.dart';
import '../ad_manager.dart';
import '../utils/webview_pool.dart';
import '../../services/adsterra_webview_service.dart';

/// Sticky social bar above bottom nav — single instance, kept alive across tabs.
class GlobalSocialBar extends StatefulWidget {
  const GlobalSocialBar({super.key});

  static const double barHeight = 50;
  static const double bottomNavClearance = 64;

  @override
  State<GlobalSocialBar> createState() => _GlobalSocialBarState();
}

class _GlobalSocialBarState extends State<GlobalSocialBar>
    with AutomaticKeepAliveClientMixin {
  bool _acquired = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _acquired = WebViewPool.instance.acquire('social_bar');
  }

  @override
  void dispose() {
    if (_acquired) WebViewPool.instance.release('social_bar');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_acquired) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: AdManager.instance.adChromeHidden,
      builder: (context, hidden, _) {
        if (hidden) return const SizedBox.shrink();
        return _buildBar(context);
      },
    );
  }

  Widget _buildBar(BuildContext context) {
    if (!AdManager.instance.adsEnabled) return const SizedBox.shrink();
    if (!AdSafetyService.instance.adsterraEnabled) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: SizedBox(
        height: GlobalSocialBar.barHeight,
        width: double.infinity,
        child: AdsterraWebViewService.socialBar(),
      ),
    );
  }
}


/// Shell-level host: one social bar instance above bottom navigation.
class GlobalSocialBarHost extends StatelessWidget {
  const GlobalSocialBarHost({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: 0,
      right: 0,
      bottom: GlobalSocialBar.bottomNavClearance,
      height: GlobalSocialBar.barHeight,
      child: GlobalSocialBar(),
    );
  }
}
