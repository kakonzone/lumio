import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/model.dart';
import '../utils/app_logger.dart';

/// Tournament-grouped scoreboards (ESPN soccer + Cricbuzz live).
class ScoreTournamentGroup {
  final String tournament;
  final List<MatchModel> matches;

  const ScoreTournamentGroup({
    required this.tournament,
    required this.matches,
  });
}

class ScoreService {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0.0.0';

  static List<ScoreTournamentGroup>? _boardsCache;
  static DateTime? _boardsCacheAt;
  static const _cacheTtl = Duration(minutes: 3);
  static const _requestTimeout = Duration(seconds: 8);
  static const _maxRetries = 3;

  static void clearCache() {
    _boardsCache = null;
    _boardsCacheAt = null;
  }

  /// HTTP request with retry and timeout
  static Future<http.Response> _fetchWithRetry(
    String url, {
    Map<String, String>? headers,
    int retries = _maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < retries) {
      try {
        return await http
            .get(Uri.parse(url), headers: headers)
            .timeout(_requestTimeout);
      } on SocketException catch (e) {
        attempt++;
        if (attempt >= retries) rethrow;
        AppLogger.warning('Network error, retry $attempt/$retries: $e', subsystem: 'ScoreService');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      } on HttpException catch (e) {
        attempt++;
        if (attempt >= retries) rethrow;
        AppLogger.warning('HTTP error, retry $attempt/$retries: $e', subsystem: 'ScoreService');
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        rethrow;
      }
    }

    throw Exception('Max retries exceeded');
  }

  static const _espnSoccerBoards = <String, String>{
    'FIFA World Cup':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/fifa.world/scoreboard',
    'Premier League':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard',
    'UEFA Champions League':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.champions/scoreboard',
    'La Liga':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/scoreboard',
    'UEFA Euro':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/uefa.euro/scoreboard',
    'Copa América':
        'https://site.api.espn.com/apis/site/v2/sports/soccer/conmebol.america/scoreboard',
  };

  static Future<List<MatchModel>> fetchLiveScores() async {
    final groups = await fetchTodayScoreboards();
    return groups.expand((g) => g.matches).toList();
  }

  /// All today's football from ESPN scoreboards (parallel).
  static Future<List<MatchModel>> fetchFootballToday() async {
    final groups = await _fetchAllEspnSoccer();
    return groups.expand((g) => g.matches).toList();
  }

  /// Live cricket from Cricbuzz RapidAPI.
  static Future<List<MatchModel>> fetchCricketLive() async {
    final groups = await _fetchCricbuzzRapidLive();
    return groups.expand((g) => g.matches).toList();
  }

  static String _espnTeamLogo(Map<String, dynamic>? team) {
    if (team == null) return '';
    final logos = team['logos'] as List? ?? [];
    String? fallback;
    for (final raw in logos) {
      if (raw is! Map) continue;
      final href = raw['href'] as String? ?? '';
      if (!href.startsWith('http')) continue;
      final relList = raw['rel'];
      final rel = relList is List
          ? relList.map((e) => e.toString().toLowerCase()).join(' ')
          : '';
      if (rel.contains('full') ||
          rel.contains('default') ||
          rel.contains('primary')) {
        return href;
      }
      fallback ??= href;
    }
    if (fallback != null) return fallback;
    final direct = team['logo'] as String? ?? '';
    if (direct.startsWith('http')) return direct;
    return '';
  }

  static String _cricbuzzTeamLogo(dynamic teamRaw) {
    if (teamRaw is! Map) return '';
    final team = Map<String, dynamic>.from(teamRaw);
    for (final key in [
      'teamImageUrl',
      'imageUrl',
      'logo',
      'flag',
      'teamLogo',
      'image',
    ]) {
      final v = team[key];
      if (v is String && v.startsWith('http')) return v;
    }
    final id = team['teamId'] ?? team['id'] ?? team['imageId'];
    if (id != null) {
      return 'https://www.cricbuzz.com/a/img/v1/184/team_${id}_flag.png';
    }
    return '';
  }

  static DateTime _cricbuzzMatchDate(Map<String, dynamic> m) {
    for (final key in [
      'matchStartTimestamp',
      'startDate',
      'matchStartTime',
      'matchDate',
      'timestamp',
    ]) {
      final v = m[key];
      if (v is int && v > 0) {
        final ms = v < 10000000000 ? v * 1000 : v;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
      if (v is String && v.isNotEmpty) {
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed.toUtc();
      }
    }
    final team1 = m['team1'];
    if (team1 is Map) {
      final ts = team1['startDate'] ?? team1['matchStartTime'];
      if (ts is String) {
        final parsed = DateTime.tryParse(ts);
        if (parsed != null) return parsed.toUtc();
      }
    }
    return DateTime.now().toUtc();
  }

  static Future<List<ScoreTournamentGroup>> fetchTodayScoreboards({
    bool force = false,
  }) async {
    if (!force &&
        _boardsCache != null &&
        _boardsCacheAt != null &&
        DateTime.now().difference(_boardsCacheAt!) < _cacheTtl) {
      return _boardsCache!;
    }

    final results = await Future.wait([
      _fetchAllEspnSoccer(),
      _fetchCricbuzzRapidLive(),
    ]);

    final out = <ScoreTournamentGroup>[];
    for (final list in results) {
      out.addAll(list);
    }
    _boardsCache = out;
    _boardsCacheAt = DateTime.now();
    return out;
  }

  static Future<List<ScoreTournamentGroup>> _fetchAllEspnSoccer() async {
    final groups = await Future.wait(
      _espnSoccerBoards.entries.map(
        (e) => _fetchEspnSoccerGroup(e.key, e.value),
      ),
    );
    return groups.where((g) => g.matches.isNotEmpty).toList();
  }

  static Future<ScoreTournamentGroup> _fetchEspnSoccerGroup(
    String name,
    String url,
  ) async {
    try {
      final res = await _fetchWithRetry(url, headers: {'User-Agent': _ua});
      if (res.statusCode != 200) {
        if (kDebugMode) {
          AppLogger.warning('ESPN returned status ${res.statusCode}', subsystem: 'ScoreService');
        }
        return ScoreTournamentGroup(tournament: name, matches: const []);
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final matches = _parseEspnSoccerToday(data, name);
      return ScoreTournamentGroup(tournament: name, matches: matches);
    } on SocketException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('ESPN network error: $e', subsystem: 'ScoreService');
      }
      return ScoreTournamentGroup(tournament: name, matches: const []);
    } on HttpException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('ESPN HTTP error: $e', subsystem: 'ScoreService');
      }
      return ScoreTournamentGroup(tournament: name, matches: const []);
    } on FormatException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('ESPN parse error: $e', subsystem: 'ScoreService');
      }
      return ScoreTournamentGroup(tournament: name, matches: const []);
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('ESPN unknown error: $e', subsystem: 'ScoreService');
      }
      return ScoreTournamentGroup(tournament: name, matches: const []);
    }
  }

  static List<MatchModel> _parseEspnSoccerToday(
    Map<String, dynamic> data,
    String tournament,
  ) {
    final events = data['events'] as List? ?? [];
    final out = <MatchModel>[];

    for (final raw in events) {
      if (raw is! Map<String, dynamic>) continue;
      final eventDate = raw['date'] as String? ?? '';
      if (!_isToday(eventDate)) continue;

      final comps = raw['competitions'] as List? ?? [];
      if (comps.isEmpty) continue;
      final comp = comps.first as Map<String, dynamic>;
      final compDate = comp['date'] as String? ?? eventDate;
      if (!_isToday(compDate)) continue;

      final competitors = comp['competitors'] as List? ?? [];
      if (competitors.length < 2) continue;

      final home = competitors.firstWhere(
        (c) => (c as Map)['homeAway'] == 'home',
        orElse: () => competitors[0],
      ) as Map<String, dynamic>;
      final away = competitors.firstWhere(
        (c) => (c as Map)['homeAway'] == 'away',
        orElse: () => competitors[1],
      ) as Map<String, dynamic>;

      final statusMap = comp['status'] as Map<String, dynamic>? ?? {};
      final type = statusMap['type'] as Map<String, dynamic>? ?? {};
      final state = type['state'] as String? ?? '';
      final completed = type['completed'] == true;
      final isLive = state == 'in' || (state == 'post' && !completed);
      final isFinal = completed || state == 'post';

      final homeTeam = home['team'] as Map<String, dynamic>? ?? {};
      final awayTeam = away['team'] as Map<String, dynamic>? ?? {};

      final teamA = homeTeam['abbreviation'] as String? ??
          homeTeam['shortDisplayName'] as String? ??
          homeTeam['displayName'] as String? ??
          'Home';
      final teamB = awayTeam['abbreviation'] as String? ??
          awayTeam['shortDisplayName'] as String? ??
          awayTeam['displayName'] as String? ??
          'Away';

      final scoreA = _espnCompetitorScore(home);
      final scoreB = _espnCompetitorScore(away);
      final detail =
          type['shortDetail'] as String? ?? type['detail'] as String? ?? '';

      String status;
      String timeLabel;
      if (isLive) {
        status = 'live';
        timeLabel = detail.isNotEmpty ? detail : 'LIVE';
      } else if (isFinal) {
        status = 'finished';
        timeLabel = detail.isNotEmpty ? detail : 'Final';
      } else {
        status = 'upcoming';
        timeLabel = detail.isNotEmpty ? detail : _formatKickoff(compDate);
      }

      out.add(MatchModel(
        id: 'espn_${raw['id'] ?? '${teamA}_${teamB}_${out.length}'}',
        sport: 'Football',
        teamA: teamA,
        teamB: teamB,
        scoreA: isFinal || isLive ? scoreA : '',
        scoreB: isFinal || isLive ? scoreB : '',
        status: status,
        time: timeLabel,
        channel: tournament,
        scoreSource: 'ESPN',
        matchDate: DateTime.tryParse(compDate) ?? DateTime.now(),
        teamALogo: _espnTeamLogo(homeTeam),
        teamBLogo: _espnTeamLogo(awayTeam),
      ));
    }
    return out;
  }

  static Future<List<ScoreTournamentGroup>> _fetchCricbuzzRapidLive() async {
    if (kReleaseMode && !ApiConfig.hasCricbuzzKey) {
      throw StateError('CRICBUZZ_RAPID_API_KEY missing in release build');
    }
    try {
      final res = await _fetchWithRetry(
        'https://${ApiConfig.cricbuzzRapidApiHost}/matches/v1/live',
        headers: {
          'User-Agent': _ua,
          'x-rapidapi-host': ApiConfig.cricbuzzRapidApiHost,
          'x-rapidapi-key': ApiConfig.cricbuzzRapidApiKey,
        },
      );
      if (res.statusCode != 200) {
        if (kDebugMode) {
          AppLogger.warning('Cricbuzz returned status ${res.statusCode}', subsystem: 'ScoreService');
        }
        return [];
      }
      final data = jsonDecode(res.body);
      final matches = _parseCricbuzzRapid(data);
      if (matches.isEmpty) return [];
      return [
        ScoreTournamentGroup(
          tournament: 'Live Cricket',
          matches: matches,
        ),
      ];
    } on SocketException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('Cricbuzz network error: $e', subsystem: 'ScoreService');
      }
      return [];
    } on HttpException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('Cricbuzz HTTP error: $e', subsystem: 'ScoreService');
      }
      return [];
    } on FormatException catch (e) {
      if (kDebugMode) {
        AppLogger.warning('Cricbuzz parse error: $e', subsystem: 'ScoreService');
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        AppLogger.warning('Cricbuzz unknown error: $e', subsystem: 'ScoreService');
      }
      return [];
    }
  }

  static List<MatchModel> _parseCricbuzzRapid(dynamic data) {
    final out = <MatchModel>[];
    final typeMatches = _extractCricbuzzMatchMaps(data);
    for (final m in typeMatches) {
      final teamA = m['team1Name'] as String? ??
          (m['team1'] as Map?)?['teamName'] as String? ??
          m['team1'] as String? ??
          '';
      final teamB = m['team2Name'] as String? ??
          (m['team2'] as Map?)?['teamName'] as String? ??
          m['team2'] as String? ??
          '';
      if (teamA.isEmpty && teamB.isEmpty) continue;

      final state =
          (m['state'] as String? ?? m['status'] as String? ?? '').toLowerCase();
      final isLive =
          state.contains('live') || state.contains('play') || state == 'in';

      final scoreA = _cricbuzzTeamScore(m, isTeam1: true);
      final scoreB = _cricbuzzTeamScore(m, isTeam1: false);

      final overs = m['status'] as String? ?? m['matchDesc'] as String? ?? '';

      final team1Map = m['team1'];
      final team2Map = m['team2'];

      out.add(MatchModel(
        id: 'cricbuzz_${m['matchId'] ?? m['id'] ?? out.length}',
        sport: 'Cricket',
        teamA: teamA,
        teamB: teamB,
        scoreA: scoreA,
        scoreB: scoreB,
        status: isLive ? 'live' : 'upcoming',
        time: isLive ? (overs.isNotEmpty ? overs : 'LIVE') : overs,
        channel: 'Live Cricket',
        scoreSource: 'Cricbuzz',
        matchDate: _cricbuzzMatchDate(m),
        teamALogo: _cricbuzzTeamLogo(team1Map ?? m['team1']),
        teamBLogo: _cricbuzzTeamLogo(team2Map ?? m['team2']),
      ));
    }
    return out;
  }

  static List<Map<String, dynamic>> _extractCricbuzzMatchMaps(dynamic data) {
    final out = <Map<String, dynamic>>[];
    if (data is! Map) return out;

    void walk(dynamic node) {
      if (node is Map) {
        if (node.containsKey('team1Name') ||
            (node['team1'] is Map &&
                (node['team1'] as Map).containsKey('teamName'))) {
          out.add(Map<String, dynamic>.from(node));
          return;
        }
        for (final v in node.values) {
          walk(v);
          if (out.length >= 12) return;
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v);
          if (out.length >= 12) return;
        }
      }
    }

    walk(data);
    return out;
  }

  static String _espnCompetitorScore(Map<String, dynamic> competitor) {
    final raw = competitor['score'];
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is num) return raw.toString();
    if (raw is Map) {
      final display = raw['displayValue'] as String? ?? '';
      if (display.isNotEmpty) return display.trim();
      final value = raw['value'];
      if (value is num) return value.toString();
    }
    return '';
  }

  static String _cricbuzzTeamScore(
    Map<String, dynamic> m, {
    required bool isTeam1,
  }) {
    final key = isTeam1 ? 'team1' : 'team2';
    final direct =
        isTeam1 ? m['team1Score'] as String? : m['team2Score'] as String?;
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    final team = m[key];
    if (team is Map) {
      final score = team['teamScore'] ?? team['score'];
      if (score is String && score.trim().isNotEmpty) return score.trim();
      if (score is Map) {
        final runs = score['runs'] ?? score['r'];
        final wkts = score['wickets'] ?? score['w'];
        if (runs != null) {
          final r = runs.toString();
          final w = wkts?.toString();
          if (w != null && w.isNotEmpty && w != '0') return '$r/$w';
          return r;
        }
        final display = score['display'] ?? score['displayValue'];
        if (display != null) return display.toString();
      }
    }
    return '';
  }

  static bool _isToday(String iso) {
    if (iso.isEmpty) return true;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return true;
    final local = dt.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static String _formatKickoff(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Scheduled';
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
