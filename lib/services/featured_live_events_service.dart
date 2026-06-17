import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/appwrite_config.dart';
import '../models/live_event_match.dart';
import '../models/model.dart';
import 'appwrite_app_config.dart';
import 'featured_live_events_cache.dart';

/// Where home World Cup / featured cards were loaded from.
enum FeaturedLiveEventsSource {
  appwrite,
  cache,
  bundledAsset,
  empty,
}

/// Result of [FeaturedLiveEventsService.load] — includes source for UI/debug.
class FeaturedLiveEventsLoadResult {
  const FeaturedLiveEventsLoadResult({
    required this.payload,
    required this.source,
    this.remoteUpdatedAt,
    this.errorMessage,
  });

  final FeaturedLiveEventsPayload payload;
  final FeaturedLiveEventsSource source;
  final String? remoteUpdatedAt;
  final String? errorMessage;

  bool get isFromAppwrite => source == FeaturedLiveEventsSource.appwrite;

  int get totalChannelLinks => payload.events.fold<int>(
        0,
        (n, e) => n + e.relatedChannels.length,
      );
}

/// Appwrite `app_config` / `featured_live_events` → home featured match cards.
class FeaturedLiveEventsService {
  FeaturedLiveEventsService._();
  static final FeaturedLiveEventsService instance =
      FeaturedLiveEventsService._();

  static const _githubEventsUrl =
      'https://raw.githubusercontent.com/kakonzone/lumio-config/main/featured_live_events.json';
  static const _assetPath = 'assets/data/featured_live_events.json';

  /// True when Appwrite row changed or cache missing / [forceRefresh].
  @visibleForTesting
  static bool shouldFetchAppwritePayload({
    required bool forceRefresh,
    String? remoteUpdatedAt,
    String? cachedUpdatedAt,
    bool cacheHit = false,
  }) {
    if (forceRefresh) return true;
    if (!cacheHit) return true;
    final remote = remoteUpdatedAt?.trim() ?? '';
    final cached = cachedUpdatedAt?.trim() ?? '';
    if (remote.isEmpty) return false;
    return remote != cached;
  }

  Future<FeaturedLiveEventsPayload?> _fetchFromGitHub() async {
    try {
      final uri = Uri.parse(_githubEventsUrl);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final payload = FeaturedLiveEventsPayload.fromJson(map);
      if (payload.events.isEmpty) return null;
      if (kDebugMode) {
        debugPrint('[FeaturedLiveEvents] GitHub fetch ok '
            'events=${payload.events.length}');
      }
      return payload;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeaturedLiveEvents] GitHub fetch failed: $e');
      }
      return null;
    }
  }

  Future<FeaturedLiveEventsLoadResult> load({bool forceRefresh = false}) async {
    // 1. Try GitHub raw JSON first (fast, no auth needed)
    if (forceRefresh || true) {
      final githubPayload = await _fetchFromGitHub();
      if (githubPayload != null) {
        await FeaturedLiveEventsCache.instance.write(
          githubPayload,
          remoteUpdatedAt: DateTime.now().toIso8601String(),
        );
        return FeaturedLiveEventsLoadResult(
          payload: githubPayload,
          source: FeaturedLiveEventsSource.appwrite, // reuse enum value
          remoteUpdatedAt: DateTime.now().toIso8601String(),
        );
      }
    }

    // 2. Check disk cache
    if (!forceRefresh) {
      final cached = await FeaturedLiveEventsCache.instance.read();
      if (cached != null && cached.events.isNotEmpty) {
        return FeaturedLiveEventsLoadResult(
          payload: cached,
          source: FeaturedLiveEventsSource.cache,
        );
      }
    }

    // 3. Fallback: Appwrite (if configured)
    if (AppwriteConfig.isConfigured) {
      return load_appwrite(forceRefresh: forceRefresh);
    }

    // 4. Final fallback: bundled asset
    return _loadWithoutAppwrite(forceRefresh: forceRefresh);
  }

  Future<FeaturedLiveEventsLoadResult> load_appwrite(
      {bool forceRefresh = false}) async {
    if (!AppwriteConfig.isConfigured) {
      return _loadWithoutAppwrite(forceRefresh: forceRefresh);
    }

    AppConfigEntry entry;
    try {
      final fetched = await AppwriteAppConfig.instance.fetchEntry(
        AppwriteConfig.featuredLiveEventsKey,
      );
      entry = fetched ??
          const AppConfigEntry(
            errorMessage: 'Appwrite app_config fetch returned null',
          );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[FeaturedLiveEvents] fetch exception: $e\n$st');
      }
      return _fallbackAfterAppwriteMiss(
        forceRefresh: forceRefresh,
        errorMessage: e.toString(),
      );
    }

    if (entry.payload == null &&
        entry.errorMessage != null &&
        entry.errorMessage!.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[FeaturedLiveEvents] Appwrite error: ${entry.errorMessage}',
        );
      }
      return _fallbackAfterAppwriteMiss(
        forceRefresh: forceRefresh,
        errorMessage: entry.errorMessage,
      );
    }

    final remoteUpdatedAt = entry.updatedAt;
    final cachedUpdatedAt =
        await FeaturedLiveEventsCache.instance.readRemoteUpdatedAt();
    final cached =
        !forceRefresh ? await FeaturedLiveEventsCache.instance.read() : null;

    final useRemotePayload = entry.payload != null &&
        shouldFetchAppwritePayload(
          forceRefresh: forceRefresh,
          remoteUpdatedAt: remoteUpdatedAt,
          cachedUpdatedAt: cachedUpdatedAt,
          cacheHit: cached != null && cached.events.isNotEmpty,
        );

    if (useRemotePayload && entry.payload != null) {
      final payload = FeaturedLiveEventsPayload.fromJson(entry.payload!);
      if (payload.events.isNotEmpty) {
        await FeaturedLiveEventsCache.instance.write(
          payload,
          remoteUpdatedAt: remoteUpdatedAt,
        );
        _logLoaded(
          source: FeaturedLiveEventsSource.appwrite,
          payload: payload,
          remoteUpdatedAt: remoteUpdatedAt,
        );
        return FeaturedLiveEventsLoadResult(
          payload: payload,
          source: FeaturedLiveEventsSource.appwrite,
          remoteUpdatedAt: remoteUpdatedAt,
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[FeaturedLiveEvents] Appwrite row ok but 0 valid events '
          '(check teamA/teamB/channels[].url in json_payload)',
        );
      }
    }

    if (cached != null && cached.events.isNotEmpty) {
      _logLoaded(
        source: FeaturedLiveEventsSource.cache,
        payload: cached,
        remoteUpdatedAt: cachedUpdatedAt,
      );
      return FeaturedLiveEventsLoadResult(
        payload: cached,
        source: FeaturedLiveEventsSource.cache,
        remoteUpdatedAt: cachedUpdatedAt,
        errorMessage: entry.payload == null
            ? 'Appwrite app_config row missing or invalid json_payload'
            : null,
      );
    }

    return _fallbackAfterAppwriteMiss(
      forceRefresh: forceRefresh,
      errorMessage: entry.payload == null
          ? 'Create app_config row key=${AppwriteConfig.featuredLiveEventsKey} '
              'with json_payload (see docs/APPWRITE_WORLD_CUP_CARDS.md)'
          : 'No valid events in json_payload (need teamA, teamB, channels[].url)',
    );
  }

  Future<FeaturedLiveEventsLoadResult> _fallbackAfterAppwriteMiss({
    required bool forceRefresh,
    String? errorMessage,
  }) async {
    final stale = await FeaturedLiveEventsCache.instance.read(ignoreTtl: true);
    if (stale != null && stale.events.isNotEmpty) {
      _logLoaded(
        source: FeaturedLiveEventsSource.cache,
        payload: stale,
      );
      return FeaturedLiveEventsLoadResult(
        payload: stale,
        source: FeaturedLiveEventsSource.cache,
        errorMessage: errorMessage,
      );
    }

    if (kDebugMode) {
      try {
        final assetBody = await rootBundle.loadString(_assetPath);
        final payload = FeaturedLiveEventsPayload.fromJson(
          jsonDecode(assetBody) as Map<String, dynamic>,
        );
        if (payload.events.isNotEmpty) {
          _logLoaded(
            source: FeaturedLiveEventsSource.bundledAsset,
            payload: payload,
          );
          return FeaturedLiveEventsLoadResult(
            payload: payload,
            source: FeaturedLiveEventsSource.bundledAsset,
            errorMessage: errorMessage,
          );
        }
      } catch (_) {}
    }

    return FeaturedLiveEventsLoadResult(
      payload: const FeaturedLiveEventsPayload(),
      source: FeaturedLiveEventsSource.empty,
      errorMessage: errorMessage,
    );
  }

  Future<FeaturedLiveEventsLoadResult> _loadWithoutAppwrite({
    required bool forceRefresh,
  }) async {
    if (!forceRefresh) {
      final cached = await FeaturedLiveEventsCache.instance.read();
      if (cached != null && cached.events.isNotEmpty) {
        return FeaturedLiveEventsLoadResult(
          payload: cached,
          source: FeaturedLiveEventsSource.cache,
        );
      }
    }

    // Always try bundled asset as fallback when cache is empty (not just debug mode)
    try {
      final assetBody = await rootBundle.loadString(_assetPath);
      final payload = FeaturedLiveEventsPayload.fromJson(
        jsonDecode(assetBody) as Map<String, dynamic>,
      );
      if (payload.events.isNotEmpty) {
        _logLoaded(
          source: FeaturedLiveEventsSource.bundledAsset,
          payload: payload,
        );
        return FeaturedLiveEventsLoadResult(
          payload: payload,
          source: FeaturedLiveEventsSource.bundledAsset,
          errorMessage: 'Appwrite not configured - using bundled asset',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FeaturedLiveEvents] bundled asset load error: $e');
      }
    }
    return const FeaturedLiveEventsLoadResult(
      payload: const FeaturedLiveEventsPayload(),
      source: FeaturedLiveEventsSource.empty,
      errorMessage: 'Appwrite not configured and no valid bundled asset',
    );
  }

  void _logLoaded({
    required FeaturedLiveEventsSource source,
    required FeaturedLiveEventsPayload payload,
    String? remoteUpdatedAt,
  }) {
    if (!kDebugMode) return;
    final links = payload.events.fold<int>(
      0,
      (n, e) => n + e.relatedChannels.length,
    );
    debugPrint(
      '[FeaturedLiveEvents] source=$source events=${payload.events.length} '
      'channelLinks=$links updated_at=${remoteUpdatedAt ?? "—"}',
    );
  }
}

class FeaturedLiveEventsPayload {
  const FeaturedLiveEventsPayload({
    this.sectionTitle = 'World Cup 2026',
    this.sectionSubtitle = '',
    this.maxCards = 3,
    this.events = const [],
  });

  final String sectionTitle;
  final String sectionSubtitle;
  final int maxCards;
  final List<LiveEventMatch> events;

  factory FeaturedLiveEventsPayload.fromJson(Map<String, dynamic> json) {
    final maxCards = ((json['maxCards'] as num?)?.toInt() ?? 3).clamp(1, 3);
    final events = <LiveEventMatch>[];
    final rawEvents = json['events'];
    if (rawEvents is List) {
      for (final item in rawEvents) {
        if (events.length >= maxCards) break;
        if (item is! Map) continue;
        final event = _parseEvent(Map<String, dynamic>.from(item));
        if (event != null) events.add(event);
      }
    }

    return FeaturedLiveEventsPayload(
      sectionTitle: (json['sectionTitle'] as String?)?.trim().isNotEmpty == true
          ? (json['sectionTitle'] as String).trim()
          : 'World Cup 2026',
      sectionSubtitle: (json['sectionSubtitle'] as String?)?.trim() ?? '',
      maxCards: maxCards,
      events: events,
    );
  }

  Map<String, dynamic> toJson() => {
        'sectionTitle': sectionTitle,
        'sectionSubtitle': sectionSubtitle,
        'maxCards': maxCards,
        'events': events
            .map(
              (e) => {
                ...e.match.toJson(),
                'tournament': e.match.channel,
                'channels': e.relatedChannels
                    .map(
                      (c) => {
                        'name': c.name,
                        'url': c.streamUrl,
                        if (c.alternateStreams.isNotEmpty)
                          'alternateStreams': c.alternateStreams
                              .map(
                                (a) => {
                                  'url': a.url,
                                  'label': a.label,
                                },
                              )
                              .toList(),
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
      };
}

LiveEventMatch? _parseEvent(Map<String, dynamic> j) {
  final id = (j['id'] as String?)?.trim();
  if (id == null || id.isEmpty) return null;

  final teamA = (j['teamA'] as String?)?.trim();
  final teamB = (j['teamB'] as String?)?.trim();
  if (teamA == null || teamA.isEmpty || teamB == null || teamB.isEmpty) {
    return null;
  }

  final related = <ChannelModel>[];
  final channels = j['channels'];
  if (channels is List) {
    for (var i = 0; i < channels.length; i++) {
      final item = channels[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url = _readChannelUrl(map);
      if (url.isEmpty) continue;
      final name = (map['name'] as String?)?.trim();
      final alts = <StreamLink>[];
      final altRaw = map['alternateStreams'] ?? map['alternate_streams'];
      if (altRaw is List) {
        for (final alt in altRaw) {
          if (alt is! Map) continue;
          final altMap = Map<String, dynamic>.from(alt);
          final altUrl = _readChannelUrl(altMap);
          if (altUrl.isEmpty) continue;
          alts.add(
            StreamLink(
              url: altUrl,
              label: (altMap['label'] as String?)?.trim().isNotEmpty == true
                  ? (altMap['label'] as String).trim()
                  : 'Link ${alts.length + 2}',
            ),
          );
        }
      }
      related.add(
        ChannelModel(
          id: 'featured_${id}_$i',
          name: name?.isNotEmpty == true ? name! : 'Channel ${i + 1}',
          category: 'Sports',
          country: '',
          streamUrl: url,
          isLive: true,
          alternateStreams: alts,
        ),
      );
    }
  }

  final match = MatchModel(
    id: id,
    sport: (j['sport'] as String?)?.trim().isNotEmpty == true
        ? (j['sport'] as String).trim()
        : 'football',
    teamA: teamA,
    teamB: teamB,
    scoreA: (j['scoreA'] as String?)?.trim() ?? '',
    scoreB: (j['scoreB'] as String?)?.trim() ?? '',
    status: (j['status'] as String?)?.trim().isNotEmpty == true
        ? (j['status'] as String).trim().toLowerCase()
        : 'live',
    time: (j['time'] as String?)?.trim() ?? '',
    channel: (j['tournament'] as String?)?.trim().isNotEmpty == true
        ? (j['tournament'] as String).trim()
        : ((j['channel'] as String?)?.trim().isNotEmpty == true
            ? (j['channel'] as String).trim()
            : 'FIFA World Cup 2026'),
    streamUrl: '',
    matchDate: DateTime.tryParse(j['matchDate'] as String? ?? '') ??
        DateTime.now().toUtc(),
    teamALogo: (j['teamALogo'] as String?)?.trim() ?? '',
    teamBLogo: (j['teamBLogo'] as String?)?.trim() ?? '',
  );

  return LiveEventMatch(match: match, relatedChannels: related);
}

/// Accepts url / streamUrl / stream_url / link from Appwrite JSON.
@visibleForTesting
String readFeaturedChannelUrl(Map<String, dynamic> map) => _readChannelUrl(map);

String _readChannelUrl(Map<String, dynamic> map) {
  for (final key in ['url', 'streamUrl', 'stream_url', 'link', 'm3u8']) {
    final v = map[key];
    if (v == null) continue;
    final text = v.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}
