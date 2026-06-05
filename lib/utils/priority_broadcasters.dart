import '../models/model.dart';

/// Top broadcasters shown first in sports lists, live events, and match picks.
class PriorityBroadcasters {
  PriorityBroadcasters._();

  /// Lower = higher in lists (FIFA → Sony → T Sports → BTV → beIN → …).
  static const _tiers = <_Tier>[
    _Tier(
      rank: 0,
      keywords: [
        'fifa',
        'world cup',
        'wc 2026',
        'wc26',
        'fifa world',
        'football world cup 2026',
        'fifa+',
        'fifa plus',
      ],
    ),
    _Tier(
      rank: 1,
      keywords: [
        'sony sports',
        'sony ten',
        'sony liv',
        'sony ',
      ],
    ),
    _Tier(
      rank: 2,
      keywords: [
        'tsports',
        't sports',
        't-sports',
        'toffee sports',
        'toffee',
      ],
    ),
    _Tier(
      rank: 3,
      keywords: [
        'btv',
        'b tv',
        'bangladesh television',
      ],
    ),
    _Tier(
      rank: 4,
      keywords: [
        'bein sports',
        'bein sport',
        'bein',
        'bien',
      ],
    ),
    _Tier(
      rank: 5,
      keywords: [
        'willow',
        'willow tv',
        'willow by',
      ],
    ),
  ];

  static const int notPriority = 99;

  /// 0 = FIFA … 5 = Willow; [notPriority] = everyone else.
  static int rank(ChannelModel channel) {
    final blob =
        '${channel.name} ${channel.currentShow} ${channel.category}'.toLowerCase();
    for (final tier in _tiers) {
      if (_containsAny(blob, tier.keywords)) return tier.rank;
    }
    return notPriority;
  }

  static bool isPriority(ChannelModel channel) => rank(channel) < notPriority;

  static int compare(ChannelModel a, ChannelModel b) {
    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static List<ChannelModel> sort(List<ChannelModel> channels) {
    final copy = [...channels];
    copy.sort(compare);
    return copy;
  }

  /// Extra score for [MatchChannelMatcher] (additive) — FIFA highest, then Sony, T Sports, BTV, beIN.
  static int matchScoreBoost(String channelBlob) {
    final b = channelBlob.toLowerCase();
    var boost = 0;
    if (_containsAny(b, _tiers[0].keywords)) boost += 90;
    if (_tiers.length > 1 && _containsAny(b, _tiers[1].keywords)) boost += 85;
    if (_tiers.length > 2 && _containsAny(b, _tiers[2].keywords)) boost += 80;
    if (_tiers.length > 3 && _containsAny(b, _tiers[3].keywords)) boost += 75;
    if (_tiers.length > 4 && _containsAny(b, _tiers[4].keywords)) boost += 70;
    if (_tiers.length > 5 && _containsAny(b, _tiers[5].keywords)) boost += 65;
    return boost;
  }

  static bool _containsAny(String blob, List<String> keywords) {
    for (final k in keywords) {
      if (blob.contains(k)) return true;
    }
    return false;
  }
}

class _Tier {
  const _Tier({required this.rank, required this.keywords});
  final int rank;
  final List<String> keywords;
}
