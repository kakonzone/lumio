import 'dart:async';

import 'package:flutter/material.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../widgets/fullscreen_interstitial_ad.dart';

class InterstitialChainController {
  static Future<void> showAdChain(
    BuildContext context, {
    int adCount = 2,
    int skipSeconds = 5,
  }) async {
    for (var i = 0; i < adCount; i++) {
      if (!context.mounted) return;
      await _showSingleAd(context, index: i + 1, skipSeconds: skipSeconds);
    }
  }

  static Future<void> _showSingleAd(
    BuildContext context, {
    required int index,
    required int skipSeconds,
  }) async {
    final completer = Completer<void>();
    
    // 10-second timeout to prevent user getting stuck if ad fails to load
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!context.mounted) return;
      if (!completer.isCompleted) {
        Navigator.of(context).pop();
        completer.complete();
      }
    });

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => FullscreenInterstitialAd(
          adHtml: AdsterraHtml.interstitialSocialBar(), // use Social Bar based interstitial
          skipAfterSeconds: skipSeconds,
          placement: 'interstitial_$index',
          onDismiss: () {
            timeout.cancel();
            Navigator.of(context).pop();
            if (!completer.isCompleted) completer.complete();
          },
        ),
      ),
    );
    await completer.future;
  }
}
