import '../../config/ad_config.dart';

/// Builds Adsterra invoke HTML for WebView placements.
class AdsterraHtml {
  AdsterraHtml._();

  static String nativeBanner({double height = 100}) => _wrap(
        baseUrl: AdConfig.adsterraNativeBaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraNativeInvokeUrl}"></script>
<div id="${AdConfig.adsterraNativeContainerId}"></div>
''',
        minHeight: height,
      );

  static String banner728x90() => _wrap(
        baseUrl: AdConfig.adsterraBanner728BaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraBanner728InvokeUrl}"></script>
<div id="${AdConfig.adsterraBanner728ContainerId}"></div>
''',
        minHeight: 90,
      );

  static String socialBar() => _wrap(
        baseUrl: AdConfig.adsterraSocialBaseUrl,
        body: '''
<script type="text/javascript" src="${AdConfig.adsterraSocialScriptUrl}"></script>
''',
        minHeight: 50,
      );

  /// First channel-tap fullscreen (in-app, no browser).
  static String channelTapFullscreen() => _wrap(
        baseUrl: AdConfig.adsterraNativeBaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraNativeInvokeUrl}"></script>
<div id="${AdConfig.adsterraNativeContainerId}"></div>
''',
        minHeight: 400,
        fullViewport: true,
      );

  /// Full-bleed in-player video/native creative (player overlay).
  static String playerInStream() => _wrap(
        baseUrl: AdConfig.adsterraNativeBaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraNativeInvokeUrl}"></script>
<div id="${AdConfig.adsterraNativeContainerId}"></div>
''',
        minHeight: 280,
        fullViewport: true,
      );

  static String popunder() => _wrap(
        baseUrl: AdConfig.adsterraPopunderBaseUrl,
        body: '''
<script type="text/javascript" src="${AdConfig.adsterraPopunderScriptUrl}"></script>
''',
        minHeight: 1,
      );

  static String _wrap({
    required String baseUrl,
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
<base href="$baseUrl">
<style>
  html, body { margin:0; padding:0; background:#000; overflow:hidden; width:100%; height:100%; }
  body { ${fullViewport ? 'min-height:100vh; display:flex; align-items:center; justify-content:center;' : 'min-height:${minHeight}px;'} }
  iframe, video, img { max-width:100%; }
</style>
</head>
<body>$body</body>
</html>
''';

  /// WebView loadHtmlString এর জন্য base URL (script load fix)
  static String baseUrlForPlacement(String placement) {
    switch (placement) {
      case 'popunder':
        return AdConfig.adsterraPopunderBaseUrl;
      case 'social_bar':
        return AdConfig.adsterraSocialBaseUrl;
      case 'banner_728':
        return AdConfig.adsterraBanner728BaseUrl;
      case 'player_video':
      case 'channel_tap':
        return AdConfig.adsterraNativeBaseUrl;
      default:
        return AdConfig.adsterraNativeBaseUrl;
    }
  }
}
