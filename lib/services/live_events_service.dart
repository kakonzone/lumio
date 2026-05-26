import '../models/live_event_match.dart';
import '../models/model.dart';
import '../utils/live_event_priority.dart';
import '../utils/live_event_sort.dart';
import 'match_channel_matcher.dart';
import 'score_service.dart';

class LiveEventsBundle {
  final List<LiveEventMatch> football;
  final List<LiveEventMatch> cricket;

  const LiveEventsBundle({
    this.football = const [],
    this.cricket = const [],
  });

  bool get isEmpty => football.isEmpty && cricket.isEmpty;
}

class LiveEventsService {
  static Future<LiveEventsBundle> fetch(List<ChannelModel> channels) async {
    final groups = await ScoreService.fetchTodayScoreboards();
    final footballRaw = <MatchModel>[];
    final cricketRaw = <MatchModel>[];

    for (final g in groups) {
      final t = g.tournament.toLowerCase();
      if (t.contains('cricket')) {
        cricketRaw.addAll(g.matches);
      } else {
        footballRaw.addAll(g.matches);
      }
    }

    final football = LiveEventSort.sort(
      LiveEventPriority.filterAndSort(_wrap(footballRaw, channels)),
    );
    final cricket = LiveEventSort.sort(
      LiveEventPriority.filterAndSort(_wrap(cricketRaw, channels)),
    );

    return LiveEventsBundle(
      football: football,
      cricket: cricket,
    );
  }

  static List<LiveEventMatch> _wrap(
    List<MatchModel> matches,
    List<ChannelModel> channels,
  ) {
    final sports = channels
        .where((c) => c.category == 'Sports' && c.streamUrl.isNotEmpty)
        .toList();
    return matches
        .map(
          (m) => LiveEventMatch(
            match: m,
            relatedChannels: MatchChannelMatcher.findRelated(m, sports),
          ),
        )
        .toList();
  }
}
