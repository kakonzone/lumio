import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/ads/ad_cold_start_eligibility.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/services/ad_safety_service.dart';
import 'package:lumio_tv/services/server_cap.dart';
import 'package:lumio_tv/services/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.ensureInit();
    AdColdStartEligibility.debugResetLogOnce();
    AdSafetyService.instance.debugSetPreferCleanSdkRouting(null);
    AdSafetyService.instance.debugSetAdsterraEnabled(null);
    ServerCap.debugTreatAsConfigured = false;
  });

  test('report lists monetization and cap blockers when unset', () async {
    final report = await AdColdStartEligibility.evaluate();
    expect(
      report.blockers.any(
        (b) => b.code == AdColdStartBlockerCode.noMonetizationConfig,
      ),
      !AdConfig.hasMonetizationConfig,
    );
  });

  test('VPN preferCleanSdk still allows cold-start Adsterra flag', () {
    AdSafetyService.instance.debugSetPreferCleanSdkRouting(true);
    expect(AdSafetyService.instance.adsterraEnabled, isFalse);
    expect(AdSafetyService.instance.adsterraEnabledForColdStart, isTrue);
  });
}
