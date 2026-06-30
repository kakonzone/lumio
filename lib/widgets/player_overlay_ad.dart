import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/safe_logger.dart';
import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../ads/propeller/propeller_webview.dart';
import '../config/ad_config.dart';
import '../config/monetag_config.dart';
import '../services/user_preferences.dart';

/// Player overlay ad widget with 15s delay, frequency cap, and dismissible UI.
class PlayerOverlayAd extends StatefulWidget {
  final bool isStreaming;
  final bool isBuffering;
  final bool isPipMode;

  const PlayerOverlayAd({
    super.key,
    required this.isStreaming,
    required this.isBuffering,
    required this.isPipMode,
  });

  @override
  State<PlayerOverlayAd> createState() => _PlayerOverlayAdState();
}

class _PlayerOverlayAdState extends State<PlayerOverlayAd> {
  Timer? _showTimer;
  Timer? _dismissTimer;
  bool _visible = false;
  bool _canDismiss = false;

  static const String _lastShownKey = 'last_player_overlay_ad_ms';
  static const Duration _showDelay = Duration(seconds: 15);
  static const Duration _dismissDelay = Duration(seconds: 5);
  static const Duration _frequencyCap = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    _scheduleShow();
  }

  void _scheduleShow() {
    _showTimer = Timer(_showDelay, () {
      if (mounted) {
        _checkAndShow();
      }
    });
  }

  Future<void> _checkAndShow() async {
    // Check if we should skip based on stream state
    if (!widget.isStreaming || widget.isBuffering || widget.isPipMode) {
      return;
    }

    // Check if we should skip
    if (_shouldSkip()) {
      return;
    }

    // Check frequency cap
    final prefs = await SharedPreferences.getInstance();
    final lastShownMs = prefs.getInt(_lastShownKey);
    if (lastShownMs != null) {
      final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMs);
      final now = DateTime.now();
      if (now.difference(lastShown) < _frequencyCap) {
        // Within frequency cap, skip
        return;
      }
    }

    // Show the ad
    if (mounted) {
      setState(() {
        _visible = true;
      });

      // Enable dismiss button after 5 seconds
      _dismissTimer = Timer(_dismissDelay, () {
        if (mounted) {
          setState(() {
            _canDismiss = true;
          });
        }
      });

      // Log that we showed the ad
      SafeLogger.debug('ads', '[PlayerOverlayAd] shown at ${DateTime.now().toIso8601String()}');

      // Update last shown timestamp
      await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  bool _shouldSkip() {
    // Check VIP status
    final adFreeUntil = UserPreferences.adFreeUntil;
    if (adFreeUntil != null && DateTime.now().isBefore(adFreeUntil)) {
      return true;
    }

    return false;
  }

  void _dismiss() {
    if (!_canDismiss) return;

    SafeLogger.debug('ads', '[PlayerOverlayAd] dismissed');
    setState(() {
      _visible = false;
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || !AdManager.instance.adsEnabled) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 50),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Bengali label
            Positioned(
              top: 2,
              left: 8,
              child: Text(
                'বিজ্ঞাপন',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),
            // Dismiss button
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: _canDismiss ? _dismiss : null,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: _canDismiss
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            // Ad content
            Positioned.fill(
              top: 16,
              child: _buildAdContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdContent() {
    // Use AdsterraNativeBanner or PropellerInPagePushBanner based on config
    if (AdConfig.hasAdsterraWebViewZones) {
      return const AdsterraNativeBanner(
        placement: 'player_overlay',
        height: 34,
        userVisible: AdConfig.playerAdsUserVisible,
      );
    } else if (MonetagConfig.isConfigured) {
      return const PropellerInPagePushBanner(
        placement: 'player_overlay_monetag',
        height: 34,
        userVisible: AdConfig.playerAdsUserVisible,
      );
    }
    return const SizedBox.shrink();
  }
}
