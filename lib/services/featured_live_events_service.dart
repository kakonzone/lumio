import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/special_link_config.dart';
import '../models/live_event_match.dart';
import '../models/model.dart';
import 'featured_live_events_cache.dart';
import 'special_link/github_raw_url.dart';

/// GitHub JSON → up to 3 home featured cards (same UI as All Live Events).
class FeaturedLiveEventsService {
  FeaturedLiveEventsService._();
  static final FeaturedLiveEventsService instance =
      FeaturedLiveEventsService._();

  static const _assetPath = 'assets/data/featured_live_events.json';

  Future<FeaturedLiveEventsPayload> load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await FeaturedLiveEventsCache.instance.read();
      if (cached != null && cached.events.isNotEmpty) return cached;
    }

    try {
      final rawUrl = GithubRawUrl.resolve(
        SpecialLinkConfig.featuredLiveEventsUrl,
      );
      final res = await http
          .get(Uri.parse(rawUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final payload = _parseJson(res.body);
        if (payload.events.isNotEmpty) {
          await FeaturedLiveEventsCache.instance.write(payload);
          return payload;
        }
      }
    } catch (_) {}

    final stale = await FeaturedLiveEventsCache.instance.read(ignoreTtl: true);
    if (stale != null && stale.events.isNotEmpty) return stale;

    try {
      final assetBody = await rootBundle.loadString(_assetPath);
      return _parseJson(assetBody);
    } catch (_) {
      return const FeaturedLiveEventsPayload();
    }
  }

  FeaturedLiveEventsPayload _parseJson(String body) {
    final root = jsonDecode(body);
    if (root is! Map<String, dynamic>) {
      return const FeaturedLiveEventsPayload();
    }
    return FeaturedLiveEventsPayload.fromJson(root);
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
      sectionTitle:
          (json['sectionTitle'] as String?)?.trim().isNotEmpty == true
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
  if (teamA == null ||
      teamA.isEmpty ||
      teamB == null ||
      teamB.isEmpty) {
    return null;
  }

  final related = <ChannelModel>[];
  final channels = j['channels'];
  if (channels is List) {
    for (var i = 0; i < channels.length; i++) {
      final item = channels[i];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final url =
          (map['url'] as String? ?? map['streamUrl'] as String? ?? '').trim();
      if (url.isEmpty) continue;
      final name = (map['name'] as String?)?.trim();
      final alts = <StreamLink>[];
      final altRaw = map['alternateStreams'];
      if (altRaw is List) {
        for (final alt in altRaw) {
          if (alt is! Map) continue;
          final altMap = Map<String, dynamic>.from(alt);
          final altUrl = (altMap['url'] as String?)?.trim() ?? '';
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
