import '../config/channel_categories.dart';
import '../models/model.dart';

/// Parses M3U playlists and merges duplicate channel names into multi-link entries.
class M3uMergeParser {
  M3uMergeParser._();

  static List<ChannelModel> parse(
    String content, {
    String idPrefix = 'm3u',
    String Function(String group, String name)? mapCategory,
    String Function(String group, String name)? mapCountry,
  }) {
    final byName = <String, _Builder>{};
    final lines = content.split('\n');
    var pendingName = '';
    var pendingGroup = '';
    var pendingLogo = '';
    final orphanUrls = <String>[];

    void flushOrphanUrls() {
      if (orphanUrls.isEmpty) return;
      final key = '__orphan_${orphanUrls.first.hashCode}';
      final b = byName.putIfAbsent(key, () => _Builder(
            id: '${idPrefix}_orphan_${byName.length}',
            name: 'Multi Link ${byName.length + 1}',
            category: 'Entertainment',
            country: 'India',
            group: '',
          ));
      for (final u in orphanUrls) {
        b.addUrl(u);
      }
      orphanUrls.clear();
    }

    for (var raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        flushOrphanUrls();
        pendingName = _afterComma(line);
        pendingGroup = _attr(line, 'group-title');
        pendingLogo = _attr(line, 'tvg-logo');
        continue;
      }

      if (!_isStreamLine(line)) continue;

      if (pendingName.isEmpty) {
        orphanUrls.add(line);
        continue;
      }

      final name = pendingName;
      final key = _nameKey(name);
      final b = byName.putIfAbsent(
        key,
        () => _Builder(
          id: '${idPrefix}_${byName.length}',
          name: name,
          category: mapCategory?.call(pendingGroup, name) ??
              categoryForGroup(pendingGroup, name),
          country: mapCountry?.call(pendingGroup, name) ?? _defaultCountry(pendingGroup, name),
          group: pendingGroup,
          logo: pendingLogo,
        ),
      );
      b.addUrl(line);
      pendingName = '';
      pendingGroup = '';
      pendingLogo = '';
    }

    flushOrphanUrls();

    return byName.values.map((b) => b.build()).where((c) => c.streamUrl.isNotEmpty).toList();
  }

  static String _nameKey(String name) => name.toLowerCase().trim();

  static bool _isStreamLine(String line) =>
      line.startsWith('http') || line.startsWith('rtmp') || line.startsWith('rtsp');

  static String _afterComma(String l) {
    final i = l.lastIndexOf(',');
    return i == -1 ? '' : l.substring(i + 1).trim();
  }

  static String _attr(String l, String k) =>
      RegExp('$k="([^"]*)"', caseSensitive: false).firstMatch(l)?.group(1) ?? '';

  /// Public alias for playlist importers (e.g. owner M3U on GitHub).
  static String categoryForGroup(String group, String name) =>
      ChannelCategoryRegistry.fromGroupTitle(group, name);

  static String _defaultCountry(String group, String name) {
    final s = (group + name).toLowerCase();
    if (s.contains('bangla') || s.contains('bangladesh')) return 'Bangladesh';
    if (s.contains('hindi') || s.contains('india')) return 'India';
    if (s.contains('pakistan')) return 'Pakistan';
    return 'India';
  }
}

class _Builder {
  final String id;
  final String name;
  final String category;
  final String country;
  final String group;
  String logo;
  final List<String> _urls = [];

  _Builder({
    required this.id,
    required this.name,
    required this.category,
    required this.country,
    required this.group,
    this.logo = '',
  });

  void addUrl(String url) {
    if (url.isEmpty) return;
    if (!_urls.contains(url)) _urls.add(url);
  }

  ChannelModel build() {
    if (_urls.isEmpty) {
      return ChannelModel(
        id: id,
        name: name,
        category: category,
        country: country,
        streamUrl: '',
        logoUrl: logo,
        isLive: true,
        currentShow: group,
      );
    }
    final alts = <StreamLink>[];
    for (var i = 1; i < _urls.length; i++) {
      alts.add(StreamLink(url: _urls[i], label: 'Link ${i + 1}'));
    }
    return ChannelModel(
      id: id,
      name: name,
      category: category,
      country: country,
      streamUrl: _urls.first,
      logoUrl: logo,
      isLive: true,
      viewers: 0,
      currentShow: group,
      alternateStreams: alts,
    );
  }
}
