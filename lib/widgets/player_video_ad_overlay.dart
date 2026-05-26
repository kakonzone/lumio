import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../config/ad_config.dart';

/// In-player video ad surface (Adsterra WebView) with YouTube-style skip after [skipAfterSeconds].
class PlayerVideoAdOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final int skipAfterSeconds;
  final int maxDurationSeconds;
  final String placement;

  const PlayerVideoAdOverlay({
    super.key,
    required this.onDismiss,
    this.skipAfterSeconds = AdConfig.playerVideoAdSkipSeconds,
    this.maxDurationSeconds = AdConfig.playerVideoAdMaxSeconds,
    this.placement = 'player_video',
  });

  @override
  State<PlayerVideoAdOverlay> createState() => _PlayerVideoAdOverlayState();
}

class _PlayerVideoAdOverlayState extends State<PlayerVideoAdOverlay> {
  late final WebViewController _web;
  Timer? _tick;
  Timer? _maxTimer;
  int _elapsed = 0;
  bool _skipEnabled = false;

  @override
  void initState() {
    super.initState();
    final baseUrl = AdsterraHtml.baseUrlForPlacement(widget.placement);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadHtmlString(
        AdsterraHtml.playerInStream(),
        baseUrl: baseUrl,
      );

    unawaited(
      AdManager.instance.analytics.logAdsterraNativeLoaded(
        placement: widget.placement,
      ),
    );

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= widget.skipAfterSeconds) _skipEnabled = true;
      });
    });

    _maxTimer = Timer(Duration(seconds: widget.maxDurationSeconds), _dismiss);
  }

  void _dismiss() {
    _tick?.cancel();
    _maxTimer?.cancel();
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _maxTimer?.cancel();
    super.dispose();
  }

  int get _skipCountdown =>
      (widget.skipAfterSeconds - _elapsed).clamp(0, widget.skipAfterSeconds);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: _web),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ad',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 16,
            child: _SkipControl(
              skipEnabled: _skipEnabled,
              countdown: _skipCountdown,
              onSkip: _dismiss,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipControl extends StatelessWidget {
  final bool skipEnabled;
  final int countdown;
  final VoidCallback onSkip;

  const _SkipControl({
    required this.skipEnabled,
    required this.countdown,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final label = skipEnabled ? 'Skip Ad' : 'Skip in ${countdown}s';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: skipEnabled ? onSkip : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: skipEnabled
                ? Colors.white.withValues(alpha: 0.92)
                : Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: skipEnabled
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: skipEnabled ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
