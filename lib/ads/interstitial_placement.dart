/// Analytics / cap placement labels for interstitial waterfall.
enum InterstitialPlacement {
  channelTap('channel_tap'),
  preroll('preroll'),
  midroll('midroll'),
  appOpen('appopen');

  const InterstitialPlacement(this.analyticsName);
  final String analyticsName;

  String get trigger => switch (this) {
        InterstitialPlacement.channelTap => 'channel_tap',
        InterstitialPlacement.preroll => 'pre_roll',
        InterstitialPlacement.midroll => 'mid_roll',
        InterstitialPlacement.appOpen => 'app_open_substitute',
      };
}

/// Result of a placement cap gate check.
class InterstitialCapResult {
  const InterstitialCapResult.allowed() : reason = null;
  const InterstitialCapResult.denied(this.reason);

  final String? reason;

  bool get allowed => reason == null;
}
