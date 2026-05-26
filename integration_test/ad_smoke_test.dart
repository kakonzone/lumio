import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lumio_tv/screens/ads_privacy_screen.dart';
import 'package:lumio_tv/services/ad_consent_service.dart';
import 'package:lumio_tv/widgets/ad_consent_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ad/consent smoke — run on device or emulator:
/// `flutter test integration_test/ad_smoke_test.dart`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Ad smoke (integration)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('first-launch consent dialog', (tester) async {
      await AdConsentService.instance.load();
      expect(AdConsentService.instance.needsConsentPrompt, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => AdConsentDialog.showIfNeeded(ctx),
                  child: const Text('Show consent'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show consent'));
      await tester.pumpAndSettle();

      expect(find.text('Ads & privacy'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Limited ads only'), findsOneWidget);

      await tester.tap(find.text('Limited ads only'));
      await tester.pumpAndSettle();

      expect(AdConsentService.instance.hasDeniedConsent, isTrue);
    });

    testWidgets('privacy settings screen renders', (tester) async {
      SharedPreferences.setMockInitialValues({
        'lumio_ads_consent_v1': 'granted',
      });
      await tester.pumpWidget(
        const MaterialApp(home: AdsPrivacyScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personalized ads'), findsOneWidget);
      expect(find.text('Limited ads only'), findsOneWidget);
    });
  });
}
