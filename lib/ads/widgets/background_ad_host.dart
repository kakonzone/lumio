import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/logging/safe_logger.dart';
import '../background_ad_engine.dart';
import '../fake_session_store.dart';
import '../utils/lumio_webview_config.dart';

/// 1×1 WebView host for [BackgroundAdEngine] (replaces flutter_inappwebview).
class BackgroundAdHost extends StatefulWidget {
  const BackgroundAdHost({super.key});

  @override
  State<BackgroundAdHost> createState() => _BackgroundAdHostState();
}

class _BackgroundAdHostState extends State<BackgroundAdHost> with WidgetsBindingObserver {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FakeSessionStore.initialize();
    BackgroundAdEngine.bindGlobalStreamingState();
    unawaited(_initController());
  }

  Future<void> _initController() async {
    final controller = await createLumioWebViewController(
      aggressiveNoCache: true,
    );
    if (!mounted) return;
    
    // Get session-specific attributes
    final session = FakeSessionStore.getNextSession();
    
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(session.userAgent);
    
    // Apply session-specific headers if supported
    // Note: webview_flutter doesn't support per-request headers in loadRequest
    // This is handled in background_ad_engine.dart for rotation
    
    _controller = controller;
    BackgroundAdEngine.attachController(controller);
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        BackgroundAdEngine.onAppForegrounded();
        BackgroundAdEngine.resume();
        break;
      case AppLifecycleState.inactive:
        BackgroundAdEngine.pause();
        break;
      case AppLifecycleState.paused:
        BackgroundAdEngine.pause();
        break;
      case AppLifecycleState.detached:
        BackgroundAdEngine.dispose();
        break;
      case AppLifecycleState.hidden:
        BackgroundAdEngine.pause();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    BackgroundAdEngine.detachController();
    BackgroundAdEngine.dispose();
    unawaited(disposeLumioWebView(c));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}
