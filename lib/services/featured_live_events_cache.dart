import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_config.dart';
import 'featured_live_events_service.dart';

/// Disk cache for Appwrite featured live event cards.
class FeaturedLiveEventsCache {
  FeaturedLiveEventsCache._();
  static final FeaturedLiveEventsCache instance = FeaturedLiveEventsCache._();

  static const _bodyKey = 'lumio_featured_live_events_v2';
  static const _tsKey = 'lumio_featured_live_events_ts_v2';
  static const _updatedAtKey = 'lumio_featured_live_events_updated_at_v2';

  Future<FeaturedLiveEventsPayload?> read({bool ignoreTtl = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_tsKey);
    if (ts == null) return null;
    if (!ignoreTtl) {
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > AppwriteConfig.featuredLiveEventsCacheTtl.inMilliseconds) {
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

  Future<void> write(
    FeaturedLiveEventsPayload payload, {
    String? remoteUpdatedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyKey, jsonEncode(payload.toJson()));
    await prefs.setInt(_tsKey, DateTime.now().millisecondsSinceEpoch);
    final ua = remoteUpdatedAt?.trim();
    if (ua != null && ua.isNotEmpty) {
      await prefs.setString(_updatedAtKey, ua);
    }
  }

  Future<String?> readRemoteUpdatedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_updatedAtKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bodyKey);
    await prefs.remove(_tsKey);
    await prefs.remove(_updatedAtKey);
  }
}
