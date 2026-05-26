import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_native.dart';

/// Injects Adsterra native rows every [interval] list items (default: 8).
class AdListInjector {
  AdListInjector._();

  static const int defaultInterval = 8;

  /// Total list slots including ad rows.
  static int totalCount(int itemCount, {int interval = defaultInterval}) {
    if (itemCount <= 0 || interval <= 0) return itemCount;
    return itemCount + itemCount ~/ interval;
  }

  /// True when [index] is an ad slot (after each block of [interval] items).
  static bool isAdIndex(int index, {int interval = defaultInterval}) {
    if (interval <= 0) return false;
    return (index + 1) % (interval + 1) == 0;
  }

  /// Source data index for a list [index], or -1 when [index] is an ad slot.
  static int sourceIndex(int index, {int interval = defaultInterval}) {
    if (isAdIndex(index, interval: interval)) return -1;
    return index - (index + 1) ~/ (interval + 1);
  }

  static int adSlotIndex(int listIndex, {int interval = defaultInterval}) =>
      listIndex ~/ (interval + 1);

  /// Inserts a native ad after every [interval] channels in a custom [ListView] build.
  static Widget? maybeNativeAdAfterChannels({
    required int channelsSoFar,
    int interval = defaultInterval,
    String placementPrefix = 'list_native',
    bool? showAds,
  }) {
    final adsOn = showAds ?? AdManager.instance.adsEnabled;
    if (!adsOn || interval <= 0 || channelsSoFar <= 0) return null;
    if (channelsSoFar % interval != 0) return null;
    final slot = channelsSoFar ~/ interval;
    return _KeepAliveNativeAdSlot(
      key: ValueKey('${placementPrefix}_ad_$slot'),
      placement: '${placementPrefix}_$slot',
    );
  }

  static Widget nativeAd({
    Key? key,
    double height = 100,
    String placement = 'list_native',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AdsterraNativeBanner(
          key: key,
          height: height,
          placement: placement,
        ),
      ),
    );
  }

  /// Channel/category list with native ads every [interval] items.
  static Widget buildSeparatedChannelList({
    required int itemCount,
    required Widget Function(BuildContext context, int sourceIndex) itemBuilder,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(16, 0, 16, 24),
    double separatorHeight = 8,
    int interval = defaultInterval,
    String placementPrefix = 'list_native',
    bool? showAds,
  }) {
    final adsOn = showAds ?? AdManager.instance.adsEnabled;
    final inject = adsOn && interval > 0 && itemCount > 0;
    final total = inject ? totalCount(itemCount, interval: interval) : itemCount;

    return ListView.separated(
      padding: padding,
      itemCount: total,
      separatorBuilder: (_, __) => SizedBox(height: separatorHeight),
      itemBuilder: (ctx, i) {
        if (inject && isAdIndex(i, interval: interval)) {
          final slot = adSlotIndex(i, interval: interval);
          return _KeepAliveNativeAdSlot(
            key: ValueKey('${placementPrefix}_ad_$slot'),
            placement: '${placementPrefix}_$slot',
          );
        }
        final src = inject ? sourceIndex(i, interval: interval) : i;
        return itemBuilder(ctx, src);
      },
    );
  }
}

/// Prevents WebView reload when scrolling past ad rows.
class _KeepAliveNativeAdSlot extends StatefulWidget {
  final String placement;

  const _KeepAliveNativeAdSlot({
    super.key,
    required this.placement,
  });

  @override
  State<_KeepAliveNativeAdSlot> createState() => _KeepAliveNativeAdSlotState();
}

class _KeepAliveNativeAdSlotState extends State<_KeepAliveNativeAdSlot>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AdListInjector.nativeAd(
      placement: widget.placement,
      height: 100,
    );
  }
}
