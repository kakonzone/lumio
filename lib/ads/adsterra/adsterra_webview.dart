import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ad_log.dart';
import '../ad_manager.dart';
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

  const AdsterraWebView({
    super.key,
    required this.html,
    required this.height,
    required this.placement,
    this.fullWidth = true,
    this.cachedHtml,
  });

  @override
  State<AdsterraWebView> createState() => _AdsterraWebViewState();
}

class _AdsterraWebViewState extends State<AdsterraWebView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _loadEventLogged = false;
  String? _lastError;
  bool _disposed = false;
  bool _hasPainted = false;
  bool _clickLogged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _hasPainted = true;
    });
    _mountWebView();
  }

  void _mountWebView() {
    final cached = widget.cachedHtml ??
        AdsterraNativeCache.instance.get(widget.placement);
    final html = cached ?? widget.html;
    if (cached == null) {
      AdsterraNativeCache.instance.put(widget.placement, widget.html);
    }

    final baseUrl = AdsterraHtml.baseUrlForPlacement(widget.placement);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0C0C0E))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            _maybeLogAdsterraClick(request.url);
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (!mounted || _disposed) return;
            setState(() => _loading = false);
            _logAdsterraLoadedOnce();
          },
          onWebResourceError: (err) {
            if (!mounted || _disposed) return;
            _lastError = err.description;
          },
        ),
      );
    _controller = controller;
    if (cached != null) {
      unawaited(controller.loadHtmlString(html, baseUrl: baseUrl));
      _loading = false;
    } else {
      unawaited(controller.loadHtmlString(html, baseUrl: baseUrl));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_hasPainted && !_loadEventLogged) {
      adLog(
        '[AdsterraNative] disposed before paint — impression suppressed '
        'placement=${widget.placement}',
      );
    }
    _controller = null;
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
    return SizedBox(
      height: widget.height,
      width: widget.fullWidth ? double.infinity : widget.height,
      child: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (_lastError != null && !_loading)
            Positioned(
              left: 4,
              right: 4,
              bottom: 2,
              child: Text(
                'Ad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
