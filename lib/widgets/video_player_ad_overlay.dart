import 'dart:async';

import 'package:flutter/material.dart';

import '../config/ad_config.dart';

/// Ad overlay widget for rewarded video ads in player.
///
/// Shows skip button with countdown, ad counter, and blocks back button.
/// Handles both portrait and fullscreen orientations.
class VideoPlayerAdOverlay extends StatefulWidget {
  final bool isFullscreen;
  final int currentAdIndex;
  final int totalAdsInPod;
  final VoidCallback onSkip;
  final VoidCallback onAdComplete;

  const VideoPlayerAdOverlay({
    super.key,
    required this.isFullscreen,
    required this.currentAdIndex,
    required this.totalAdsInPod,
    required this.onSkip,
    required this.onAdComplete,
  });

  @override
  State<VideoPlayerAdOverlay> createState() => _VideoPlayerAdOverlayState();
}

class _VideoPlayerAdOverlayState extends State<VideoPlayerAdOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _skipCountdown = AdConfig.skipDelaySeconds;
  Timer? _countdownTimer;
  bool _skipEnabled = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _startSkipCountdown();
  }

  void _startSkipCountdown() {
    _skipCountdown = AdConfig.skipDelaySeconds;
    _skipEnabled = false;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _skipCountdown--;
        if (_skipCountdown <= 0) {
          _skipEnabled = true;
          timer.cancel();
        }
      });
    });
  }

  void _handleSkip() {
    if (_skipEnabled) {
      _fadeOut(() {
        widget.onSkip();
      });
    }
  }

  void _fadeOut(VoidCallback callback) {
    _fadeController.forward().then((_) {
      callback();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Block back button during ad
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          color: Colors.black, // Black opaque background
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Skip button (top-right)
              Positioned(
                top: widget.isFullscreen ? 24 : 8,
                right: widget.isFullscreen ? 24 : 8,
                child: _buildSkipButton(),
              ),

              // Ad counter (bottom-left)
              Positioned(
                bottom: widget.isFullscreen ? 24 : 8,
                left: widget.isFullscreen ? 24 : 8,
                child: _buildAdCounter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    final buttonSize = widget.isFullscreen ? 56.0 : 40.0;
    final fontSize = widget.isFullscreen ? 16.0 : 12.0;

    if (!_skipEnabled) {
      // Show countdown
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isFullscreen ? 16 : 12,
          vertical: widget.isFullscreen ? 8 : 4,
        ),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Skip in $_skipCountdown',
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Show enabled skip button
    return GestureDetector(
      onTap: _handleSkip,
      child: Container(
        height: buttonSize,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isFullscreen ? 20 : 14,
          vertical: widget.isFullscreen ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip Ad',
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: widget.isFullscreen ? 8 : 4),
            Icon(
              Icons.skip_next,
              color: Colors.black,
              size: widget.isFullscreen ? 20 : 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCounter() {
    final fontSize = widget.isFullscreen ? 14.0 : 11.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isFullscreen ? 12 : 8,
        vertical: widget.isFullscreen ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Ad ${widget.currentAdIndex} of ${widget.totalAdsInPod}',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
