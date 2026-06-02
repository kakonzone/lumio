import 'package:flutter/material.dart';

import 'adsterra_html.dart';
import 'adsterra_webview.dart';

/// Sticky social bar (50px).
class AdsterraSocialBar extends StatelessWidget {
  const AdsterraSocialBar({
    super.key,
    this.placement = 'social_bar',
    this.userVisible = true,
  });

  final String placement;
  final bool userVisible;

  @override
  Widget build(BuildContext context) {
    return AdsterraWebView(
      html: AdsterraHtml.socialBar(),
      height: 50,
      placement: placement,
      userVisible: userVisible,
    );
  }
}
