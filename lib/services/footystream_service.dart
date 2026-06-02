import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/model.dart';

/// Schedules from [FootyStream](https://footystream.pk) — /pk (live hub) and /today.
class FootyStreamService {
  FootyStreamService._();

  static const pkUrl = 'https://footystream.pk/pk';
  static const todayUrl = 'https://footystream.pk/today';

  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0 Mobile Safari/537.36';

  static List<MatchModel>? _pkCache;
  static List<MatchModel>? _todayCache;
  static DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 4);

  static void clearCache() {
    _pkCache = null;
    _todayCache = null;
    _cacheAt = null;
  }

  /// Live hub + schedule (Pakistan landing).
  static Future<List<MatchModel>> fetchPk({bool force = false}) async {
    if (!force &&
        _pkCache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _pkCache!;
    }
    final html = await _getHtml(pkUrl);
    if (html == null) return _pkCache ?? [];
    _pkCache = parseEventsHtml(html, pageLabel: 'pk');
    _cacheAt = DateTime.now();
    return _pkCache!;
  }

  /// Today's full schedule.
  static Future<List<MatchModel>> fetchToday({bool force = false}) async {
    if (!force &&
        _todayCache != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl) {
      return _todayCache!;
    }
    final html = await _getHtml(todayUrl);
    if (html == null) return _todayCache ?? [];
    _todayCache = parseEventsHtml(html, pageLabel: 'today');
    _cacheAt = DateTime.now();
    return _todayCache!;
  }

  static Future<String?> _getHtml(String url) async {
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': _ua,
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'en',
            },
          )
          .timeout(const Duration(seconds: 14));
      if (res.statusCode != 200) return null;
      return res.body;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static List<MatchModel> parseEventsHtml(
    String html, {
    String pageLabel = 'pk',
  }) {
    final leagueAt = <int, String>{};
    for (final m in RegExp(
      r'<div class="text-white font-semibold text-sm[^"]*">([^<]+)</div>',
    ).allMatches(html)) {
      final label = m.group(1)!.trim();
      if (label.isEmpty ||
          label == 'Top Leagues' ||
          label == 'Top teams' ||
          label == 'Live Now') {
        continue;
      }
      leagueAt[m.start] = label;
    }

    String leagueFor(int pos) {
      var league = 'Football';
      for (final e in leagueAt.entries) {
        if (e.key <= pos) league = e.value;
      }
      return league;
    }

    final out = <MatchModel>[];
    final seen = <String>{};

    final eventRe = RegExp(
      r'<a href="(https://footystream\.pk/events/[^"]+)"[^>]*>([\s\S]*?)</a>',
    );

    for (final m in eventRe.allMatches(html)) {
      final url = m.group(1)!;
      final block = m.group(2)!;
      final slug = url.split('/').last;
      final id = 'footystream_${pageLabel}_$slug';
      if (seen.contains(id)) continue;
      seen.add(id);

      final league = leagueFor(m.start);
      final sport = _sportFromLeague(league);

      final startRaw =
          RegExp(r'data-start="([^"]+)"').firstMatch(block)?.group(1);
      final endRaw = RegExp(r'data-end="([^"]+)"').firstMatch(block)?.group(1);
      final start = startRaw != null ? DateTime.tryParse(startRaw) : null;
      final end = endRaw != null ? DateTime.tryParse(endRaw) : null;

      final teams = <String>[];
      final logos = <String>[];
      for (final tm in RegExp(
        r'src="(https://cdn\.img4every1\.org/team/[^"]+)"[^>]*alt="([^"]+)"',
      ).allMatches(block)) {
        logos.add(tm.group(1)!);
        teams.add(tm.group(2)!.trim());
      }

      final titleFromSlug = _titleFromSlug(slug);
      late final String teamA;
      late final String teamB;
      if (teams.length >= 2) {
        teamA = teams[0];
        teamB = teams[1];
      } else if (teams.length == 1) {
        teamA = teams[0];
        teamB = titleFromSlug.contains(' vs ')
            ? titleFromSlug.split(' vs ').last
            : 'Live';
      } else {
        final parts = titleFromSlug.split(' vs ');
        teamA = parts.first;
        teamB = parts.length > 1 ? parts.sublist(1).join(' vs ') : 'Event';
      }

      final liveBar = block.contains('bg-orange-500') ||
          block.contains('bg-red-500') ||
          block.contains('bg-green-500');
      final status = _statusFromTimes(start, end, forceLive: liveBar);
      final timeLabel = _timeLabel(start, end, status);

      out.add(
        MatchModel(
          id: id,
          sport: sport,
          teamA: teamA,
          teamB: teamB,
          status: status,
          time: timeLabel,
          channel: league,
          matchDate: start?.toLocal() ?? DateTime.now(),
          scoreSource: 'FootyStream',
          teamALogo: logos.isNotEmpty ? logos[0] : '',
          teamBLogo: logos.length > 1 ? logos[1] : '',
        ),
      );
    }

    out.sort((a, b) {
      final liveA = a.status == 'live' ? 0 : 1;
      final liveB = b.status == 'live' ? 0 : 1;
      if (liveA != liveB) return liveA.compareTo(liveB);
      return a.matchDate.compareTo(b.matchDate);
    });
    return out;
  }

  static String _titleFromSlug(String slug) {
    return slug
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ')
        .replaceAll('Vs', 'vs');
  }

  static String _sportFromLeague(String league) {
    final l = league.toLowerCase();
    if (l.contains('cricket')) return 'Cricket';
    if (l.contains('mlb') || l.contains('baseball')) return 'Baseball';
    if (l.contains('nba') || l.contains('basketball')) return 'Basketball';
    if (l.contains('nfl') || l.contains('american football')) {
      return 'American Football';
    }
    if (l.contains('formula') || l.contains('f1')) return 'Formula 1';
    if (l.contains('moto')) return 'MotoGP';
    if (l.contains('ufc') || l.contains('boxing')) return 'Combat';
    if (l.contains('roland') ||
        l.contains('atp') ||
        l.contains('tennis')) {
      return 'Tennis';
    }
    if (l.contains('rugby')) return 'Rugby';
    return 'Football';
  }

  static String _statusFromTimes(
    DateTime? start,
    DateTime? end, {
    bool forceLive = false,
  }) {
    if (forceLive) return 'live';
    final now = DateTime.now().toUtc();
    if (start != null && end != null) {
      final s = start.toUtc();
      final e = end.toUtc();
      if (now.isAfter(s) && now.isBefore(e)) return 'live';
      if (now.isAfter(e)) return 'finished';
    }
    if (start != null && now.isBefore(start.toUtc())) return 'upcoming';
    return 'upcoming';
  }

  static String _timeLabel(DateTime? start, DateTime? end, String status) {
    if (status == 'live') return 'LIVE';
    if (start == null) return 'Scheduled';
    final local = start.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }
}
