import 'package:flutter_test/flutter_test.dart';
import 'package:lumio_tv/services/featured_live_events_service.dart';

void main() {
  group('shouldFetchAppwritePayload', () {
    test('refreshes when Appwrite updated_at changes', () {
      expect(
        FeaturedLiveEventsService.shouldFetchAppwritePayload(
          forceRefresh: false,
          remoteUpdatedAt: '2026-06-04T10:00:00.000Z',
          cachedUpdatedAt: '2026-06-03T10:00:00.000Z',
          cacheHit: true,
        ),
        isTrue,
      );
    });

    test('skips parse when cache fresh and updated_at unchanged', () {
      expect(
        FeaturedLiveEventsService.shouldFetchAppwritePayload(
          forceRefresh: false,
          remoteUpdatedAt: '2026-06-03T10:00:00.000Z',
          cachedUpdatedAt: '2026-06-03T10:00:00.000Z',
          cacheHit: true,
        ),
        isFalse,
      );
    });

    test('forceRefresh always fetches', () {
      expect(
        FeaturedLiveEventsService.shouldFetchAppwritePayload(
          forceRefresh: true,
          remoteUpdatedAt: 'a',
          cachedUpdatedAt: 'a',
          cacheHit: true,
        ),
        isTrue,
      );
    });
  });

  test('readFeaturedChannelUrl accepts stream_url alias', () {
    expect(
      readFeaturedChannelUrl({'stream_url': 'https://x.m3u8'}),
      'https://x.m3u8',
    );
  });
}
