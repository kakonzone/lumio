import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../ads/utils/lumio_webview_config.dart';

class FullscreenInterstitialAd extends StatefulWidget {
  final String adHtml;          // Adsterra banner snippet
  final int skipAfterSeconds;   // 5 sec
  final VoidCallback onDismiss;
  final String placement;

  const FullscreenInterstitialAd({
    super.key,
    required this.adHtml,
    required this.onDismiss,
    this.skipAfterSeconds = 5,
    this.placement = 'interstitial',
  });

  @override
  State<FullscreenInterstitialAd> createState() =>
      _FullscreenInterstitialAdState();
}

class _FullscreenInterstitialAdState extends State<FullscreenInterstitialAd> {
  WebViewController? _controller;
  late int _secondsLeft;
  Timer? _ticker;
  Timer? _failsafe;
  bool _canSkip = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.skipAfterSeconds;
    _initWebView();
    _startTimers();
  }

  Future<void> _initWebView() async {
    final controller = await createLumioWebViewController();
    if (!mounted) return;

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;

            // Allow the initial about:blank / data: load for the HTML string
            if (url.startsWith('about:') || url.startsWith('data:')) {
              return NavigationDecision.navigate;
            }

            // Allow Adsterra's own script host to load inside the WebView
            if (url.contains('effectivecpmnetwork.com') ||
                url.contains('highperformanceformat.com') ||
                url.contains('profitabledisplaynetwork.com')) {
              return NavigationDecision.navigate;
            }

            // Everything else = ad click → open externally
            final uri = Uri.tryParse(url);
            if (uri != null) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint('Adsterra WebView error: ${error.description}');
            }
          },
        ),
      )
      ..loadHtmlString(widget.adHtml);

    setState(() => _controller = controller);
  }

  void _startTimers() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dismissed) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) _canSkip = true;
      });
    });
    // Safety: force-close after 20s no matter what
    _failsafe = Timer(const Duration(seconds: 20), () {
      if (!_dismissed) _dismiss();
    });
  }

  void _dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _ticker?.cancel();
    _failsafe?.cancel();
    HapticFeedback.lightImpact();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _failsafe?.cancel();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // back button block until skip
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Ad WebView fills screen
              Positioned.fill(
                child: _controller == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : WebViewWidget(controller: _controller!),
              ),
              // Top-right Skip / Countdown badge
              Positioned(
                top: 16,
                right: 16,
                child: _canSkip
                    ? _SkipButton(onTap: _dismiss)
                    : _CountdownBadge(seconds: _secondsLeft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final int seconds;
  const _CountdownBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Text(
        'Skip in ${seconds}s',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.close, color: Colors.black, size: 16),
          ],
        ),
      ),
    );
  }
}
