import 'dart:async';

import 'package:flutter/material.dart';

import '../../ads/ad_manager.dart';
import '../../services/ad_trigger_manager.dart';
import '../../services/user_preferences.dart';
import '../utils/webview_pool.dart';
import 'adsterra_html.dart';
import 'adsterra_webview.dart';

/// Hidden 1×1 popunder loader — mounts only when [canMount] passes session cap.
class AdsterraPopunderHost extends StatefulWidget {
  const AdsterraPopunderHost({super.key});

  /// True when consent, RC, caps, and cooldown allow the WebView to load.
  static Future<bool> canMount() async {
    if (UserPreferences.removeAdsPurchased) return false;
    if (!AdManager.instance.adsEnabled) return false;
    return AdTriggerManager.instance.canShowPopunder();
  }

  @override
  State<AdsterraPopunderHost> createState() => _AdsterraPopunderHostState();
}

class _AdsterraPopunderHostState extends State<AdsterraPopunderHost> {
  late final Future<bool> _mountFuture = AdsterraPopunderHost.canMount();
  bool _recorded = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _mountFuture,
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return const SizedBox.shrink();
        }
        return _PopunderWebView(
          onMounted: () {
            if (_recorded) return;
            _recorded = true;
            unawaited(AdManager.instance.onPopunderWebViewMounted());
          },
        );
      },
    );
  }
}

class _PopunderWebView extends StatefulWidget {
  const _PopunderWebView({required this.onMounted});

  final VoidCallback onMounted;

  @override
  State<_PopunderWebView> createState() => _PopunderWebViewState();
}

class _PopunderWebViewState extends State<_PopunderWebView> {
  bool _acquired = false;

  @override
  void initState() {
    super.initState();
    _acquired = WebViewPool.instance.acquire('popunder');
    if (_acquired) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMounted());
    }
  }

  @override
  void dispose() {
    if (_acquired) WebViewPool.instance.release('popunder');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_acquired) return const SizedBox.shrink();
    return ClipRect(
      child: SizedBox(
        width: 1,
        height: 1,
        child: AdsterraWebView(
          html: AdsterraHtml.popunder(),
          height: 1,
          placement: 'popunder',
          fullWidth: false,
        ),
      ),
    );
  }
}
