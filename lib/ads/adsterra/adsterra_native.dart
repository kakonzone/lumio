import 'package:flutter/material.dart';

import 'adsterra_html.dart';
import 'adsterra_webview.dart';

/// Adsterra native-style banner (100–250px).
class AdsterraNativeBanner extends StatelessWidget {
  final double height;
  final String placement;
  final bool userVisible;

  const AdsterraNativeBanner({
    super.key,
    this.height = 100,
    this.placement = 'native_top',
    this.userVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AdsterraWebView(
      html: AdsterraHtml.nativeBanner(height: height),
      height: height,
      placement: placement,
      userVisible: userVisible,
    );
  }
}
