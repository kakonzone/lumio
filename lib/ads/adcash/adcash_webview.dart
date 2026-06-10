import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ad_log.dart';
import '../../config/ad_config.dart';
import '../../core/ads/webview_ad_host.dart';
import '../utils/lumio_webview_config.dart';
import '../../utils/ad_debug_log.dart';

/// Adcash WebView banner host with zone-based script injection.
class AdcashWebView extends StatefulWidget {
  final double height;
  final String placement;
  final bool fullWidth;
  final bool userVisible;

  const AdcashWebView({
    super.key,
    required this.height,
    required this.placement,
    this.fullWidth = true,
    this.userVisible = true,
  });

  @override
  State<AdcashWebView> createState() => _AdcashWebViewState();
}

class _AdcashWebViewState extends State<AdcashWebView> {
  WebViewController? _controller;
  bool _hasPainted = false;
  bool _loadLogged = false;

  String get _adcashHtml {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; overflow: hidden; }
    #adcash-container { width: 100%; height: 100%; }
  </style>
  <script type="text/javascript">
    aclib.runAutoTag({
      zoneId: '${AdConfig.adcashScriptZoneId}',
    });
  </script>
</head>
<body>
  <div id="adcash-container"></div>
</body>
</html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.hasAdcashConfig) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: widget.height,
      width: widget.fullWidth ? double.infinity : null,
      child: Opacity(
        opacity: widget.userVisible ? 1.0 : 0.0,
        child: WebViewWidget(
          controller: _controller ?? _createController(),
        ),
      ),
    );
  }

  WebViewController _createController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _onPageFinished(),
          onNavigationRequest: (request) {
            // Block all navigation to prevent opening external links
            return NavigationAction.prevent;
          },
        ),
      )
      ..loadHtmlString(_adcashHtml);
  }

  Future<void> _onPageFinished() async {
    if (_loadLogged) return;
    _loadLogged = true;

    adLog('[Adcash] page finished: ${widget.placement}');
    logAdsterraTelemetry(
      placement: widget.placement,
      format: 'adcash_webview',
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = _createController();
    adLog('[Adcash] init: ${widget.placement}');
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
}
