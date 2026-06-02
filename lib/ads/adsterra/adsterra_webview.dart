import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ad_log.dart';
import '../ad_manager.dart';
import '../utils/ad_webview_navigation_policy.dart';
import '../utils/lumio_webview_config.dart';
import '../../utils/ad_debug_log.dart';
import 'adsterra_html.dart';
import 'adsterra_native_cache.dart';

/// Shared Adsterra WebView host with placement cache + lifecycle-safe impressions.
class AdsterraWebView extends StatefulWidget {
  @visibleForTesting
  static bool shouldSuppressImpression({
    required bool disposed,
    required bool hasPainted,
    required bool loadLogged,
  }) {
    if (loadLogged) return true;
    if (disposed && !hasPainted) return true;
    return false;
  }

  final String html;
  final double height;
  final String placement;
  final bool fullWidth;
  final String? cachedHtml;
  /// When false, WebView still mounts/loads but is drawn at opacity 0 (player strip).
  final bool userVisible;

  const AdsterraWebView({
    super.key,
    required this.html,
    required this.height,
    required this.placement,
    this.fullWidth = true,
    this.cachedHtml,
    this.userVisible = true,
  });

  @override
  State<AdsterraWebView> createState() => _AdsterraWebViewState();
}

class _AdsterraWebViewState extends State<AdsterraWebView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _pageLoaded = false;
  bool _loadEventLogged = false;
  String? _lastError;
  bool _disposed = false;
  bool _hasPainted = false;
  bool _clickLogged = false;
  int _loadAttempts = 0;
  Timer? _loadGuardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hasPainted = true;
    });
    _mountWebView();
  }

  Future<void> _mountWebView() async {
    _loadGuardTimer?.cancel();
    final cached = widget.cachedHtml ??
        AdsterraNativeCache.instance.get(widget.placement);
    final html = cached ?? widget.html;
    if (cached == null) {
      AdsterraNativeCache.instance.put(widget.placement, widget.html);
    }

    final baseUrl = AdsterraHtml.baseUrlForPlacement(widget.placement);
    final controller = await createLumioWebViewController();
    if (!mounted || _disposed) return;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final decision = AdWebViewNavigationPolicy.evaluate(request.url);
            if (decision == NavigationDecision.navigate) {
              _maybeLogAdsterraClick(request.url);
            }
            return decision;
          },
          onPageFinished: (_) {
            if (!mounted || _disposed) return;
            final mountedController = _controller;
            if (mountedController != null) {
              unawaited(
                mountedController.runJavaScript(
                  "document.documentElement.style.background='transparent';"
                  "document.body.style.background='transparent';",
                ),
              );
            }
            _loadGuardTimer?.cancel();
            setState(() {
              _loading = false;
              _pageLoaded = true;
              _lastError = null;
            });
            _logAdsterraLoadedOnce();
          },
          onWebResourceError: (err) {
            if (!mounted || _disposed) return;
            _loadGuardTimer?.cancel();
            if (_loadAttempts < 2) {
              _loadAttempts++;
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted && !_disposed) _mountWebView();
              });
              return;
            }
            setState(() {
              _lastError = err.description;
              _loading = false;
              _pageLoaded = false;
            });
          },
        ),
      );
    _controller = controller;
    _loadGuardTimer?.cancel();
    _loadGuardTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || _disposed || !_loading) return;
      if (_loadAttempts < 2) {
        _loadAttempts++;
        _mountWebView();
        return;
      }
      setState(() => _loading = false);
    });
    unawaited(controller.loadHtmlString(html, baseUrl: baseUrl));
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGuardTimer?.cancel();
    if (!_hasPainted && !_loadEventLogged) {
      adLog(
        '[AdsterraNative] disposed before paint — impression suppressed '
        'placement=${widget.placement}',
      );
    }
    final c = _controller;
    _controller = null;
    unawaited(disposeLumioWebView(c));
    super.dispose();
  }

  void _maybeLogAdsterraClick(String url) {
    if (_clickLogged || _disposed) return;
    final lower = url.toLowerCase();
    if (lower.startsWith('about:') || lower.startsWith('data:')) return;
    final base = AdsterraHtml.baseUrlForPlacement(widget.placement).toLowerCase();
    if (lower.startsWith(base)) return;
    _clickLogged = true;
    final format =
        _isBannerPlacement(widget.placement) ? 'banner_webview' : 'native_webview';
    unawaited(
      AdManager.instance.analytics.logClick(
        network: 'adsterra',
        format: format,
        placement: widget.placement,
      ),
    );
    adLog(
      '[AdAnalytics] lumio_ad_click network=adsterra format=$format '
      'placement=${widget.placement}',
    );
  }

  void _logAdsterraLoadedOnce() {
    if (AdsterraWebView.shouldSuppressImpression(
      disposed: _disposed,
      hasPainted: _hasPainted,
      loadLogged: _loadEventLogged,
    )) {
      if (_disposed && !_hasPainted && !_loadEventLogged) {
        adLog(
          '[AdsterraNative] disposed before paint — impression suppressed '
          'placement=${widget.placement}',
        );
      }
      return;
    }
    _loadEventLogged = true;
    final analytics = AdManager.instance.analytics;
    final p = widget.placement;
    final isBanner = _isBannerPlacement(p);
    if (isBanner) {
      unawaited(analytics.logAdsterraBannerLoaded(placement: p));
    } else {
      unawaited(analytics.logAdsterraNativeLoaded(placement: p));
    }
    logAdsterraTelemetry(
      placement: p,
      format: isBanner ? 'banner_webview' : 'native_webview',
    );
    if (p.toLowerCase().contains('popunder')) {
      adLog('[Adsterra] popunder loaded placement=$p');
    }
  }

  static bool _isBannerPlacement(String placement) {
    final lower = placement.toLowerCase();
    return lower.contains('banner') ||
        lower.contains('728') ||
        lower.contains('social_bar') ||
        lower == 'sports_top' ||
        lower == 'player_below';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return SizedBox(height: widget.height);
    }

    final webStack = SizedBox(
      height: widget.height,
      width: widget.fullWidth ? double.infinity : widget.height,
      child: Stack(
        children: [
          Opacity(
            opacity: _pageLoaded ? 1 : 0.01,
            child: WebViewWidget(controller: controller),
          ),
          if (widget.userVisible && _loading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );

    if (widget.userVisible) return webStack;

    return Opacity(
      opacity: 0,
      child: IgnorePointer(
        ignoring: true,
        child: webStack,
      ),
    );
  }
}
