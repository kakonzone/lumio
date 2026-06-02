import 'package:webview_flutter/webview_flutter.dart';

/// Shared navigation rules for visible Adsterra WebViews (not headless Monetag engine).
class AdWebViewNavigationPolicy {
  AdWebViewNavigationPolicy._();

  static const _allowedSchemes = {'https', 'http', 'about', 'data', 'blob'};

  static NavigationDecision evaluate(String url) {
    final lower = url.trim().toLowerCase();
    if (lower.isEmpty) return NavigationDecision.prevent;

    final uri = Uri.tryParse(url);
    if (uri == null) return NavigationDecision.prevent;

    final scheme = uri.scheme.toLowerCase();
    if (!_allowedSchemes.contains(scheme)) {
      return NavigationDecision.prevent;
    }
    if (scheme == 'file' || lower.startsWith('content://')) {
      return NavigationDecision.prevent;
    }
    if (lower.startsWith('intent://') ||
        lower.startsWith('market://') ||
        lower.startsWith('javascript:')) {
      return NavigationDecision.prevent;
    }
    if (lower.contains('.apk') && !lower.contains('adsterra')) {
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }
}
