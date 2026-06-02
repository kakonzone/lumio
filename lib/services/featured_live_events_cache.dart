import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/special_link_config.dart';
import 'featured_live_events_service.dart';

/// Disk cache for GitHub featured live event cards.
class FeaturedLiveEventsCache {
  FeaturedLiveEventsCache._();
  static final FeaturedLiveEventsCache instance = FeaturedLiveEventsCache._();

  static const _bodyKey = 'lumio_featured_live_events_v1';
  static const _tsKey = 'lumio_featured_live_events_ts_v1';

  Future<FeaturedLiveEventsPayload?> read({bool ignoreTtl = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey);
    if (ts == null) return null;
    if (!ignoreTtl) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > SpecialLinkConfig.featuredLiveEventsCacheTtl.inMilliseconds) {
        return null;
      }
    }

    final raw = prefs.getString(_bodyKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FeaturedLiveEventsPayload.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(FeaturedLiveEventsPayload payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyKey, jsonEncode(payload.toJson()));
    await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bodyKey);
    await prefs.remove(_tsKey);
  }
}
