import 'package:flutter/material.dart';

import '../../config/ad_config.dart';
import '../ad_manager.dart';
import '../adsterra/adsterra_native.dart';
import 'lazy_ad_viewport.dart';
import 'webview_pool.dart';

export '../../config/ad_config.dart' show AdListScreen;

/// Injects Adsterra native rows with per-screen density + WebView pool.
class AdListInjector {
  AdListInjector._();

  static const int defaultInterval = 8;

  static int intervalFor(
    AdListScreen screen, {
    int? intervalOverride,
  }) =>
      intervalOverride ??
      AdConfig.nativeDensityByScreen[screen] ??
      defaultInterval;

  static int totalCount(
    int itemCount, {
    required AdListScreen screen,
    int? intervalOverride,
  }) {
    final interval = intervalFor(screen, intervalOverride: intervalOverride);
    if (itemCount <= 0 || interval <= 0) return itemCount;
    return itemCount + itemCount ~/ interval;
  }

  static bool isAdIndex(
    int index, {
    required AdListScreen screen,
    int? intervalOverride,
  }) {
    final interval = intervalFor(screen, intervalOverride: intervalOverride);
    if (interval <= 0) return false;
    return (index + 1) % (interval + 1) == 0;
  }

  static int sourceIndex(
    int index, {
    required AdListScreen screen,
    int? intervalOverride,
  }) {
    if (isAdIndex(index, screen: screen, intervalOverride: intervalOverride)) {
      return -1;
    }
    final interval = intervalFor(screen, intervalOverride: intervalOverride);
    return index - (index + 1) ~/ (interval + 1);
  }

  static int adSlotIndex(
    int listIndex, {
    required AdListScreen screen,
    int? intervalOverride,
  }) {
    final interval = intervalFor(screen, intervalOverride: intervalOverride);
    return listIndex ~/ (interval + 1);
  }

  static Widget? maybeNativeAdAfterChannels({
    required int channelsSoFar,
    AdListScreen screen = AdListScreen.defaultList,
    int? interval,
    String placementPrefix = 'list_native',
    bool? showAds,
  }) {
    final adsOn = showAds ??
        (AdManager.instance.adsEnabled &&
            !AdManager.instance.isStreaming &&
            !AdManager.instance.adChromeHidden.value);
    final effectiveInterval =
        intervalFor(screen, intervalOverride: interval);
    if (!adsOn || effectiveInterval <= 0 || channelsSoFar <= 0) return null;
    if (channelsSoFar % effectiveInterval != 0) return null;
    final slot = channelsSoFar ~/ effectiveInterval;
    return _PooledNativeAdSlot(
      key: ValueKey('${placementPrefix}_ad_$slot'),
      placement: '${placementPrefix}_$slot',
    );
  }

  static Widget nativeAd({
    Key? key,
    double height = 100,
    String placement = 'list_native',
    bool lazy = true,
  }) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _PooledNativeAdSlot(
            key: key,
            placement: placement,
            height: height,
            lazy: lazy,
          ),
        ),
      ),
    );
  }

  static Widget buildSeparatedChannelList({
    required int itemCount,
    required Widget Function(BuildContext context, int sourceIndex) itemBuilder,
    AdListScreen screen = AdListScreen.defaultList,
    int? interval,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    double separatorHeight = 8,
    String placementPrefix = 'list_native',
    bool? showAds,
  }) {
    final adsOn = showAds ??
        (AdManager.instance.adsEnabled &&
            !AdManager.instance.isStreaming &&
            !AdManager.instance.adChromeHidden.value);
    final effectiveInterval =
        intervalFor(screen, intervalOverride: interval);
    final inject = adsOn && effectiveInterval > 0 && itemCount > 0;
    final total = inject
        ? totalCount(
            itemCount,
            screen: screen,
            intervalOverride: interval,
          )
        : itemCount;

    return ListView.separated(
      padding: padding,
      cacheExtent: 200,
      itemCount: total,
      separatorBuilder: (_, __) => SizedBox(height: separatorHeight),
      itemBuilder: (ctx, i) {
        if (inject &&
            isAdIndex(
              i,
              screen: screen,
              intervalOverride: interval,
            )) {
          final slot = adSlotIndex(
            i,
            screen: screen,
            intervalOverride: interval,
          );
          return _PooledNativeAdSlot(
            key: ValueKey('${placementPrefix}_ad_$slot'),
            placement: '${placementPrefix}_$slot',
          );
        }
        final src = inject
            ? sourceIndex(
                i,
                screen: screen,
                intervalOverride: interval,
              )
            : i;
        return itemBuilder(ctx, src);
      },
    );
  }
}

class _PooledNativeAdSlot extends StatefulWidget {
  const _PooledNativeAdSlot({
    super.key,
    required this.placement,
    this.height = 100,
    this.lazy = true,
  });

  final String placement;
  final double height;
  final bool lazy;

  @override
  State<_PooledNativeAdSlot> createState() => _PooledNativeAdSlotState();
}

class _PooledNativeAdSlotState extends State<_PooledNativeAdSlot>
    with AutomaticKeepAliveClientMixin {
  bool _mountedWebView = false;
  DateTime? _lastAcquireAttemptAt;
  static const Duration _acquireRetryCooldown = Duration(seconds: 8);

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    if (!widget.lazy) {
      _tryMount();
    }
  }

  void _tryMount() {
    if (_mountedWebView) return;
    final adsAllowed = AdManager.instance.adsEnabled &&
        !AdManager.instance.isStreaming &&
        !AdManager.instance.adChromeHidden.value;
    if (!adsAllowed) return;
    final now = DateTime.now();
    final last = _lastAcquireAttemptAt;
    if (last != null && now.difference(last) < _acquireRetryCooldown) {
      return;
    }
    _lastAcquireAttemptAt = now;
    if (WebViewPool.instance.acquire(widget.placement)) {
      // Prevent "setState during build" when called from lazy builder.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _mountedWebView) return;
        setState(() => _mountedWebView = true);
      });
    }
  }

  @override
  void dispose() {
    if (_mountedWebView) {
      WebViewPool.instance.release(widget.placement);
    }
    super.dispose();
  }

  Widget _nativeBanner() => RepaintBoundary(
        child: AdsterraNativeBanner(
          height: widget.height,
          placement: widget.placement,
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final adsAllowed = AdManager.instance.adsEnabled &&
        !AdManager.instance.isStreaming &&
        !AdManager.instance.adChromeHidden.value;
    if (!adsAllowed) {
      return SizedBox(height: widget.height);
    }
    if (widget.lazy && !_mountedWebView) {
      return LazyAdViewport(
        placeholderHeight: widget.height,
        builder: () {
          if (!_mountedWebView) {
            _tryMount();
          }
          if (!_mountedWebView) {
            return SizedBox(height: widget.height);
          }
          return _nativeBanner();
        },
      );
    }
    if (!_mountedWebView) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: TextButton(
            onPressed: _tryMount,
            child: const Text('Load ad', style: TextStyle(fontSize: 11)),
          ),
        ),
      );
    }
    return _nativeBanner();
  }
}
