import '../../config/ad_config.dart';
import '../ad_log.dart';
import 'direct_link_rotator.dart';
import 'external_url_launcher.dart';

/// Opens Adsterra direct / smart link in external browser (first channel tap).
class AdsterraDirectLink {
  AdsterraDirectLink._();

  static Future<bool> open() async {
    if (!AdConfig.hasAdsterraDirectLink) return false;
    final pool = AdConfig.adsterraDirectLinkRotation;
    if (pool.isEmpty) return false;
    return ExternalUrlLauncher.openInBrowser(pool.first);
  }

  /// First channel tap: random direct link in external browser.
  static Future<bool> openChannelTapInBrowser() async {
    if (!AdConfig.hasAdsterraDirectLink) {
      adLog('[AdsterraDirectLink] channel_tap — direct links not configured');
      return false;
    }
    final picked = DirectLinkRotator.pickUrl();
    if (picked == null) {
      adLog('[AdsterraDirectLink] no direct link in rotation');
      return false;
    }
    adLog('[AdsterraDirectLink] channel_tap opening rotated link');
    if (await ExternalUrlLauncher.openInBrowser(picked)) {
      adLog('[AdsterraDirectLink] channel_tap browser (random direct link)');
      return true;
    }
    adLog('[AdsterraDirectLink] channel_tap browser failed for rotated url');
    return false;
  }
}
