import '../models/model.dart';
import 'priority_broadcasters.dart';
import 'sport_channel_icons.dart';

/// Live sports ordering: Bangladesh → India → Pakistan → other regions.
class SportsChannelPriority {
  SportsChannelPriority._();

  static const int bangladesh = 0;
  static const int india = 1;
  static const int pakistan = 2;
  static const int other = 3;

  static const _bangladeshCountry = {
    'bangladesh',
    'bangla',
    'bd',
    'bdt',
  };

  static const _indiaCountry = {
    'india',
    'indian',
    'in',
    'hindi',
  };

  static const _pakistanCountry = {
    'pakistan',
    'pakistani',
    'pk',
    'urdu',
  };

  static const _bangladeshNameHints = [
    'bangladesh',
    'bangla',
    'gazi tv',
    'gazi',
    'tsports',
    't sports',
    't-sports',
    'btv',
    'rtv',
    'channel i',
    'somoy',
    'jamuna',
    'dbc',
    'nagorik',
    'maasranga',
    'deepto',
    'atn',
  ];

  static const _indiaNameHints = [
    'india',
    'indian',
    'hindi',
    'sony',
    'star sports',
    'star select',
    'dd sports',
    'jio cinema',
    'eurosport india',
    'sports18',
    'willow', // cricket feed popular in subcontinent
  ];

  static const _pakistanNameHints = [
    'pakistan',
    'pakistani',
    'ptv',
    'a sports',
    'asports',
    'geo super',
    'ten sports pk',
    'ary',
    'hum',
  ];

  static int regionPriority(ChannelModel channel) {
    final country = channel.country.trim().toLowerCase();
    if (_matchesAny(country, _bangladeshCountry)) return bangladesh;
    if (_matchesAny(country, _indiaCountry)) return india;
    if (_matchesAny(country, _pakistanCountry)) return pakistan;

    final blob = '${channel.name} ${channel.currentShow} ${channel.category}'
        .toLowerCase();

    if (_containsAny(blob, _bangladeshNameHints)) return bangladesh;
    if (_containsAny(blob, _pakistanNameHints)) return pakistan;
    if (_containsAny(blob, _indiaNameHints)) return india;

    return other;
  }

  static String regionSectionTitle(int priority) {
    switch (priority) {
      case bangladesh:
        return 'BANGLADESH SPORTS';
      case india:
        return 'INDIA SPORTS';
      case pakistan:
        return 'PAKISTAN SPORTS';
      default:
        return 'INTERNATIONAL SPORTS';
    }
  }

  static List<ChannelModel> sortLiveSports(List<ChannelModel> channels) {
    final copy = [...channels];
    copy.sort(compare);
    return copy;
  }

  /// Groups sorted by region priority (BD → IN → PK → other).
  static List<({int region, List<ChannelModel> channels})> groupedByRegion(
    List<ChannelModel> channels,
  ) {
    final buckets = <int, List<ChannelModel>>{};
    for (final c in channels) {
      final r = regionPriority(c);
      buckets.putIfAbsent(r, () => []).add(c);
    }
    for (final list in buckets.values) {
      list.sort(compare);
    }
    return [
      for (final r in [bangladesh, india, pakistan, other])
        if (buckets[r]?.isNotEmpty ?? false) (region: r, channels: buckets[r]!),
    ];
  }

  static int compare(ChannelModel a, ChannelModel b) {
    final pa = PriorityBroadcasters.rank(a);
    final pb = PriorityBroadcasters.rank(b);
    if (pa != pb) return pa.compareTo(pb);

    final ra = regionPriority(a);
    final rb = regionPriority(b);
    if (ra != rb) return ra.compareTo(rb);

    final ta = _typeRank(a);
    final tb = _typeRank(b);
    if (ta != tb) return ta.compareTo(tb);

    final viewers = b.viewers.compareTo(a.viewers);
    if (viewers != 0) return viewers;

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  static int _typeRank(ChannelModel c) {
    if (SportChannelIcons.isCricketChannel(c)) return 0;
    if (SportChannelIcons.isFootballChannel(c)) return 1;
    return 2;
  }

  static bool _matchesAny(String value, Set<String> keys) {
    if (value.isEmpty) return false;
    for (final k in keys) {
      if (value == k || value.contains(k)) return true;
    }
    return false;
  }

  static bool _containsAny(String blob, List<String> hints) {
    for (final h in hints) {
      if (blob.contains(h)) return true;
    }
    return false;
  }
}
