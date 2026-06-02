import 'package:flutter/material.dart';

import '../../config/ad_config.dart';

/// Wraps in-player ad WebViews: keeps layout space, hides from user when configured.
class PlayerAdVisibility {
  PlayerAdVisibility._();

  static bool get userVisible => AdConfig.playerAdsUserVisible;

  static Widget shell({
    required double height,
    required Widget child,
    bool? visible,
  }) {
    final show = visible ?? userVisible;
    final sized = SizedBox(
      height: height,
      width: double.infinity,
      child: child,
    );
    if (show) return sized;
    return Opacity(
      opacity: 0,
      child: IgnorePointer(
        ignoring: true,
        child: sized,
      ),
    );
  }
}
