import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/config/ad_config.dart';

void main() {
  test('LevelPlay banner refresh is dashboard-only constant', () {
    expect(AdConfig.levelPlayBannerDashboardRefreshSeconds, 60);
    expect(AdConfig.bannerAdUnitId, isA<String>());
  });
}
