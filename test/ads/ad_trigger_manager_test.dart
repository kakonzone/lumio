import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/ad_trigger_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('blocks interstitial before min channel clicks', () async {
    final caps = AdTriggerManager.instance;
    await caps.startSession();
    caps.debugBackdateSessionStart(const Duration(seconds: 10));
    caps.recordChannelClick();
    caps.recordChannelClick();
    expect(
      caps.debugSessionAllowsInterstitial(
        isStreaming: false,
        removeAds: false,
      ),
      isFalse,
    );
    caps.recordChannelClick();
    expect(
      caps.debugSessionAllowsInterstitial(
        isStreaming: false,
        removeAds: false,
      ),
      isTrue,
    );
  });

  test('app-open substitute does not require channel clicks', () async {
    final caps = AdTriggerManager.instance;
    caps.markConsentResolved();
    await caps.waitUntilAdsEligible();
    await caps.startSession();
    expect(caps.sessionChannelClicks, 0);
    expect(
      caps.debugSessionAllowsInterstitial(
        isStreaming: false,
        removeAds: false,
      ),
      isFalse,
    );
    expect(caps.debugIsAdsEligible, isTrue);
  });

  test('exit ad does not require channel clicks', () async {
    final caps = AdTriggerManager.instance;
    caps.markConsentResolved();
    await caps.waitUntilAdsEligible();
    expect(caps.canShowExitAd(removeAds: false), isTrue);
    expect(caps.sessionChannelClicks, 0);
  });

  test('recordInterstitialAttempted does not increment shown count', () async {
    final caps = AdTriggerManager.instance;
    await caps.startSession();
    caps.recordInterstitialAttempted();
    caps.recordInterstitialAttempted();
    expect(caps.debugSessionInterstitialAttempts, 2);
    expect(caps.debugSessionInterstitialsShown, 0);
  });

  test('session cap uses shown count not attempt count', () async {
    final caps = AdTriggerManager.instance;
    await caps.startSession();
    caps.debugBackdateSessionStart(const Duration(seconds: 120));
    for (var i = 0; i < 3; i++) {
      caps.recordChannelClick();
    }
    for (var i = 0; i < 8; i++) {
      caps.recordInterstitialAttempted();
    }
    expect(caps.debugSessionInterstitialsShown, 0);
    expect(
      caps.debugSessionAllowsInterstitial(
        isStreaming: false,
        removeAds: false,
      ),
      isTrue,
    );
  });

  test('recordInterstitialShown increments shown count only', () async {
    final caps = AdTriggerManager.instance;
    await caps.startSession();
    await caps.recordInterstitialShown();
    expect(caps.debugSessionInterstitialsShown, 1);
    expect(caps.debugSessionInterstitialAttempts, 0);
  });

  test('blocks interstitial while streaming', () async {
    final caps = AdTriggerManager.instance;
    await caps.startSession();
    caps.debugBackdateSessionStart(const Duration(seconds: 10));
    for (var i = 0; i < 5; i++) {
      caps.recordChannelClick();
    }
    expect(
      caps.debugSessionAllowsInterstitial(
        isStreaming: true,
        removeAds: false,
      ),
      isFalse,
    );
  });
}
