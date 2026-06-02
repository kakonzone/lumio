import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/monetag_config.dart';
import '../../services/ad_trigger_manager.dart';
import '../ad_log.dart';
import '../analytics/ad_analytics.dart';
import 'propeller_html.dart';
import 'propeller_service.dart';
import 'propeller_webview.dart';

/// Visible Monetag actions — smartlink, vignette WebView, telemetry.
class PropellerEngine {
  PropellerEngine._();
  static final PropellerEngine instance = PropellerEngine._();

  Future<bool> openSmartlink({
    required String placement,
    AdAnalytics? analytics,
  }) async {
    final url = PropellerAdsService.smartlinkUrl();
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        AdTriggerManager.instance.recordAdsterraSurfaceEvent();
        final a = analytics;
        if (a != null) {
          unawaited(
            a.logClick(
              network: 'monetag',
              format: 'smartlink',
              placement: placement,
            ),
          );
        }
        adLog('[Monetag] smartlink opened placement=$placement');
      }
      return ok;
    } catch (e) {
      adLog('[Monetag] smartlink failed: $e');
      return false;
    }
  }

  /// Fullscreen vignette interstitial (tab switch / first-tap LevelPlay slot).
  Future<bool> showVignetteDialog(
    BuildContext context, {
    required String placement,
    int minSeconds = 5,
  }) async {
    if (!MonetagConfig.isConfigured) return false;
    if (!context.mounted) return false;

    try {
      final completed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PropellerVignetteDialog(
          placement: placement,
          minSeconds: minSeconds,
        ),
      );
      return completed == true;
    } catch (e) {
      adLog('[Monetag] vignette dialog error: $e');
      return false;
    }
  }
}

class _PropellerVignetteDialog extends StatefulWidget {
  const _PropellerVignetteDialog({
    required this.placement,
    required this.minSeconds,
  });

  final String placement;
  final int minSeconds;

  @override
  State<_PropellerVignetteDialog> createState() =>
      _PropellerVignetteDialogState();
}

class _PropellerVignetteDialogState extends State<_PropellerVignetteDialog> {
  Timer? _tick;
  int _elapsed = 0;
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed++;
        if (_elapsed >= widget.minSeconds) _canClose = true;
      });
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wait = (widget.minSeconds - _elapsed).clamp(0, 999);
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PropellerWebView(
            html: PropellerHtml.vignette(),
            height: MediaQuery.sizeOf(context).height,
            placement: widget.placement,
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: const Text(
              'Ad · Monetag',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 24,
            child: FilledButton(
              onPressed: _canClose
                  ? () => Navigator.of(context).pop(true)
                  : null,
              child: Text(_canClose ? 'Continue' : '$wait s'),
            ),
          ),
        ],
      ),
    );
  }
}
