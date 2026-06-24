import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';
import 'ad_log.dart';
import 'adsterra_engine.dart';
import '../services/ad_safety_service.dart';
import 'ad_manager.dart';

/// Chained full-screen interstitial service.
/// Shows Ad 1 (5s skip) → dismiss → Ad 2 (5s skip).
/// Frequency cap: once every 2 hours per placement.
class ChainedInterstitialService {
  ChainedInterstitialService._();
  static final ChainedInterstitialService instance = ChainedInterstitialService._();

  bool _showing = false;
  int _currentAdIndex = 0;
  static const int _totalAds = 2;
  static const Duration _frequencyCap = Duration(hours: 2);

  /// Show chained interstitials (Ad 1 → Ad 2).
  /// Returns true if at least one ad was shown.
  Future<bool> showChainedInterstitials({
    required String placement,
  }) async {
    if (_showing) return false;
    if (!AdManager.instance.adsEnabled) return false;
    if (!AdSafetyService.instance.adsEnabledRemote) return false;
    if (!AdConfig.hasValidAdsterraDirectLink) {
      adLog('[ChainedInterstitial] blocked - no valid direct link');
      return false;
    }

    // Check frequency cap (2 hours)
    if (!await _canShowPlacement(placement)) {
      adLog('[ChainedInterstitial] blocked by frequency cap: $placement');
      return false;
    }

    _showing = true;
    _currentAdIndex = 0;
    int adsShown = 0;

    try {
      // Show Ad 1
      if (await _showSingleAd(placement: '${placement}_ad1')) {
        adsShown++;
      }

      // Show Ad 2
      if (await _showSingleAd(placement: '${placement}_ad2')) {
        adsShown++;
      }

      // Record placement shown if at least one ad was shown
      if (adsShown > 0) {
        await _recordPlacementShown(placement);
      }
    } finally {
      _showing = false;
    }

    return adsShown > 0;
  }

  Future<bool> _showSingleAd({required String placement}) async {
    _currentAdIndex++;
    adLog('[ChainedInterstitial] showing ad $_currentAdIndex/$_totalAds: $placement');

    final ok = await AdsterraEngine.instance.openDirectLink(
      placement: placement,
      analytics: AdManager.instance.analytics,
    );

    if (ok) {
      adLog('[ChainedInterstitial] ad $_currentAdIndex shown successfully');
      // Wait a bit before showing next ad
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      adLog('[ChainedInterstitial] ad $_currentAdIndex failed to show');
    }

    return ok;
  }

  /// Check if currently showing chained ads.
  bool get isShowing => _showing;

  /// Check if placement can be shown based on frequency cap (2 hours).
  Future<bool> _canShowPlacement(String placement) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chained_interstitial_$placement';
    final lastShown = prefs.getInt(key);
    
    if (lastShown == null) return true;
    
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastShown;
    return elapsed >= _frequencyCap.inMilliseconds;
  }

  /// Record placement shown timestamp.
  Future<void> _recordPlacementShown(String placement) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chained_interstitial_$placement';
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, now);
    adLog('[ChainedInterstitial] recorded placement shown: $placement at $now');
  }
}
