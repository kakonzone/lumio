import '../../config/monetag_config.dart';

/// Monetag / Propeller tag HTML for in-app WebViews.
class PropellerHtml {
  PropellerHtml._();

  static const _basePage = 'https://monetag.local/';

  /// OnClick / popunder loader (shell 1×1 host).
  static String onclick() => _wrap(
        body: '''
<script>(function(s){s.dataset.zone='${MonetagConfig.effectiveOnclickZoneId}',s.src='${MonetagConfig.onclickScriptHost}/tag.min.js'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
''',
        minHeight: 1,
      );

  /// Vignette interstitial (tab switch / exit fallback).
  static String vignette() => _wrap(
        body: '''
<script>(function(s){s.dataset.zone='${MonetagConfig.effectiveVignetteZoneId}',s.src='${MonetagConfig.vignetteScriptHost}/vignette.min.js'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
''',
        minHeight: 400,
        fullViewport: true,
      );

  /// Push subscription prompt.
  static String pushSubscription() => _wrap(
        body: '''
<script src="${MonetagConfig.pushScriptUrl}" data-cfasync="false" async></script>
''',
        minHeight: 120,
      );

  /// In-page push / native banner strip.
  static String inPagePush({double minHeight = 50}) => _wrap(
        body: '''
<script>(function(s){s.dataset.zone='${MonetagConfig.effectiveInPagePushZoneId}',s.src='${MonetagConfig.inPagePushHost}/tag.min.js'})([document.documentElement, document.body].filter(Boolean).pop().appendChild(document.createElement('script')))</script>
''',
        minHeight: minHeight,
      );

  static String _wrap({
    required String body,
    required double minHeight,
    bool fullViewport = false,
  }) =>
      '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<base href="$_basePage">
<style>
  html, body { margin:0; padding:0; background:transparent !important; overflow:hidden; width:100%; height:100%; }
  body { ${fullViewport ? 'min-height:100vh;' : 'min-height:${minHeight}px;'} }
  body, body * { background-color: transparent !important; }
</style>
</head>
<body>$body</body>
</html>
''';

  static String baseUrlForPlacement(String placement) => _basePage;
}
