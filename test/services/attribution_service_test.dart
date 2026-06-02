import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lumio_tv/services/attribution_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AttributionService.instance.handleUri(
      Uri.parse('lumio://open?source=facebook&campaign=wc2026&tab=sports'),
    );
  });

  test('parses UTM and tab from lumio://open', () async {
    expect(AttributionService.instance.pendingTabIndex, 1);
    final stored = await AttributionService.instance.storedAttribution();
    expect(stored['utm_source'], 'facebook');
    expect(stored['utm_campaign'], 'wc2026');
  });

  test('parses channel id from lumio://channel', () async {
    SharedPreferences.setMockInitialValues({});
    await AttributionService.instance.handleUri(
      Uri.parse('lumio://channel?channel_id=test_ch&source=whatsapp'),
    );
    expect(AttributionService.instance.pendingChannelId, 'test_ch');
  });
}
