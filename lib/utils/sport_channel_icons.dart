import '../models/model.dart';

/// Cricket / football / other sport detection for Sports nav filters.
class SportChannelIcons {
  SportChannelIcons._();

  static const cricketAsset = 'assets/images/cricket_icon.webp';
  static const footballAsset = 'assets/images/football_icon.webp';

  static const sportGridTypes = [
    'Cricket',
    'Football',
    'Basketball',
    'Tennis',
    'Formula 1',
    'Boxing',
    'Hockey',
    'Volleyball',
    'WWE',
    'Swimming',
    'Snooker',
    'Racing',
    'Other Sports',
  ];

  static const sportFilterPills = [
    'All',
    ...sportGridTypes,
  ];

  static const _footballExplicit = [
    'football',
    'soccer',
    ' epl',
    'premier league',
    'sky sports football',
    'sky sports epl',
    'sky sport nz premier',
    'uefa',
    'laliga',
    'bundesliga',
    'serie a',
    'champions league',
    'world cup football',
    'fifa world',
    'match-',
    'bfl live',
    'bfl ',
    'supersport football',
    'goal hd',
    'dazn',
  ];

  static const _cricketKeywords = [
    'cricket',
    'willow',
    'tsports',
    't sports',
    't-sports',
    'sony ten cricket',
    'ten cricket',
    'ptv sports',
    'fancode',
    'bpl',
    'ipl',
    'ashes',
    'wtc',
    'icc',
    'psl',
    'sky sports cricket',
    'super sport cricket',
    'astro cricket',
    'dd sports',
    'star sports 1',
    'star sports 2',
    'star sports 3',
    'star sports select',
    'star sports khel',
    'star sports hindi',
    'sony sports ten',
    'sony ten 1',
    'sony ten 2',
    'sony ten 3',
    'sony ten 5',
    'sony max sports',
    'bd vs',
    ' vs ',
  ];

  static const _footballBroad = [
    'bein sport',
    'bein',
    'eurosport',
    'tnt sports',
    'sky sports main',
    'sky sports mix',
    'sky sports action',
    'sky sports news',
    'fox sports',
    'espn',
    'supersport',
    'sport tv',
    'laliga',
  ];

  static const _bdCricketBroadcasters = [
    'gazi',
    'nagorik',
    'toffee',
    'tsports',
    't sports',
    'btv',
  ];

  static const _sportRules = <_SportRule>[
    _SportRule(
        'Formula 1', ['formula 1', 'formula one', ' f1', 'sky f1', 'motogp']),
    _SportRule(
        'Basketball', ['basketball', ' nba', 'ncaa', 'euroleague basket']),
    _SportRule('Tennis', [
      'tennis',
      'wimbledon',
      'us open',
      'australian open',
      'roland garros',
      ' atp',
      ' wta',
      'sky sports tennis',
    ]),
    _SportRule('Boxing', ['boxing', 'fight network', 'box nation']),
    _SportRule('Hockey', ['hockey', ' nhl', 'ice hockey', 'field hockey']),
    _SportRule('Volleyball', ['volleyball', 'volley']),
    _SportRule('WWE', ['wwe', 'wrestling']),
    _SportRule('Swimming', ['swimming', 'aquatic']),
    _SportRule('Snooker', ['snooker', 'pool tv']),
    _SportRule('Racing', [
      'racing',
      'nascar',
      'horse racing',
      'sky sports racing',
      'sky sport nz',
    ]),
  ];

  /// Channels shown on Sports tab (Sports category + cricket broadcasters).
  static List<ChannelModel> browseChannels(List<ChannelModel> all) {
    return all
        .where((c) => c.streamUrl.trim().isNotEmpty && isSportsBrowseChannel(c))
        .toList();
  }

  static bool isSportsBrowseChannel(ChannelModel channel) {
    if (channel.category == 'Sports') return true;
    return isBdCricketBroadcaster(channel);
  }

  static bool isBdCricketBroadcaster(ChannelModel channel) {
    final blob = _blob(channel);
    if (channel.category != 'Bangladesh' &&
        channel.category != 'Entertainment') {
      return false;
    }
    return _bdCricketBroadcasters.any(blob.contains);
  }

  static String? detectSportType(ChannelModel channel) {
    final blob = _blob(channel);

    if (_hasFootballSignal(blob)) return 'Football';
    if (_hasCricketSignal(blob)) return 'Cricket';
    if (isBdCricketBroadcaster(channel)) return 'Cricket';

    for (final rule in _sportRules) {
      if (rule.keywords.any(blob.contains)) return rule.name;
    }

    if (channel.category == 'Sports') {
      if (_footballBroad.any(blob.contains) &&
          !blob.contains('cricket') &&
          !blob.contains('tennis')) {
        return 'Football';
      }
      return 'Other Sports';
    }
    return null;
  }

  static Map<String, int> countBySportType(List<ChannelModel> channels) {
    final counts = <String, int>{
      for (final t in sportGridTypes) t: 0,
    };
    for (final c in channels) {
      final type = detectSportType(c);
      if (type != null && counts.containsKey(type)) {
        counts[type] = counts[type]! + 1;
      }
    }
    return counts;
  }

  static bool isCricketChannel(ChannelModel channel) =>
      detectSportType(channel) == 'Cricket' || isBdCricketBroadcaster(channel);

  static bool isFootballChannel(ChannelModel channel) =>
      detectSportType(channel) == 'Football';

  static String? assetFor(ChannelModel channel) {
    if (!isSportsBrowseChannel(channel)) return null;
    if (isCricketChannel(channel)) return cricketAsset;
    if (isFootballChannel(channel)) return footballAsset;
    return null;
  }

  static bool matchesSportFilter(ChannelModel channel, String sportFilter) {
    if (sportFilter == 'All') return true;
    final detected = detectSportType(channel);
    if (detected == sportFilter) return true;
    if (sportFilter == 'Cricket' && isBdCricketBroadcaster(channel)) {
      return true;
    }
    return false;
  }

  static String? assetForSportName(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'cricket':
        return cricketAsset;
      case 'football':
        return footballAsset;
      default:
        return null;
    }
  }

  static String _blob(ChannelModel channel) =>
      '${channel.name} ${channel.currentShow} ${channel.category}'
          .toLowerCase();

  static bool _hasFootballSignal(String blob) {
    if (_footballExplicit.any(blob.contains)) return true;
    if (blob.contains('star sports') &&
        (blob.contains('football') || blob.contains('epl'))) {
      return true;
    }
    return false;
  }

  static bool _hasCricketSignal(String blob) {
    if (_hasFootballSignal(blob) && !blob.contains('cricket')) return false;
    return _cricketKeywords.any(blob.contains);
  }
}

class _SportRule {
  final String name;
  final List<String> keywords;
  const _SportRule(this.name, this.keywords);
}
