import '../models/live_event_match.dart';
import '../models/model.dart';
import '../utils/live_event_priority.dart';
import '../utils/live_event_sort.dart';
import '../utils/schedule_merge.dart';
import 'footystream_service.dart';
import 'match_channel_matcher.dart';
import 'score_service.dart';

class LiveEventsBundle {
  final List<LiveEventMatch> football;
  final List<LiveEventMatch> cricket;
  final List<LiveEventMatch> all;

  const LiveEventsBundle({
    this.football = const [],
    this.cricket = const [],
    this.all = const [],
  });

  bool get isEmpty => all.isEmpty && football.isEmpty && cricket.isEmpty;
}

class LiveEventsService {
  /// FootyStream /pk + ESPN/Cricbuzz — merged when same teams/day; ESPN filters unchanged.
  static Future<LiveEventsBundle> fetch(List<ChannelModel> channels) async {
    final pkFuture = FootyStreamService.fetchPk();
    final groupsFuture = ScoreService.fetchTodayScoreboards();
    final pkMatches = await pkFuture;
    final groups = await groupsFuture;

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

    final pkFootball =
        pkMatches.where((m) => m.sport.toLowerCase() != 'cricket').toList();
    final pkCricket =
        pkMatches.where((m) => m.sport.toLowerCase() == 'cricket').toList();

    final mergedFootball = ScheduleMerge.mergeMatches([
      pkFootball,
      footballRaw,
    ]);
    final mergedCricket = ScheduleMerge.mergeMatches([
      pkCricket,
      cricketRaw,
    ]);

    final footballWrapped = ScheduleMerge.mergeLiveEvents(
      _wrap(mergedFootball, channels),
    );
    final cricketWrapped = ScheduleMerge.mergeLiveEvents(
      _wrap(mergedCricket, channels),
    );

    final football = LiveEventSort.sort(
      LiveEventPriority.filterAndSort(footballWrapped),
    );
    final cricket = LiveEventSort.sort(
      LiveEventPriority.filterAndSort(cricketWrapped),
    );
    final all = LiveEventSort.sort([...football, ...cricket]);

    return LiveEventsBundle(
      all: all,
      football: football,
      cricket: cricket,
    );
  }

  static List<LiveEventMatch> _wrap(
    List<MatchModel> matches,
    List<ChannelModel> channels,
  ) {
    return matches.map(
      (m) {
        final pool = MatchChannelMatcher.channelPoolFor(channels, m);
        return LiveEventMatch(
          match: m,
          relatedChannels: MatchChannelMatcher.findRelated(
            m,
            pool,
            tournamentLabel: m.channel,
          ),
        );
      },
    ).toList();
  }
}
