import 'package:flutter/material.dart';

import '../../config/ad_config.dart';
import '../ad_placement_config.dart';
import '../ad_manager.dart';
import '../adsterra/adsterra_native.dart';
import 'lazy_ad_viewport.dart';
import 'webview_pool.dart';

export '../../config/ad_config.dart' show AdListScreen;

/// Injects Adsterra native rows with per-screen density + WebView pool.
class AdListInjector {
  AdListInjector._();

  static const int defaultInterval = 6;

  static int intervalFor(
    AdListScreen screen, {
    int? intervalOverride,
  }) {
    if (intervalOverride != null) return intervalOverride;
    return AdPlacementConfig.listNativeInterval;
  }

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

  /// Stable placement id per browse category (Sports, Bangla, …).
  static String placementPrefixForCategory(String categoryName) {
    return 'category_list_${_placementSlug(categoryName)}';
  }

  /// Stable placement id per Sports filter (Cricket, Football, All, …).
  static String placementPrefixForSport(String sportFilter) {
    return 'sports_list_${_placementSlug(sportFilter)}';
  }

  static String _placementSlug(String raw) {
    final slug = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return slug.isEmpty ? 'all' : slug;
  }

  static bool defaultUseWebViewPool(AdListScreen screen) {
    switch (screen) {
      case AdListScreen.sports:
      case AdListScreen.categoryDrilldown:
      case AdListScreen.live:
      case AdListScreen.categories:
        return false;
      default:
        return true;
    }
  }

  static Widget? maybeNativeAdAfterChannels({
    required int channelsSoFar,
    AdListScreen screen = AdListScreen.defaultList,
    int? interval,
    String placementPrefix = 'list_native',
    bool? showAds,
    bool? useWebViewPool,
  }) {
    final adsOn = showAds ??
        (AdManager.instance.showAdsterraWebViewSlots &&
            !AdManager.instance.isStreaming &&
            !AdManager.instance.adChromeHidden.value);
    final effectiveInterval = intervalFor(screen, intervalOverride: interval);
    if (!adsOn || effectiveInterval <= 0 || channelsSoFar <= 0) return null;
    if (channelsSoFar % effectiveInterval != 0) return null;
    final slot = channelsSoFar ~/ effectiveInterval;
    final placement = '${placementPrefix}_$slot';
    return _listNativeAdSlot(
      key: ValueKey('${placementPrefix}_ad_$slot'),
      placement: placement,
      screen: screen,
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
    bool? useWebViewPool,
  }) {
    final adsOn = showAds ??
        (AdManager.instance.showAdsterraWebViewSlots &&
            !AdManager.instance.isStreaming &&
            !AdManager.instance.adChromeHidden.value);
    final effectiveInterval = intervalFor(screen, intervalOverride: interval);
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
      itemBuilder: (ctx, i) => _buildSeparatedItem(
        ctx,
        i,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
        screen: screen,
        interval: interval,
        placementPrefix: placementPrefix,
        inject: inject,
        useWebViewPool: useWebViewPool,
      ),
    );
  }

  /// Channel rows + native ads as one scroll sliver (for unified page scroll).
  static Widget buildSeparatedChannelSliver({
    required int itemCount,
    required Widget Function(BuildContext context, int sourceIndex) itemBuilder,
    AdListScreen screen = AdListScreen.defaultList,
    int? interval,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    double separatorHeight = 8,
    String placementPrefix = 'list_native',
    bool? showAds,
    bool? useWebViewPool,
  }) {
    final adsOn = showAds ??
        (AdManager.instance.showAdsterraWebViewSlots &&
            !AdManager.instance.isStreaming &&
            !AdManager.instance.adChromeHidden.value);
    final effectiveInterval = intervalFor(screen, intervalOverride: interval);
    final inject = adsOn && effectiveInterval > 0 && itemCount > 0;
    final total = inject
        ? totalCount(
            itemCount,
            screen: screen,
            intervalOverride: interval,
          )
        : itemCount;

    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final child = _buildSeparatedItem(
              ctx,
              i,
              itemCount: itemCount,
              itemBuilder: itemBuilder,
              screen: screen,
              interval: interval,
              placementPrefix: placementPrefix,
              inject: inject,
              useWebViewPool: useWebViewPool,
            );
            if (i >= total - 1) return child;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                SizedBox(height: separatorHeight),
              ],
            );
          },
          childCount: total,
        ),
      ),
    );
  }

  static Widget _listNativeAdSlot({
    Key? key,
    required String placement,
    required AdListScreen screen,
    double height = 100,
    bool? useWebViewPool,
  }) {
    final pooled = useWebViewPool ?? defaultUseWebViewPool(screen);
    if (pooled) {
      return _PooledNativeAdSlot(
        key: key,
        placement: placement,
        height: height,
      );
    }
    return _UnpooledListNativeAd(
      key: key,
      placement: placement,
      height: height,
    );
  }

  static Widget _buildSeparatedItem(
    BuildContext ctx,
    int i, {
    required int itemCount,
    required Widget Function(BuildContext context, int sourceIndex) itemBuilder,
    required AdListScreen screen,
    int? interval,
    required String placementPrefix,
    required bool inject,
    bool? useWebViewPool,
  }) {
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
      final placement = '${placementPrefix}_$slot';
      return _listNativeAdSlot(
        key: ValueKey('${placementPrefix}_ad_$slot'),
        placement: placement,
        screen: screen,
        useWebViewPool: useWebViewPool,
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
    WebViewPool.instance.addListener(_onPoolChanged);
    if (!widget.lazy) {
      _tryMount();
    }
  }

  void _onPoolChanged() {
    if (_mountedWebView &&
        !WebViewPool.instance.holdsPlacement(widget.placement)) {
      _lastAcquireAttemptAt = null;
      if (mounted) setState(() => _mountedWebView = false);
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
    WebViewPool.instance.removeListener(_onPoolChanged);
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
    final adsAllowed = AdManager.instance.showAdsterraWebViewSlots &&
        !AdManager.instance.isStreaming &&
        !AdManager.instance.adChromeHidden.value;
    if (!adsAllowed) {
      return const SizedBox.shrink();
    }
    if (widget.lazy && !_mountedWebView) {
      return LazyAdViewport(
        placeholderHeight: 0,
        builder: () {
          if (!_mountedWebView) {
            _tryMount();
          }
          if (!_mountedWebView) {
            return const SizedBox.shrink();
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

/// In-feed list native — no WebView pool (reliable every-8 on category/sports/live).
class _UnpooledListNativeAd extends StatelessWidget {
  const _UnpooledListNativeAd({
    super.key,
    required this.placement,
    this.height = 100,
  });

  final String placement;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.showAdsterraWebViewSlots ||
        AdManager.instance.isStreaming ||
        AdManager.instance.adChromeHidden.value) {
      return const SizedBox.shrink();
    }
    return LazyAdViewport(
      placeholderHeight: 0,
      preloadPx: 480,
      builder: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: AdsterraNativeBanner(
          placement: placement,
          height: height,
        ),
      ),
    );
  }
}
