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

  /// Post-splash app-open fullscreen — best configured Adsterra zone.
  static String appOpenFullscreen() {
    if (AdConfig.hasAdsterraNativeZone) {
      return _wrap(
        baseUrl: AdConfig.adsterraNativeBaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraNativeInvokeUrl}"></script>
<div id="${AdConfig.adsterraNativeContainerId}"></div>
''',
        minHeight: 400,
        fullViewport: true,
      );
    }
    if (AdConfig.hasAdsterraBanner728) {
      return _wrap(
        baseUrl: AdConfig.adsterraBanner728BaseUrl,
        body: '''
<script async="async" data-cfasync="false"
  src="${AdConfig.adsterraBanner728InvokeUrl}"></script>
<div id="${AdConfig.adsterraBanner728ContainerId}"></div>
''',
        minHeight: 400,
        fullViewport: true,
      );
    }
    return _wrap(
      baseUrl: AdConfig.adsterraPopunderBaseUrl,
      body: '''
<script type="text/javascript" src="${AdConfig.adsterraPopunderScriptUrl}"></script>
''',
      minHeight: 400,
      fullViewport: true,
    );
  }

  static String baseUrlForAppOpen() {
    if (AdConfig.hasAdsterraNativeZone) {
      return AdConfig.adsterraNativeBaseUrl;
    }
    if (AdConfig.hasAdsterraBanner728) {
      return AdConfig.adsterraBanner728BaseUrl;
    }
    return AdConfig.adsterraPopunderBaseUrl;
  }

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

  /// Channel-change interstitial (in-app, dismissible).
  static String interstitial() => _wrap(
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

  /// Full-screen Interstitial Ad (Social Bar based)
  /// Social Bar automatically takes over the screen with high-CPM ads.
  /// Wrapped in a centered container so it fills the WebView properly.
  static String interstitialSocialBar() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Ad</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body {
    width: 100%;
    height: 100%;
    background: #0a0a0a;
    overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    color: #fff;
  }
  body {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    position: relative;
  }
  .loader-wrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 16px;
    opacity: 0.85;
  }
  .spinner {
    width: 44px;
    height: 44px;
    border: 3px solid rgba(255,255,255,0.15);
    border-top-color: #ffcc00;
    border-radius: 50%;
    animation: spin 0.9s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
  .label {
    font-size: 13px;
    letter-spacing: 1.5px;
    text-transform: uppercase;
    color: rgba(255,255,255,0.55);
  }
  /* Social Bar injects its own absolutely-positioned elements.
     We just provide a clean stage. */
  #ad-stage {
    position: fixed;
    inset: 0;
    width: 100vw;
    height: 100vh;
    z-index: 1;
  }
</style>
<script>
  window.open = function(url) {
    window.location.href = url;
    return null;
  };
</script>
</head>
<body>

  <div id="ad-stage"></div>

  <div class="loader-wrap" id="loader">
    <div class="spinner"></div>
    <div class="label">Advertisement</div>
  </div>

  <!-- Adsterra Social Bar -->
  <script src="${AdConfig.adsterraSocialBarScriptUrl}"></script>

  <script>
    // Hide loader once Social Bar likely rendered (it injects DOM async)
    setTimeout(function() {
      var l = document.getElementById('loader');
      if (l) l.style.display = 'none';
    }, 2500);

    // Prevent accidental navigation issues inside WebView
    document.addEventListener('click', function(e) {
      // Social Bar handles its own clicks; we don't block them.
    }, true);
  </script>

</body>
</html>
''';
  }

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
<meta http-equiv="Content-Security-Policy" content="default-src https: data: blob: 'unsafe-inline' 'unsafe-eval'; frame-src https:; object-src 'none'; base-uri $baseUrl;">
<base href="$baseUrl">
<style>
  html, body { margin:0; padding:0; background:transparent !important; overflow:hidden; width:100%; height:100%; }
  body { ${fullViewport ? 'min-height:100vh; display:flex; align-items:center; justify-content:center;' : 'min-height:${minHeight}px;'} }
  body, body * { background-color: transparent !important; }
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
      case 'player_below':
        return AdConfig.adsterraBanner728BaseUrl;
      case 'player_video':
      case 'app_open':
        return baseUrlForAppOpen();
      case 'channel_tap':
      case 'channel_change_interstitial':
        return AdConfig.adsterraNativeBaseUrl;
      default:
        return AdConfig.adsterraNativeBaseUrl;
    }
  }
}
