import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/ad_config.dart';
import '../services/unity_ads_service.dart';
import '../services/ad_safety_service.dart';
import 'ad_log.dart';
import 'adsterra/adsterra_html.dart';
import 'utils/ad_webview_navigation_policy.dart';
import 'adsterra_engine.dart';
import 'analytics/ad_analytics.dart';

/// Tri-network waterfall: Unity Ads → Adsterra WebView → Monetag.
class AdWaterfall {
  AdWaterfall._();
  static final AdWaterfall instance = AdWaterfall._();

  UnityAdsService? _unityAds;
  AdAnalytics? _analytics;

  final Map<String, int> _sessionFailures = {};

  void attach({
    required UnityAdsService unityAds,
    required AdAnalytics analytics,
  }) {
    _unityAds = unityAds;
    _analytics = analytics;
  }

  Duration get _networkTimeout =>
      Duration(seconds: AdConfig.waterfallTimeoutSeconds);

  bool _isSkipped(String network) {
    final n = _sessionFailures[network] ?? 0;
    return n >= AdConfig.networkFailureSkipThreshold;
  }

  void _recordFailure(String network) {
    _sessionFailures[network] = (_sessionFailures[network] ?? 0) + 1;
    if (_isSkipped(network)) {
      adLog('[AdWaterfall] skipping $network for rest of session');
    }
  }

  void _recordSuccess(String network) {
    _sessionFailures.remove(network);
  }

  /// Preload Unity Ads interstitial + rewarded.
  void preloadAll() {
    final ua = _unityAds;
    if (ua == null || !ua.isInitialized) return;
    ua.loadInterstitial();
    ua.loadRewarded();
  }

  /// Unity Ads rewarded only — returns true when user earns reward.
  Future<bool> showRewarded({required String trigger}) async {
    final analytics = _analytics;
    final ua = _unityAds;
    if (ua == null || !ua.isInitialized || _isSkipped('unity_rewarded')) {
      unawaited(analytics?.logNoFill(placement: 'rewarded'));
      return false;
    }

    unawaited(
      analytics?.logWaterfallAttempt(
        format: 'rewarded',
        network: 'unity',
        trigger: trigger,
      ),
    );
    ua.setRewardedTrigger(trigger);

    final ok = await _tryUnityRewarded(ua).timeout(
      _networkTimeout,
      onTimeout: () {
        adLog('[AdWaterfall] unity rewarded timeout');
        return false;
      },
    );

    if (ok) {
      _recordSuccess('unity_rewarded');
      unawaited(
        analytics?.logFill(network: 'unity', placement: 'rewarded'),
      );
      return true;
    }

    _recordFailure('unity_rewarded');
    unawaited(
      analytics?.logWaterfallFailure(
        format: 'rewarded',
        trigger: trigger,
        lastNetwork: 'unity',
      ),
    );
    unawaited(analytics?.logNoFill(placement: 'rewarded'));
    return false;
  }

  Future<bool> _tryUnityRewarded(UnityAdsService ua) async {
    try {
      if (!ua.isRewardedReady) {
        await ua.loadRewarded();
        await Future.delayed(const Duration(milliseconds: 500));
        if (!ua.isRewardedReady) return false;
      }
      return await ua.showRewarded();
    } catch (e) {
      adLog('[AdWaterfall] unity rewarded error: $e');
      return false;
    }
  }

  /// Interstitial chain: Unity Ads → Adsterra fullscreen WebView → direct link.
  ///
  /// Frequency caps must be checked by [AdManager] before calling.
  Future<bool> showInterstitial(
    BuildContext? context, {
    required String trigger,
  }) async {
    final analytics = _analytics;
    final ua = _unityAds;

    if (ua != null && ua.isInitialized && !_isSkipped('unity')) {
      unawaited(
        analytics?.logWaterfallAttempt(
          format: 'interstitial',
          network: 'unity',
          trigger: trigger,
        ),
      );
      ua.setInterstitialTrigger(trigger);

      final uaOk = await _tryUnityInterstitial(ua).timeout(
        _networkTimeout,
        onTimeout: () {
          adLog('[AdWaterfall] unity interstitial timeout');
          return false;
        },
      );

      if (uaOk) {
        _recordSuccess('unity');
        unawaited(
          analytics?.logFill(network: 'unity', placement: 'interstitial'),
        );
        return true;
      }

      _recordFailure('unity');
      unawaited(
        analytics?.logWaterfallFallback(
          format: 'interstitial',
          fromNetwork: 'unity',
          toNetwork: 'adsterra',
          trigger: trigger,
          reason: 'no_fill_or_timeout',
        ),
      );
    }

    if (!AdSafetyService.instance.adsterraEnabled || _isSkipped('adsterra')) {
      unawaited(
        analytics?.logWaterfallFailure(
          format: 'interstitial',
          trigger: trigger,
          lastNetwork: 'unity',
        ),
      );
      unawaited(analytics?.logNoFill(placement: 'interstitial'));
      return false;
    }

    unawaited(
      analytics?.logWaterfallAttempt(
        format: 'interstitial',
        network: 'adsterra',
        trigger: trigger,
      ),
    );

    if (context != null && context.mounted) {
      final webOk = await _showAdsterraFullscreen(
        context,
        placement: 'waterfall_interstitial_$trigger',
        minSeconds: AdConfig.channelTapAdMinSeconds,
      );
      if (webOk) {
        _recordSuccess('adsterra');
        unawaited(
          analytics?.logFill(
            network: 'adsterra',
            placement: 'waterfall_interstitial_webview',
          ),
        );
        return true;
      }
    }

    final linkOk = await AdsterraEngine.instance.openDirectLink(
      placement: 'waterfall_interstitial_$trigger',
      analytics: analytics,
    );

    if (linkOk) {
      _recordSuccess('adsterra');
      unawaited(
        analytics?.logFill(
          network: 'adsterra',
          placement: 'waterfall_interstitial_direct',
        ),
      );
      return true;
    }

    _recordFailure('adsterra');
    unawaited(
      analytics?.logWaterfallFailure(
        format: 'interstitial',
        trigger: trigger,
        lastNetwork: 'adsterra',
      ),
    );
    unawaited(analytics?.logNoFill(placement: 'interstitial'));
    return false;
  }

  Future<bool> _tryUnityInterstitial(UnityAdsService ua) async {
    try {
      if (!ua.isInterstitialReady) {
        await ua.loadInterstitial();
        await Future.delayed(const Duration(milliseconds: 500));
        if (!ua.isInterstitialReady) return false;
      }
      return await ua.showInterstitial();
    } catch (e) {
      adLog('[AdWaterfall] unity interstitial error: $e');
      return false;
    }
  }

  Future<bool> _showAdsterraFullscreen(
    BuildContext context, {
    required String placement,
    required int minSeconds,
    VoidCallback? onCompleted,
  }) async {
    if (!AdConfig.hasAdsterraWebViewZones &&
        !AdConfig.hasValidAdsterraDirectLink) {
      return false;
    }
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AdsterraWaterfallFullscreenDialog(
          placement: placement,
          minSeconds: minSeconds,
          onCompleted: onCompleted,
        ),
      );
      return result == true;
    } catch (e) {
      adLog('[AdWaterfall] adsterra fullscreen error: $e');
      return false;
    }
  }

  @visibleForTesting
  void resetFailureCountsForTest() => _sessionFailures.clear();
}

/// Fullscreen Adsterra WebView fallback (interstitial).
class _AdsterraWaterfallFullscreenDialog extends StatefulWidget {
  const _AdsterraWaterfallFullscreenDialog({
    required this.placement,
    required this.minSeconds,
    this.onCompleted,
  });

  final String placement;
  final int minSeconds;
  final VoidCallback? onCompleted;

  @override
  State<_AdsterraWaterfallFullscreenDialog> createState() =>
      _AdsterraWaterfallFullscreenDialogState();
}

class _AdsterraWaterfallFullscreenDialogState
    extends State<_AdsterraWaterfallFullscreenDialog> {
  late final WebViewController _web;
  Timer? _tick;
  int _elapsed = 0;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              AdWebViewNavigationPolicy.evaluate(request.url),
        ),
      )
      ..loadHtmlString(
        AdsterraHtml.channelTapFullscreen(),
        baseUrl: AdsterraHtml.baseUrlForPlacement('channel_tap'),
      );

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= widget.minSeconds) _canClose = true;
      });
    });
  }

  void _close({required bool completed}) {
    _tick?.cancel();
    if (completed) widget.onCompleted?.call();
    Navigator.of(context).pop(completed);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waitLeft = (widget.minSeconds - _elapsed).clamp(0, 999);
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _web),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Ad · ${widget.placement}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 24,
            child: FilledButton(
              onPressed: _canClose ? () => _close(completed: true) : null,
              child: Text(_canClose ? 'Continue' : '$waitLeft s'),
            ),
          ),
        ],
      ),
    );
  }
}
