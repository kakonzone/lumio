import '../models/live_event_match.dart';
import '../models/model.dart';

/// Merges FootyStream + ESPN/Cricbuzz rows when teams & day match.
class ScheduleMerge {
  ScheduleMerge._();

  /// Dedupe [sources] in order — earlier lists win on conflicts unless ESPN has scores/live.
  static List<MatchModel> mergeMatches(List<List<MatchModel>> sources) {
    final out = <MatchModel>[];
    final index = <String, int>{};

    for (final list in sources) {
      for (final m in list) {
        final existing = _findExistingIndex(out, m);
        if (existing == null) {
          final key = _matchKey(m);
          if (key.isNotEmpty) index[key] = out.length;
          out.add(m);
        } else {
          out[existing] = _mergeMatch(out[existing], m);
          final key = _matchKey(out[existing]);
          if (key.isNotEmpty) index[key] = existing;
        }
      }
    }
    return out;
  }

  /// Merge live-event rows (union related channels, single match card).
  static List<LiveEventMatch> mergeLiveEvents(List<LiveEventMatch> events) {
    final out = <LiveEventMatch>[];
    final index = <String, int>{};

    for (final e in events) {
      final existing = _findExistingIndex(
        out.map((x) => x.match).toList(),
        e.match,
      );
      if (existing == null) {
        final key = _matchKey(e.match);
        if (key.isNotEmpty) index[key] = out.length;
        out.add(e);
      } else {
        out[existing] = _mergeLiveEvent(out[existing], e);
      }
    }
    return out;
  }

  static LiveEventMatch _mergeLiveEvent(LiveEventMatch a, LiveEventMatch b) {
    final merged = _mergeMatch(a.match, b.match);
    final channels = <String, ChannelModel>{};
    for (final c in [...a.relatedChannels, ...b.relatedChannels]) {
      channels[c.id] = c;
    }
    return LiveEventMatch(
      match: merged,
      relatedChannels: channels.values.toList(),
    );
  }

  static MatchModel _mergeMatch(MatchModel primary, MatchModel other) {
    final live =
        primary.status == 'live' || other.status == 'live';
    final finished =
        !live && (primary.status == 'finished' || other.status == 'finished');

    String status;
    if (live) {
      status = 'live';
    } else if (finished) {
      status = 'finished';
    } else {
      status = primary.status == 'upcoming' || other.status == 'upcoming'
          ? 'upcoming'
          : primary.status;
    }

    final scoreA = _preferNonEmpty(primary.scoreA, other.scoreA);
    final scoreB = _preferNonEmpty(primary.scoreB, other.scoreB);
    final time = live
        ? _preferNonEmpty(other.time, primary.time, fallback: 'LIVE')
        : _preferNonEmpty(primary.time, other.time, fallback: other.time);

    return MatchModel(
      id: primary.id.startsWith('footystream_') ? primary.id : other.id,
      sport: _preferNonEmpty(primary.sport, other.sport, fallback: 'Football'),
      teamA: primary.teamA,
      teamB: primary.teamB,
      scoreA: scoreA,
      scoreB: scoreB,
      status: status,
      time: time,
      channel: _preferChannel(primary, other),
      streamUrl: _preferNonEmpty(primary.streamUrl, other.streamUrl),
      matchDate: primary.matchDate,
      scoreSource: _joinSources(primary.scoreSource, other.scoreSource),
      teamALogo: _preferNonEmpty(primary.teamALogo, other.teamALogo),
      teamBLogo: _preferNonEmpty(primary.teamBLogo, other.teamBLogo),
    );
  }

  static String _preferChannel(MatchModel a, MatchModel b) {
    final aEspn = _isScoreProvider(a.scoreSource);
    final bEspn = _isScoreProvider(b.scoreSource);
    if (aEspn && !bEspn) return a.channel;
    if (bEspn && !aEspn) return b.channel;
    return a.channel.isNotEmpty ? a.channel : b.channel;
  }

  static bool _isScoreProvider(String source) {
    final s = source.toLowerCase();
    return s.contains('espn') || s.contains('cricbuzz');
  }

  static String _joinSources(String a, String b) {
    final parts = <String>{};
    for (final raw in '$a·$b'.split(RegExp(r'[·|,]'))) {
      final t = raw.trim();
      if (t.isNotEmpty) parts.add(t);
    }
    return parts.join(' · ');
  }

  static String _preferNonEmpty(
    String a,
    String b, {
    String fallback = '',
  }) {
    if (a.trim().isNotEmpty) return a;
    if (b.trim().isNotEmpty) return b;
    return fallback;
  }

  static int? _findExistingIndex(List<MatchModel> out, MatchModel m) {
    for (var i = 0; i < out.length; i++) {
      if (_sameFixture(out[i], m)) return i;
    }
    return null;
  }

  static bool _sameFixture(MatchModel a, MatchModel b) {
    if (!_sameDay(a.matchDate, b.matchDate)) return false;
    final keyA = _matchKey(a);
    final keyB = _matchKey(b);
    if (keyA.isNotEmpty && keyA == keyB) return true;
    return _teamsOverlap(a, b);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year &&
        la.month == lb.month &&
        la.day == lb.day;
  }

  static bool _teamsOverlap(MatchModel a, MatchModel b) {
    final ta = _teamTokens(a.teamA);
    final tb = _teamTokens(a.teamB);
    final ua = _teamTokens(b.teamA);
    final ub = _teamTokens(b.teamB);
    if (ta.isEmpty || tb.isEmpty || ua.isEmpty || ub.isEmpty) {
      return false;
    }
    final matchAB = _tokenPairMatches(ta, ua) && _tokenPairMatches(tb, ub);
    final matchAC = _tokenPairMatches(ta, ub) && _tokenPairMatches(tb, ua);
    return matchAB || matchAC;
  }

  static bool _tokenPairMatches(Set<String> left, Set<String> right) {
    for (final l in left) {
      if (!right.any((r) => _tokensSimilar(l, r))) return false;
    }
    return true;
  }

  static bool _tokensSimilar(String a, String b) {
    if (a == b) return true;
    if (a.length >= 3 && b.length >= 3) {
      return a.startsWith(b) ||
          b.startsWith(a) ||
          a.contains(b) ||
          b.contains(a);
    }
    return false;
  }

  static Set<String> _teamTokens(String name) {
    final n = _normalizeTeam(name);
    if (n.isEmpty) return {};
    final parts = n.split(' ').where((p) => p.length >= 2).toSet();
    if (n.length <= 4) parts.add(n);
    return parts;
  }

  static String _matchKey(MatchModel m) {
    final a = _normalizeTeam(m.teamA);
    final b = _normalizeTeam(m.teamB);
    if (a.isEmpty && b.isEmpty) return '';
    final pair = [if (a.isNotEmpty) a, if (b.isNotEmpty) b]..sort();
    final d = m.matchDate.toLocal();
    final day = '${d.year}-${d.month}-${d.day}';
    return '${pair.join('|')}|$day';
  }

  static String _normalizeTeam(String name) {
    var s = name.toLowerCase().trim();
    if (s.isEmpty) return '';
    const aliases = {
      'turkiye': 'turkey',
      'cote d ivoire': 'ivory coast',
      'usa': 'united states',
      'u s a': 'united states',
    };
    for (final e in aliases.entries) {
      if (s.contains(e.key)) s = e.value;
    }
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    s = s.replaceAll(RegExp(r'\b(fc|cf|sc|afc)\b'), '');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
