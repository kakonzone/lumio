import 'model.dart';

/// Live Events row: API match + related app channels for chips.
class LiveEventMatch {
  final MatchModel match;
  final List<ChannelModel> relatedChannels;

  const LiveEventMatch({
    required this.match,
    this.relatedChannels = const [],
  });

  String get tournament => match.channel;
}
