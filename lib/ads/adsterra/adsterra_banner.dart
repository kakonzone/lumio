import 'package:flutter/material.dart';

import '../ad_manager.dart';
import 'adsterra_html.dart';
import 'adsterra_webview.dart';

/// Adsterra 728×90 style banner strip.
class AdsterraBanner728 extends StatelessWidget {
  const AdsterraBanner728({
    super.key,
    this.placement = 'banner_728',
    this.userVisible = true,
  });

  final String placement;
  final bool userVisible;

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.showAdsterraWebViewSlots) {
      return const SizedBox.shrink();
    }
    return AdsterraWebView(
      html: AdsterraHtml.banner728x90(),
      height: 90,
      placement: placement,
      userVisible: userVisible,
    );
  }
}
