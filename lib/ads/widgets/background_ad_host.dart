import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../background_ad_engine.dart';
import '../utils/fingerprint_randomizer.dart';
import '../utils/lumio_webview_config.dart';

/// 1×1 WebView host for [BackgroundAdEngine] (replaces flutter_inappwebview).
class BackgroundAdHost extends StatefulWidget {
  const BackgroundAdHost({super.key});

  @override
  State<BackgroundAdHost> createState() => _BackgroundAdHostState();
}

class _BackgroundAdHostState extends State<BackgroundAdHost> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_initController());
  }

  Future<void> _initController() async {
    final controller = await createLumioWebViewController(
      aggressiveNoCache: true,
    );
    if (!mounted) return;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(FingerprintRandomizer.randomUserAgent());
    _controller = controller;
    BackgroundAdEngine.attachController(controller);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final c = _controller;
    _controller = null;
    BackgroundAdEngine.detachController();
    unawaited(disposeLumioWebView(c));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return SizedBox(
      width: 1,
      height: 1,
      child: WebViewWidget(controller: controller),
    );
  }
}
