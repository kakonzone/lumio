import 'package:flutter/material.dart';

import 'propeller_html.dart';
import '../adsterra/adsterra_webview.dart';

/// Monetag WebView host (reuses hardened Adsterra WebView delegate).
class PropellerWebView extends StatelessWidget {
  const PropellerWebView({
    super.key,
    required this.html,
    required this.height,
    required this.placement,
    this.fullWidth = true,
    this.userVisible = true,
  });

  final String html;
  final double height;
  final String placement;
  final bool fullWidth;
  final bool userVisible;

  @override
  Widget build(BuildContext context) {
    return AdsterraWebView(
      html: html,
      height: height,
      placement: 'monetag_$placement',
      fullWidth: fullWidth,
      userVisible: userVisible,
    );
  }
}

/// In-page push strip (list / player sticky).
class PropellerInPagePushBanner extends StatelessWidget {
  const PropellerInPagePushBanner({
    super.key,
    this.placement = 'inpage_push',
    this.height = 50,
    this.userVisible = true,
  });

  final String placement;
  final double height;
  final bool userVisible;

  @override
  Widget build(BuildContext context) {
    return PropellerWebView(
      html: PropellerHtml.inPagePush(minHeight: height),
      height: height,
      placement: placement,
      userVisible: userVisible,
    );
  }
}
