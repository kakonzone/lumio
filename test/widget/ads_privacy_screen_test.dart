import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/screens/ads_privacy_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'lumio_ads_consent_v1': 'granted',
    });
  });

  testWidgets('AdsPrivacyScreen shows legal links', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdsPrivacyScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ads & privacy'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Data deletion request'), findsOneWidget);
  });
}
