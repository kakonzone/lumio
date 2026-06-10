/// Gated features unlocked by watching rewarded ads.
enum RewardedFeatures {
  /// 60 minutes ad-free (already exists, verify it works)
  adFreeWindow,

  /// Unlock 1 premium channel for 30 minutes
  extraChannel,

  /// Skip next 3 pre-roll ads
  skipPreRoll,
}

extension RewardedFeaturesExtension on RewardedFeatures {
  /// Convert to trigger string for existing ad waterfall
  String toTrigger() {
    switch (this) {
      case RewardedFeatures.adFreeWindow:
        return 'ad_free_window';
      case RewardedFeatures.extraChannel:
        return 'extra_channel';
      case RewardedFeatures.skipPreRoll:
        return 'skip_preroll';
    }
  }

  /// Human-readable Bengali label for UI
  String toBengaliLabel() {
    switch (this) {
      case RewardedFeatures.adFreeWindow:
        return 'বিজ্ঞাপন-মুক্ত';
      case RewardedFeatures.extraChannel:
        return 'এক্সট্রা চ্যানেল';
      case RewardedFeatures.skipPreRoll:
        return 'প্রি-রোল স্কিপ';
    }
  }
}
