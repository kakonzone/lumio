import 'package:flutter/material.dart';

import '../config/ad_config.dart';
import 'adcash/adcash_webview.dart';
import 'adsterra/adsterra_webview.dart';

/// Rotates between Adsterra and Adcash banner ads.
class BannerRotator extends StatefulWidget {
  final String placement;
  final double height;
  final bool fullWidth;

  const BannerRotator({
    super.key,
    required this.placement,
    this.height = 90,
    this.fullWidth = true,
  });

  @override
  State<BannerRotator> createState() => _BannerRotatorState();
}

class _BannerRotatorState extends State<BannerRotator> {
  bool _showAdcash = false;

  @override
  void initState() {
    super.initState();
    // Alternate between Adsterra and Adcash
    _showAdcash = DateTime.now().millisecond % 2 == 0;
  }

  @override
  Widget build(BuildContext context) {
    // Show Adcash if configured, otherwise fallback to Adsterra
    if (_showAdcash && AdConfig.hasAdcashConfig) {
      return AdcashWebView(
        placement: widget.placement,
        height: widget.height,
        fullWidth: widget.fullWidth,
      );
    }

    // Fallback to Adsterra banner
    if (AdConfig.hasAdsterraBanner728) {
      return AdsterraWebView(
        html: _getAdsterraBannerHtml(),
        height: widget.height,
        placement: widget.placement,
        fullWidth: widget.fullWidth,
      );
    }

    return const SizedBox.shrink();
  }

  String _getAdsterraBannerHtml() {
    // Industrial banner HTML for Adsterra
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { margin: 0; padding: 0; overflow: hidden; }
    #adsterra-banner { width: 100%; height: 100%; }
  </style>
  <script src="${AdConfig.adsterraBanner728InvokeUrl}"></script>
</head>
<body>
  <div id="${AdConfig.adsterraBanner728ContainerId}"></div>
</body>
</html>
    ''';
  }
}
