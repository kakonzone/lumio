import 'dart:async';

import 'package:flutter/material.dart';
import '../config/ad_config.dart';
import '../theme/tokens/colors.dart';

/// Custom rewarded ad overlay with 15s skip button and 30s auto-close.
/// Supports ad chaining: skip → show another ad.
class CustomRewardedAdOverlay extends StatefulWidget {
  final VoidCallback? onDismissed;
  final VoidCallback? onRewardEarned;
  final int totalAdsInChain;

  const CustomRewardedAdOverlay({
    super.key,
    this.onDismissed,
    this.onRewardEarned,
    this.totalAdsInChain = 1,
  });

  @override
  State<CustomRewardedAdOverlay> createState() => _CustomRewardedAdOverlayState();
}

class _CustomRewardedAdOverlayState extends State<CustomRewardedAdOverlay> {
  static const _skipDelaySeconds = AdConfig.skipDelaySeconds;
  static const _autoCloseSeconds = 30;

  Timer? _skipTimer;
  Timer? _autoCloseTimer;
  int _secondsUntilSkip = _skipDelaySeconds;
  int _secondsUntilAutoClose = _autoCloseSeconds;
  bool _skipEnabled = false;
  bool _adShowing = false;
  int _currentAdIndex = 1;

  @override
  void initState() {
    super.initState();
    _startTimers();
    _showAd();
  }

  void _startTimers() {
    _skipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsUntilSkip--;
        if (_secondsUntilSkip <= 0) {
          _skipEnabled = true;
          timer.cancel();
        }
      });
    });

    _autoCloseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsUntilAutoClose--;
        if (_secondsUntilAutoClose <= 0) {
          timer.cancel();
          _dismiss();
        }
      });
    });
  }

  Future<void> _showAd() async {
    setState(() => _adShowing = true);
    // Unity Ads disabled - no rewarded ad shown
    if (!mounted) return;
    setState(() => _adShowing = false);
  }

  void _dismiss() {
    if (!mounted) return;
    _skipTimer?.cancel();
    _autoCloseTimer?.cancel();
    Navigator.of(context).pop();
    widget.onDismissed?.call();
  }

  void _handleSkip() {
    if (!_skipEnabled) return;
    
    // Chain to next ad if more ads remaining
    if (_currentAdIndex < widget.totalAdsInChain) {
      setState(() {
        _currentAdIndex++;
        _secondsUntilSkip = _skipDelaySeconds;
        _secondsUntilAutoClose = _autoCloseSeconds;
        _skipEnabled = false;
      });
      _skipTimer?.cancel();
      _autoCloseTimer?.cancel();
      _startTimers();
      _showAd();
    } else {
      _dismiss();
    }
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // Ad content area (Unity Ads takes full screen)
          if (_adShowing)
            const Center(
              child: CircularProgressIndicator(
                color: AppTokens.accent,
                strokeWidth: 2,
              ),
            )
          else
            const Center(
              child: Text(
                'Ad Loading...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),

          // Top-left countdown
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ad $_currentAdIndex of ${widget.totalAdsInChain}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Progress bar
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1 - (_secondsUntilAutoClose / _autoCloseSeconds),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTokens.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_secondsUntilAutoClose}s',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Skip button (bottom-right)
          Positioned(
            bottom: 24,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _skipEnabled ? 1.0 : 0.5,
              child: GestureDetector(
                onTap: _skipEnabled ? _handleSkip : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _skipEnabled
                        ? AppTokens.accent
                        : Colors.grey.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_skipEnabled) ...[
                        Text(
                          '$_secondsUntilSkip',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text(
                        'Skip Ad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
