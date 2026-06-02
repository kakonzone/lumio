import '../../config/monetag_config.dart';
import 'propeller_html.dart';

/// Monetag zone accessors (PropellerAds publisher dashboard).
class PropellerAdsService {
  PropellerAdsService._();

  static String get onclickZoneId => MonetagConfig.onclickZoneId;
  static String get interstitialZoneId => MonetagConfig.vignetteZoneId;
  static String get pushZoneId => MonetagConfig.pushZoneId;
  static String get inPagePushZoneId => MonetagConfig.inPagePushZoneId;

  static String onclickHtml() => PropellerHtml.onclick();

  static String interstitialHtml() => PropellerHtml.vignette();

  static String pushSubscriptionHtml() => PropellerHtml.pushSubscription();

  static String inPagePushHtml({double height = 50}) =>
      PropellerHtml.inPagePush(minHeight: height);

  static String smartlinkUrl() => MonetagConfig.directLinkUrl.trim();
}
