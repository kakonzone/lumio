import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../ads/adsterra/adsterra_webview.dart';
import '../config/ad_config.dart';
import '../theme/app_theme.dart';

/// Fullscreen in-app Adsterra ad for first channel tap (no external browser).
class ChannelTapAdDialog extends StatefulWidget {
  const ChannelTapAdDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChannelTapAdDialog(),
    );
    return result ?? false;
  }

  @override
  State<ChannelTapAdDialog> createState() => _ChannelTapAdDialogState();
}

class _ChannelTapAdDialogState extends State<ChannelTapAdDialog> {
  Timer? _tick;
  int _elapsed = 0;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    unawaited(
      AdManager.instance.analytics.logAdsterraNativeLoaded(
        placement: 'channel_tap',
      ),
    );
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= AdConfig.channelTapAdMinSeconds) _canClose = true;
      });
    });
  }

  void _close() {
    _tick?.cancel();
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _waitLeft =>
      (AdConfig.channelTapAdMinSeconds - _elapsed).clamp(0, 999);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AdsterraWebView(
            html: AdsterraHtml.channelTapFullscreen(),
            height: h,
            placement: 'channel_tap',
            userVisible: true,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ad · Adsterra',
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
            bottom: 24,
            child: FilledButton(
              onPressed: _canClose ? _close : null,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _canClose ? AppColors.accent : Colors.grey.shade800,
              ),
              child: Text(
                _canClose ? 'চালিয়ে যান' : '$_waitLeft s',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
