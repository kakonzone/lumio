import '../models/model.dart';

/// Groups scoreboard matches into international vs premier-league buckets.
class MatchGrouping {
  static bool isPremierLeagueMatch(MatchModel m) {
    final blob = '${m.channel} ${m.time} ${m.teamA} ${m.teamB}'.toLowerCase();
    if (m.sport == 'Football') {
      return blob.contains('premier league');
    }
    if (m.sport == 'Cricket') {
      const keys = [
        'ipl',
        'premier league',
        'bpl',
        'psl',
        'cpl',
        'bbl',
        'sa20',
        'the hundred',
        'ilt20',
      ];
      return keys.any(blob.contains);
    }
    return false;
  }

  static List<MatchModel> international(List<MatchModel> matches) =>
      matches.where((m) => !isPremierLeagueMatch(m)).toList();

  static List<MatchModel> premierLeague(List<MatchModel> matches) =>
      matches.where(isPremierLeagueMatch).toList();
}
