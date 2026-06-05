import '../config/channel_categories.dart';
import '../models/model.dart';
import 'channel_name_normalizer.dart';
import 'sport_channel_icons.dart';

/// Single place to normalize channels so one add appears everywhere:
/// Categories, bottom Live nav, Sports tab, Live Events matcher.
class ChannelCatalog {
  ChannelCatalog._();

  static const _sportsBlobKeywords = [
    'cricket',
    'football',
    'soccer',
    'epl',
    'bfl',
    'star sports',
    'sony sports',
    'sony ten',
    't sports',
    'tsports',
    'toffee sports',
    'willow',
    'ptv sports',
    'euro sport',
    'eurosport',
    'match-',
    ' vs ',
    'bd vs',
    'fancode',
    'bein sport',
    'sky sports',
    'tnt sports',
    'dd sports',
    'geo super',
    'a sports',
    'sports18',
    'jio cinema sport',
    'gazi tv',
    'gazi',
    'nba',
    'tennis',
    'supersport',
    'fox sports',
    'espn',
  ];

  static List<ChannelModel> normalizeAll(List<ChannelModel> raw) {
    return raw.map(normalize).map(ChannelCategoryRegistry.normalizeChannel).toList();
  }

  static ChannelModel normalize(ChannelModel c) {
    final name = ChannelNameNormalizer.clean(c.name);
    var category = ChannelCategoryRegistry.normalizeId(c.category.trim());
    if (category.isEmpty) category = 'Entertainment';

    final sportsCandidate = c.copyWith(name: name);
    if (category != 'Sports' && _shouldBeSports(sportsCandidate)) {
      category = 'Sports';
    }

    var streamUrl = c.streamUrl.trim();
    final alts = c.alternateStreams;
    if (streamUrl.isEmpty && alts.isNotEmpty) {
      streamUrl = alts.first.url;
    }

    if (name == c.name && category == c.category && streamUrl == c.streamUrl) {
      return c;
    }

    return c.copyWith(
      name: name,
      category: category,
      streamUrl: streamUrl,
    );
  }

  static bool _shouldBeSports(ChannelModel c) {
    if (c.category == 'Sports') return true;
    if (SportChannelIcons.isCricketChannel(c) ||
        SportChannelIcons.isFootballChannel(c)) {
      return true;
    }
    final blob = '${c.name} ${c.currentShow}'.toLowerCase();
    return _sportsBlobKeywords.any(blob.contains);
  }
}
