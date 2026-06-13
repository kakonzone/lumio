import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../ads/ad_manager.dart';
import '../ads/adsterra/adsterra_html.dart';
import '../ads/adsterra/adsterra_webview.dart';
import '../ads/interstitial_placement.dart';
import '../ads/utils/lumio_webview_config.dart';
import '../config/ad_config.dart';
import '../services/ad_consent_service.dart';
import '../services/ad_safety_service.dart';
import '../services/ad_trigger_manager.dart';
import '../theme/app_theme.dart';
import '../theme/tokens/colors.dart';

/// App-open promo with real Adsterra WebView (or direct-link fallback).
class AppOpenPromoScreen extends StatefulWidget {
  const AppOpenPromoScreen({super.key});

  @override
  State<AppOpenPromoScreen> createState() => _AppOpenPromoScreenState();
}

class _AppOpenPromoScreenState extends State<AppOpenPromoScreen> {
  static const _countdownTotal = AdConfig.appOpenPromoCountdownSeconds;

  Timer? _tick;
  Timer? _failsafe;
  int _secondsLeft = _countdownTotal;
  bool _dismissed = false;

  bool get _useAdsterraWeb =>
      AdManager.instance.adsEnabled &&
      AdSafetyService.instance.adsterraEnabledForColdStart &&
      AdConfig.hasAdsterraWebViewZones &&
      !AdConsentService.instance.hasDeniedConsent;

  bool get _useDirectLink =>
      AdManager.instance.adsEnabled &&
      AdSafetyService.instance.adsterraEnabledForColdStart &&
      !AdConsentService.instance.hasDeniedConsent &&
      !_useAdsterraWeb &&
      AdConfig.hasValidAdsterraDirectLink;

  @override
  void initState() {
    super.initState();
    unawaited(_onShown());
    _failsafe = Timer(const Duration(seconds: 8), () {
      if (!mounted || _dismissed) return;
      unawaited(_dismiss(auto: true));
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dismissed) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) unawaited(_dismiss(auto: true));
      });
    });
  }

  Future<void> _onShown() async {
    await AdTriggerManager.instance.recordPlacementShown(
      InterstitialPlacement.appOpen,
    );
    final network = _useAdsterraWeb
        ? 'adsterra'
        : (_useDirectLink ? 'adsterra_direct' : 'house');
    unawaited(
      AdManager.instance.analytics.logAdInterstitialShown(
        placement: 'app_open_promo',
        network: network,
      ),
    );
  }

  Future<void> _dismiss({bool auto = false}) async {
    if (_dismissed) return;
    _dismissed = true;
    _tick?.cancel();
    _failsafe?.cancel();
    if (!auto) HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _failsafe?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final adHeight = MediaQuery.sizeOf(context).height * 0.62;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_dismiss());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0C0E),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/lumio_sports_logo.webp',
                      height: 32,
                      errorBuilder: (_, __, ___) => Text(
                        'LUMIO',
                        style: GF.head(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _CountdownBadge(
                        seconds: _secondsLeft.clamp(0, _countdownTotal)),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ColoredBox(
                      color: const Color(0xFF1A1A22),
                      child: _buildAdSlot(adHeight),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 10),
                child: _SkipButton(onPressed: () => unawaited(_dismiss())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdSlot(double adHeight) {
    if (_useAdsterraWeb) {
      return AdsterraWebView(
        html: AdsterraHtml.appOpenFullscreen(),
        height: adHeight,
        placement: 'app_open',
        userVisible: true,
      );
    }
    if (_useDirectLink) {
      return _DirectLinkAdView(height: adHeight);
    }
    return const _HousePromo();
  }
}

class _DirectLinkAdView extends StatefulWidget {
  final double height;

  const _DirectLinkAdView({required this.height});

  @override
  State<_DirectLinkAdView> createState() => _DirectLinkAdViewState();
}

class _DirectLinkAdViewState extends State<_DirectLinkAdView> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final urls = AdConfig.adsterraDirectLinksReleaseSafe;
    if (urls.isEmpty) return;
    final controller = await createLumioWebViewController();
    if (!mounted) return;
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF12141C))
      ..loadRequest(Uri.parse(urls.first));
    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Center(
        child:
            CircularProgressIndicator(color: AppTokens.accent, strokeWidth: 2),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: WebViewWidget(controller: c),
    );
  }
}

class _HousePromo extends StatelessWidget {
  const _HousePromo();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0D1B2A)],
        ),
      ),
      child: Text(
        'Configure ADSTERRA_* or LEVELPLAY keys in secrets.json',
        textAlign: TextAlign.center,
        style: GF.body(fontSize: 13, color: Colors.white70),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final int seconds;

  const _CountdownBadge({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white24),
      ),
      child: Center(
        child: Text(
          seconds > 0 ? '$seconds' : '·',
          style: GF.head(
              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SkipButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          'Skip',
          style: GF.body(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
