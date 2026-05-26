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

  testWidgets('AdsPrivacyScreen shows both ad choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdsPrivacyScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ads & privacy'), findsOneWidget);
    expect(find.text('Personalized ads'), findsOneWidget);
    expect(find.text('Limited ads only'), findsOneWidget);
  });
}
