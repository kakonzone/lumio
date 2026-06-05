import '../models/model.dart';

/// Canonical channel categories for Home, Browse, and Categories tab.
class ChannelCategoryDef {
  const ChannelCategoryDef({
    required this.id,
    required this.label,
    required this.emoji,
    required this.subtitle,
    this.sortOrder = 50,
    this.preferLiveBadge = false,
    this.accentArgb = 0xFFFF6B1A,
  });

  final String id;
  final String label;
  final String emoji;
  final String subtitle;
  final int sortOrder;
  final bool preferLiveBadge;
  final int accentArgb;
}

/// Maps M3U [group-title] + channel name → app categories.
class ChannelCategoryRegistry {
  ChannelCategoryRegistry._();

  static const specialLinkId = '__special_link__';

  /// Fixed home grid — only these tiles (not every playlist genre).
  static const homeTileCategoryIds = <String>[
    'Sports',
    'Bangladesh',
    'Entertainment',
    'Movies',
    'Kids',
  ];

  static const _defs = <ChannelCategoryDef>[
    ChannelCategoryDef(
      id: 'Sports',
      label: 'Sports',
      emoji: '⚽',
      subtitle: 'Cricket, football & live sports',
      sortOrder: 1,
      preferLiveBadge: true,
      accentArgb: 0xFFFF6B1A,
    ),
    ChannelCategoryDef(
      id: 'Bangladesh',
      label: 'Bangla',
      emoji: '🇧🇩',
      subtitle: 'Bangladesh & Kolkata TV',
      sortOrder: 2,
      preferLiveBadge: true,
      accentArgb: 0xFF009688,
    ),
    ChannelCategoryDef(
      id: 'News',
      label: 'News',
      emoji: '📰',
      subtitle: 'Live news & current affairs',
      sortOrder: 3,
      preferLiveBadge: true,
      accentArgb: 0xFF1565C0,
    ),
    ChannelCategoryDef(
      id: 'Entertainment',
      label: 'Entertainment',
      emoji: '🎭',
      subtitle: 'Drama, reality & general TV',
      sortOrder: 4,
      accentArgb: 0xFF9C27B0,
    ),
    ChannelCategoryDef(
      id: 'Movies',
      label: 'Movies',
      emoji: '🎬',
      subtitle: 'Movies & cinema channels',
      sortOrder: 5,
      accentArgb: 0xFFE91E63,
    ),
    ChannelCategoryDef(
      id: 'Kids',
      label: 'Cartoon',
      emoji: '🎨',
      subtitle: 'Cartoons & family',
      sortOrder: 6,
      accentArgb: 0xFF4CAF50,
    ),
    ChannelCategoryDef(
      id: 'Hindi',
      label: 'Hindi',
      emoji: '🇮🇳',
      subtitle: 'Hindi & Bollywood',
      sortOrder: 7,
      preferLiveBadge: true,
      accentArgb: 0xFFFF9800,
    ),
    ChannelCategoryDef(
      id: 'English',
      label: 'English',
      emoji: '🇬🇧',
      subtitle: 'UK, US & international',
      sortOrder: 8,
      accentArgb: 0xFF2196F3,
    ),
    ChannelCategoryDef(
      id: 'Pakistan',
      label: 'Pakistan',
      emoji: '🇵🇰',
      subtitle: 'Pakistani channels',
      sortOrder: 9,
      preferLiveBadge: true,
      accentArgb: 0xFF2E7D32,
    ),
    ChannelCategoryDef(
      id: 'KDrama',
      label: 'KDrama',
      emoji: '🇰🇷',
      subtitle: 'Korean drama & shows',
      sortOrder: 10,
      accentArgb: 0xFFFF4081,
    ),
    ChannelCategoryDef(
      id: 'Live TV',
      label: 'Live TV',
      emoji: '📡',
      subtitle: 'More live streams',
      sortOrder: 90,
      preferLiveBadge: true,
      accentArgb: 0xFF546E7A,
    ),
    ChannelCategoryDef(
      id: specialLinkId,
      label: 'Special Link',
      emoji: '🔗',
      subtitle: 'GITUN third-party playlists',
      sortOrder: 99,
      preferLiveBadge: true,
      accentArgb: 0xFF5E35B1,
    ),
  ];

  static ChannelCategoryDef? defFor(String categoryId) {
    final id = normalizeId(categoryId);
    for (final d in _defs) {
      if (d.id == id) return d;
    }
    return null;
  }

  static String normalizeId(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return 'Entertainment';
    if (s == 'Bangla') return 'Bangladesh';
    if (s == 'Live Channels') return 'Live TV';
    return s;
  }

  /// Category from M3U `group-title` (your GitHub playlist).
  static String fromGroupTitle(String group, String channelName) {
    final g = group.trim().toLowerCase();
    if (g.isEmpty) return fromChannelName(channelName);
    if (g == 'sports' || g.contains('sport')) return 'Sports';
    if (g == 'bangladesh' ||
        g.contains('bangla') ||
        g.contains('bangladesh')) {
      return 'Bangladesh';
    }
    if (g.contains('pakistan') || g == 'pk') return 'Pakistan';
    if (g.contains('hindi') || g.contains('india') || g.contains('bollywood')) {
      return 'Hindi';
    }
    if (g.contains('english') ||
        g.contains(' uk') ||
        g.startsWith('uk ') ||
        g.contains('usa') ||
        g.contains('international')) {
      return 'English';
    }
    if (g.contains('news') || g.contains('current affairs')) return 'News';
    if (g.contains('movie') || g.contains('cinema') || g.contains('film')) {
      return 'Movies';
    }
    if (g.contains('kid') || g.contains('cartoon') || g.contains('children')) {
      return 'Kids';
    }
    if (g.contains('korea') || g.contains('k-drama') || g.contains('kdrama')) {
      return 'KDrama';
    }
    if (g.contains('entertain') || g.contains('drama') || g.contains('general')) {
      return 'Entertainment';
    }
    if (g == 'live tv' || g == 'live' || g == 'livetv') {
      return fromChannelName(channelName);
    }
    if (g.isNotEmpty) {
      final titled = _titleCase(group);
      if (defFor(titled) != null) return titled;
      return fromChannelName(channelName);
    }
    return fromChannelName(channelName);
  }

  /// Refine category using channel title (for large "Live TV" groups).
  static String fromChannelName(String name) {
    final s = name.toLowerCase();

    if (_hasAny(s, [
      'sport',
      'cricket',
      'football',
      'soccer',
      'epl',
      'f1',
      'nba',
      'match ',
      ' vs ',
      'tsports',
      'star sports',
      'sony sports',
      'willow',
      'bein',
      'eurosport',
    ])) {
      return 'Sports';
    }

    if (_hasAny(s, [
      'news',
      'jago',
      'somoy',
      'jamuna',
      'ekattor',
      'independent',
      'channel 24',
      'channel i',
      'rtv',
      'atn',
      'nrb',
      'dbc',
      'boishakhi',
      'rplus',
      'mnews',
      'cnn',
      'bbc',
      'sky news',
      'republic',
      'aaj tak',
      'ndtv',
      'wion',
      'abp',
      'times now',
    ])) {
      return 'News';
    }

    if (_hasAny(s, [
      'movie',
      'cinema',
      'film',
      'hbo',
      'zee cinema',
      'sony max',
      'star gold',
      '&flix',
      'b4u movies',
    ])) {
      return 'Movies';
    }

    if (_hasAny(s, [
      'kids',
      'cartoon',
      'nick',
      'pogo',
      'cn ',
      'disney',
      'baby',
    ])) {
      return 'Kids';
    }

    if (_hasAny(s, [
      'pakistan',
      'ptv',
      'geo ',
      'ary ',
      'hum tv',
      'duniya',
    ])) {
      return 'Pakistan';
    }

    if (_hasAny(s, [
      'bangla',
      'bangladesh',
      'btv',
      'gazi',
      'nagorik',
      'deepto',
      'maasranga',
      'duronto',
    ])) {
      return 'Bangladesh';
    }

    if (_hasAny(s, [
      'hindi',
      'zee ',
      'colors',
      'star plus',
      'sony tv',
      'sab tv',
      '&tv',
      'bollywood',
    ])) {
      return 'Hindi';
    }

    if (_hasAny(s, [
      'korean',
      'k-drama',
      'kdrama',
      'kbs',
      'mbc',
      'tvn',
    ])) {
      return 'KDrama';
    }

    if (_hasAny(s, [
      'discovery',
      'nat geo',
      'history',
      'tlc',
      'fx ',
      'comedy',
      'entertain',
      'drama',
      'shemaroo',
      'colors',
    ])) {
      return 'Entertainment';
    }

    if (_hasAny(s, [
      'bbc',
      'itv',
      'sky ',
      'fox ',
      'cnn',
      'usa',
      'uk ',
      'english',
    ])) {
      return 'English';
    }

    return 'Live TV';
  }

  static ChannelModel normalizeChannel(ChannelModel c) {
    var group = c.currentShow.trim();
    var category = normalizeId(c.category);

    if (group.isNotEmpty) {
      category = fromGroupTitle(group, c.name);
    } else if (category == 'Entertainment' || category == 'Live TV') {
      category = fromChannelName(c.name);
    }

    category = normalizeId(category);
    return c.copyWith(category: category);
  }

  static List<ChannelModel> normalizeAll(List<ChannelModel> list) =>
      list.map(normalizeChannel).toList();

  /// Home / Browse tiles: categories that have live channels, sorted.
  static List<Map<String, String>> tilesForChannels(
    List<ChannelModel> channels, {
    bool includeSpecialLink = true,
  }) {
    final counts = <String, int>{};
    for (final c in channels) {
      if (c.streamUrl.isEmpty) continue;
      final id = normalizeId(c.category);
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final tiles = <Map<String, String>>[];
    final ordered = List<ChannelCategoryDef>.from(_defs)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final def in ordered) {
      if (def.id == specialLinkId) continue;
      final n = counts[def.id] ?? 0;
      if (n == 0) continue;
      tiles.add({
        'icon': def.emoji,
        'label': def.label,
        'cat': def.id,
        'subtitle': def.subtitle,
        'count': '$n',
      });
    }

    if (includeSpecialLink) {
      tiles.add({
        'icon': '🔗',
        'label': 'Special Link',
        'cat': specialLinkId,
        'subtitle': 'GITUN playlists',
        'count': '0',
      });
    }

    return tiles;
  }

  /// Home tab grid — fixed categories in order (always shown).
  static List<Map<String, String>> homeTilesForChannels(
    List<ChannelModel> channels, {
    bool includeSpecialLink = true,
  }) {
    final counts = <String, int>{};
    for (final c in channels) {
      if (c.streamUrl.isEmpty) continue;
      final id = normalizeId(c.category);
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final tiles = <Map<String, String>>[];
    for (final id in homeTileCategoryIds) {
      final def = defFor(id);
      if (def == null) continue;
      final n = counts[id] ?? 0;
      tiles.add({
        'icon': def.emoji,
        'label': def.label,
        'cat': def.id,
        'subtitle': def.subtitle,
        'count': '$n',
      });
    }

    if (includeSpecialLink) {
      final def = defFor(specialLinkId);
      tiles.add({
        'icon': def?.emoji ?? '🔗',
        'label': def?.label ?? 'Special Link',
        'cat': specialLinkId,
        'subtitle': def?.subtitle ?? 'GITUN playlists',
        'count': '0',
      });
    }

    return tiles;
  }

  /// Full Categories tab rows: [emoji, title, subtitle, preferLive, accent].
  static List<List<Object>> genreRowsForChannels(List<ChannelModel> channels) {
    final counts = <String, int>{};
    for (final c in channels) {
      if (c.streamUrl.isEmpty) continue;
      final id = normalizeId(c.category);
      counts[id] = (counts[id] ?? 0) + 1;
    }

    final rows = <List<Object>>[];
    final ordered = List<ChannelCategoryDef>.from(_defs)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final def in ordered) {
      if (def.id == specialLinkId) {
        rows.add([
          def.emoji,
          def.label,
          def.subtitle,
          def.preferLiveBadge,
          def.accentArgb,
        ]);
        continue;
      }
      if ((counts[def.id] ?? 0) == 0) continue;
      rows.add([
        def.emoji,
        def.label == 'Bangla' ? 'Bangla' : def.label,
        '${counts[def.id]} channels · ${def.subtitle}',
        def.preferLiveBadge,
        def.accentArgb,
      ]);
    }
    return rows;
  }

  static bool _hasAny(String haystack, List<String> needles) =>
      needles.any(haystack.contains);

  static String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .map((w) =>
            w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
