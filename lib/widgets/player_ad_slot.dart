import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_banner.dart';
import '../ads/adsterra/adsterra_social_bar.dart';
import '../ads/propeller/propeller_webview.dart';
import '../config/ad_config.dart';
import '../config/monetag_config.dart';

/// Below-player ad strip — WebViews stay mounted; hidden at opacity 0 by default.
class PlayerAdSlot extends StatelessWidget {
  const PlayerAdSlot({super.key});

  static const double _bannerHeight = 90;
  static const double _stickyHeight = 50;

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.adsEnabled) {
      return const SizedBox(height: 8);
    }

    final visible = AdConfig.playerAdsUserVisible;
    final children = <Widget>[];

    if (AdConfig.hasAdsterraBanner728) {
      children.add(
        AdsterraBanner728(
          placement: 'player_below',
          userVisible: visible,
        ),
      );
    } else if (MonetagConfig.isConfigured) {
      children.add(
        PropellerInPagePushBanner(
          placement: 'player_below_monetag',
          height: _bannerHeight,
          userVisible: visible,
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox(height: 8);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }
}

/// In-player sticky strip (over video) — Monetag or Adsterra social fallback.
class PlayerStickyAdStrip extends StatelessWidget {
  const PlayerStickyAdStrip({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AdManager.instance.adsEnabled) return const SizedBox.shrink();

    final visible = AdConfig.playerAdsUserVisible;
    const h = 50.0;

    if (MonetagConfig.isConfigured) {
      return PropellerInPagePushBanner(
        placement: 'monetag_player_sticky_social',
        height: h,
        userVisible: visible,
      );
    }

    if (AdConfig.adsterraSocialScriptUrl.trim().isNotEmpty &&
        AdConfig.adsterraSocialBaseUrl.trim().isNotEmpty) {
      return AdsterraSocialBar(
        placement: 'player_sticky_social',
        userVisible: visible,
      );
    }

    return const SizedBox.shrink();
  }
}
