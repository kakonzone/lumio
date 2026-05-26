import '../models/live_event_match.dart';
import '../models/model.dart';

/// Home / Live nav: men's cricket & football only; priority tournaments & teams.
class LiveEventPriority {
  LiveEventPriority._();

  // ── Cricket franchise / ICC events ─────────────────────────────────────
  static const _cricketTier0 = [
    'world cup',
    't20 world cup',
    'champions trophy',
    'icc world',
    'icc cricket world',
  ];

  static const _cricketTier1 = [
    'asia cup',
    'ipl',
    'indian premier league',
    'bpl',
    'bangladesh premier',
    'psl',
    'pakistan super',
    'cpl',
    'caribbean premier',
    't10',
    'abu dhabi t10',
    'sa20',
    'the hundred',
    'ilt20',
    'bbl',
    'big bash',
  ];

  static const _cricketTier2 = [
    'ashes',
    'wtc',
    'world test championship',
    'tri-series',
    'tri series',
    'bilateral',
    'odi series',
    't20i series',
    'test series',
  ];

  // ── Football: 2026 World Cup cycle + top leagues / clubs ───────────────
  static const _footballTier0 = [
    'world cup',
    'fifa world',
    'wc 2026',
    'world cup 2026',
    'world cup qualifier',
    'wc qualifier',
    'qualifier fifa',
  ];

  static const _footballTier1 = [
    'champions league',
    'uefa champions',
    'ucl',
    'el clasico',
    'la liga',
    'laliga',
    'premier league',
    'epl',
    'bundesliga',
    'serie a',
    'ligue 1',
    'copa del rey',
    'fa cup',
    'copa libertadores',
  ];

  static const _footballTier2Clubs = [
    'barcelona',
    'barça',
    'barca',
    'psg',
    'paris saint',
    'manchester city',
    'man city',
    'man. city',
    'real madrid',
    'bayern',
    'liverpool',
    'arsenal',
    'chelsea',
    'manchester united',
    'man united',
    'man utd',
    'juventus',
    'inter milan',
    'ac milan',
    'atletico',
    'dortmund',
  ];

  /// Nations prioritized (2026 WC cycle + Bangladesh men's team).
  static const _priorityNations = [
    'brazil',
    'argentina',
    'bangladesh',
    'germany',
    'france',
    'england',
    'spain',
    'croatia',
    'portugal',
    'netherlands',
    'belgium',
    'italy',
    'uruguay',
    'colombia',
    'mexico',
    'usa',
    'united states',
    'canada',
    'japan',
    'south korea',
    'korea republic',
    'saudi arabia',
    'australia',
    'morocco',
    'senegal',
    'switzerland',
    'denmark',
    'poland',
    'austria',
    'turkey',
    'ukraine',
    'scotland',
    'wales',
    'ireland',
    'ecuador',
    'paraguay',
    'chile',
    'peru',
    'nigeria',
    'ghana',
    'cameroon',
    'tunisia',
    'algeria',
    'egypt',
    'iran',
    'qatar',
    'india',
    'pakistan',
  ];

  static const _excludeBlob = [
    'women',
    "women's",
    'womens',
    ' wpl',
    'female',
    'u19',
    'u-19',
    'u21',
    'u-21',
    'u23',
    'u-23',
    'youth',
    'reserve',
    'friendly u',
    'legends',
    'golf',
    'rugby',
    'nba',
    'nfl',
    'mlb',
    'nhl',
    'tennis',
    'f1',
    'formula 1',
    'motogp',
    'wwe',
    'esports',
    'e-sports',
  ];

  static String _blob(MatchModel m) {
    return '${m.channel} ${m.time} ${m.teamA} ${m.teamB} ${m.sport}'
        .toLowerCase();
  }

  static bool isMensCricketOrFootball(MatchModel m) {
    final sport = m.sport.toLowerCase();
    if (sport != 'cricket' && sport != 'football') return false;
    final b = _blob(m);
    if (_excludeBlob.any(b.contains)) return false;
    return true;
  }

  /// Lower rank = higher priority. 99 = not priority (hidden).
  static int rank(MatchModel m) {
    if (!isMensCricketOrFootball(m)) return 99;

    final b = _blob(m);
    if (m.sport.toLowerCase() == 'cricket') {
      return _cricketRank(b);
    }
    return _footballRank(b, m);
  }

  static int _cricketRank(String b) {
    if (_cricketTier0.any(b.contains)) return 0;
    if (_cricketTier1.any(b.contains)) return 1;
    if (_cricketTier2.any(b.contains)) return 2;
    if (_hasPriorityNation(b)) return 3;
    return 99;
  }

  static int _footballRank(String b, MatchModel m) {
    if (_footballTier0.any(b.contains)) return 0;
    if (_footballTier1.any(b.contains)) return 1;
    if (_footballTier2Clubs.any(b.contains)) return 2;
    if (_hasPriorityNation(b)) return 3;
    // Team names in fixture (ESPN abbreviations / full names).
    if (_matchHasPriorityNation(m)) return 3;
    return 99;
  }

  static bool _hasPriorityNation(String b) =>
      _priorityNations.any((n) => b.contains(n));

  static bool _matchHasPriorityNation(MatchModel m) {
    final teams = '${m.teamA} ${m.teamB}'.toLowerCase();
    return _priorityNations.any(teams.contains);
  }

  static bool shouldShow(MatchModel m) => rank(m) < 99;

  static List<LiveEventMatch> filterAndSort(List<LiveEventMatch> events) {
    return events.where((e) => shouldShow(e.match)).toList();
  }
}
