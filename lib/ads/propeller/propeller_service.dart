import '../../config/monetag_config.dart';
import 'propeller_html.dart';

/// Monetag zone accessors (PropellerAds publisher dashboard).
class PropellerAdsService {
  PropellerAdsService._();

  static String get onclickZoneId => MonetagConfig.effectiveOnclickZoneId;
  static String get interstitialZoneId => MonetagConfig.effectiveVignetteZoneId;
  static String get pushZoneId => MonetagConfig.effectivePushZoneId;
  static String get inPagePushZoneId => MonetagConfig.effectiveInPagePushZoneId;

  static String onclickHtml() => PropellerHtml.onclick();

  static String interstitialHtml() => PropellerHtml.vignette();

  static String pushSubscriptionHtml() => PropellerHtml.pushSubscription();

  static String inPagePushHtml({double height = 50}) =>
      PropellerHtml.inPagePush(minHeight: height);

  static String smartlinkUrl() => MonetagConfig.directLinkUrl.trim();
}
