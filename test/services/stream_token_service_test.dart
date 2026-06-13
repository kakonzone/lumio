import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lumio_tv/services/stream_token_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    StreamTokenService.instance.baseUrlOverrideForTest =
        'https://api.test.example';
  });

  tearDown(() {
    StreamTokenService.instance.clearCacheForTest();
    StreamTokenService.instance.httpClientOverride = null;
    StreamTokenService.instance.baseUrlOverrideForTest = null;
  });

  group('StreamTokenService.fetchToken', () {
    test('200 returns token and caches stream URL', () async {
      StreamTokenService.instance.httpClientOverride =
          MockClient((request) async {
        expect(request.url.path, contains('stream-token'));
        final body = jsonDecode(request.body as String) as Map<String, dynamic>;
        expect(body['channelId'], 'ch_1');
        return http.Response(
          jsonEncode({
            'token': 'tok_abc',
            'expiresIn': 3600,
            'streamUrl': 'https://cdn.example/live.m3u8?sig=1',
          }),
          200,
        );
      });

      final result = await StreamTokenService.instance.fetchTokenResult(
        channelId: 'ch_1',
        originalUrl: 'http://starshare.net/live/1',
      );
      expect(result, isNotNull);
      expect(result!.streamUrl, contains('cdn.example'));
      expect(result.expiresInSeconds, 3600);

      final cached = await StreamTokenService.instance.fetchTokenResult(
        channelId: 'ch_1',
      );
      expect(cached?.streamUrl, result.streamUrl);
    });

    test('401 returns null', () async {
      StreamTokenService.instance.httpClientOverride =
          MockClient((request) async {
        return http.Response('unauthorized', 401);
      });

      final result = await StreamTokenService.instance.fetchTokenResult(
        channelId: 'ch_denied',
      );
      expect(result, isNull);
    });

    test('network error falls back to originalUrl when set', () async {
      StreamTokenService.instance.httpClientOverride =
          MockClient((request) async {
        throw Exception('socket failed');
      });

      const original = 'http://starshare.net/live/fallback.m3u8';
      final result = await StreamTokenService.instance.fetchTokenResult(
        channelId: 'ch_net',
        originalUrl: original,
      );
      expect(result, isNotNull);
      expect(result!.streamUrl, contains('starshare.net/live/fallback.m3u8'));
    });

    test('missing BASE_URL uses direct originalUrl', () async {
      StreamTokenService.instance.baseUrlOverrideForTest = '';

      final result = await StreamTokenService.instance.fetchTokenResult(
        channelId: 'ch_direct',
        originalUrl: 'https://cdn.example/line.m3u8',
      );
      expect(result, isNotNull);
      expect(result!.streamUrl, 'https://cdn.example/line.m3u8');
    });
  });
}
