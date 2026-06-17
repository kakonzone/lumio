import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ad_log.dart';
import 'adsterra/adsterra_html.dart';
import 'adsterra/adsterra_webview.dart';

/// Controller for channel-change interstitial ads.
///
/// Features:
/// - Shows at most ONE interstitial per 5 minutes per user
/// - Dismissible after 5 seconds
/// - ONLY on channel-change (not on resume or rotation)
/// - In-app WebView (no external browser)
class ChannelChangeInterstitialController {
  ChannelChangeInterstitialController._();
  static final ChannelChangeInterstitialController instance =
      ChannelChangeInterstitialController._();

  static const _cooldownMinutes = 5;
  static const _dismissibleAfterSeconds = 5;
  static const _lastShownKey = 'channel_change_interstitial_last_shown';
  static const _channelChangeCountKey = 'channel_change_count';

  DateTime? _lastShownTime;
  int _channelChangeCount = 0;
  bool _isShowing = false;

  /// Check if interstitial can be shown (respects 5-minute cooldown)
  Future<bool> canShow() async {
    if (_isShowing) {
      adLog('[ChannelChangeInterstitial] Already showing, skipping');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShownTimestamp = prefs.getInt(_lastShownKey);
    
    if (lastShownTimestamp == null) {
      return true;
    }

    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownTimestamp);
    final timeSinceLastShown = DateTime.now().difference(lastShown);
    
    if (timeSinceLastShown >= Duration(minutes: _cooldownMinutes)) {
      return true;
    }

    adLog('[ChannelChangeInterstitial] Cooldown active, skipping');
    return false;
  }

  /// Record a channel change event
  Future<void> recordChannelChange() async {
    final prefs = await SharedPreferences.getInstance();
    _channelChangeCount = prefs.getInt(_channelChangeCountKey) ?? 0;
    _channelChangeCount++;
    await prefs.setInt(_channelChangeCountKey, _channelChangeCount);
  }

  /// Show interstitial if eligible
  Future<bool> showIf(BuildContext context) async {
    if (!await canShow()) {
      return false;
    }

    await recordChannelChange();
    return show(context);
  }

  /// Show interstitial (call only if canShow() returns true)
  Future<bool> show(BuildContext context) async {
    if (!context.mounted) return false;
    if (_isShowing) return false;

    _isShowing = true;
    
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _ChannelChangeInterstitialDialog(
          onDismiss: () {
            Navigator.of(dialogContext).pop(true);
          },
        ),
      );

      // Record last shown time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastShownKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      adLog('[ChannelChangeInterstitial] Shown successfully');
      return result ?? false;
    } catch (e) {
      adLog('[ChannelChangeInterstitial] Error showing: $e');
      return false;
    } finally {
      _isShowing = false;
    }
  }

  /// Reset cooldown (for testing)
  Future<void> resetCooldown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastShownKey);
    await prefs.remove(_channelChangeCountKey);
    _channelChangeCount = 0;
    _lastShownTime = null;
  }
}

/// In-app interstitial dialog with auto-dismiss after 5 seconds
class _ChannelChangeInterstitialDialog extends StatefulWidget {
  const _ChannelChangeInterstitialDialog({
    required this.onDismiss,
  });

  final VoidCallback onDismiss;

  @override
  State<_ChannelChangeInterstitialDialog> createState() =>
      _ChannelChangeInterstitialDialogState();
}

class _ChannelChangeInterstitialDialogState
    extends State<_ChannelChangeInterstitialDialog> {
  Timer? _dismissTimer;
  bool _canDismiss = false;

  @override
  void initState() {
    super.initState();
    
    // Allow dismiss after 5 seconds
    _dismissTimer = Timer(
      const Duration(seconds: ChannelChangeInterstitialController._dismissibleAfterSeconds),
      () {
        if (mounted) {
          setState(() {
            _canDismiss = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _handleDismiss() {
    if (_canDismiss) {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Ad content
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.7,
            child: AdsterraWebView(
              html: AdsterraHtml.interstitial(),
              height: MediaQuery.of(context).size.height * 0.7,
              placement: 'channel_change_interstitial',
              userVisible: true,
            ),
          ),
          // Dismiss button (appears after 5 seconds)
          if (_canDismiss)
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: _handleDismiss,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          // Countdown/Loading indicator
          if (!_canDismiss)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Loading...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
