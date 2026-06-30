import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/safe_logger.dart';
import 'interstitial_chain_controller.dart';

/// Controller for channel-change interstitial ads.
///
/// Features:
/// - Shows 1 Adsterra direct link in external browser
/// - At most ONE ad per 5 minutes per user
/// - Uses InterstitialChainController for consistent ad flow
/// - User returns to app after closing browser, channel opens
class ChannelChangeInterstitialController {
  ChannelChangeInterstitialController._();
  static final ChannelChangeInterstitialController instance =
      ChannelChangeInterstitialController._();

  static const _cooldownMinutes = 5;
  static const _lastShownKey = 'channel_change_interstitial_last_shown';
  static const _chainCountKey = 'channel_change_chain_count';

  bool _isShowing = false;
  DateTime? _lastShownTime;

  /// Check if interstitial can be shown (respects 5-minute cooldown)
  Future<bool> canShow() async {
    if (_isShowing) {
      SafeLogger.debug('ad', '[ChannelChangeInterstitial] Already showing, skipping');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShownTimestamp = prefs.getInt(_lastShownKey);
    
    if (lastShownTimestamp == null) {
      return true;
    }

    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
    final timeSinceLastShown = DateTime.now().difference(lastShown);
    
    if (timeSinceLastShown >= const Duration(minutes: _cooldownMinutes)) {
      return true;
    }

    SafeLogger.debug('ad', '[ChannelChangeInterstitial] Cooldown active, skipping');
    return false;
  }

  /// Show interstitial chain if eligible
  Future<bool> showIf(BuildContext context) async {
    if (!await canShow()) {
      return false;
    }
    if (!context.mounted) return false;

    return show(context);
  }

  /// Show single Adsterra direct link in external browser
  Future<bool> show(BuildContext context) async {
    if (!context.mounted) return false;
    if (_isShowing) return false;

    _isShowing = true;
    
    try {
      await InterstitialChainController.showAdChain(
        context,
        adCount: 1,  // Only 1 ad, not 4
        skipSeconds: 5,
      );

      // Record last shown time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastShownKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      SafeLogger.debug('ad', '[ChannelChangeInterstitial] Ad shown successfully');
      return true;
    } catch (e) {
      SafeLogger.debug('ad', '[ChannelChangeInterstitial] Error showing ad: $e');
      return false;
    } finally {
      _isShowing = false;
    }
  }

  /// Reset cooldown (for testing)
  Future<void> resetCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownKey);
    await prefs.remove(_chainCountKey);
    _lastShownTime = null;
  }
}
