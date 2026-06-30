import 'package:flutter/foundation.dart';

import '../config/channel_categories.dart';
import '../core/result.dart';
import '../models/model.dart';
import 'channel_name_normalizer.dart';
import 'channel_playback_links.dart';

/// Top-level function for use with compute() isolate - Appwrite variant.
/// Returns Result type for proper error handling.
Result<List<ChannelModel>> parseM3uAppwriteIsolate(String content) {
  try {
    final channels = M3uMergeParser.parse(
      content,
      idPrefix: 'appwrite',
      mapCategory: M3uMergeParser.categoryForGroup,
    );
    return Success(channels);
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('[M3uParser] Appwrite parse error: $e\n$stack');
    }
    return Failure(ParseError('Failed to parse M3U content', content), stack);
  }
}

/// Top-level function for use with compute() isolate - Gitun variant.
/// Returns Result type for proper error handling.
Result<List<ChannelModel>> parseM3uGitunIsolate(
  (String, String, bool, String) params,
) {
  try {
    final (content, idPrefix, includeAllChannels, gitunOnlyCategory) = params;
    final channels = M3uMergeParser.parse(
      content,
      idPrefix: idPrefix,
      mapCategory: includeAllChannels
          ? M3uMergeParser.categoryForGroup
          : (_, __) => gitunOnlyCategory,
      mapCountry: (_, __) => 'International',
    );
    return Success(channels);
  } catch (e, stack) {
    if (kDebugMode) {
      debugPrint('[M3uParser] Gitun parse error: $e\n$stack');
    }
    final (content, _, _, _) = params;
    return Failure(ParseError('Failed to parse Gitun M3U content', content), stack);
  }
}

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
    var extinfCount = 0;
    var urlCount = 0;

    void flushOrphanUrls() {
      if (orphanUrls.isEmpty) return;
      final key = '__orphan_${orphanUrls.first.hashCode}';
      final b = byName.putIfAbsent(
          key,
          () => _Builder(
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

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        extinfCount++;
        flushOrphanUrls();
        pendingName = ChannelNameNormalizer.clean(
          _afterComma(line),
          tvgName: _attr(line, 'tvg-name'),
        );
        pendingGroup = _attr(line, 'group-title');
        pendingLogo = _attr(line, 'tvg-logo');

        // Search forward for URL (handles blank lines, comments, #EXTVLCOPT between EXTINF and URL)
        String? url;
        for (var j = i + 1; j < lines.length; j++) {
          final next = lines[j].trim();
          if (next.isEmpty) continue;
          if (next.startsWith('#EXTINF')) break;
          if (next.startsWith('http://') ||
              next.startsWith('https://') ||
              next.startsWith('rtmp://') ||
              next.startsWith('rtsp://')) {
            url = next;
            break;
          }
        }

        if (url != null && pendingName.isNotEmpty) {
          urlCount++;
          final name = pendingName;
          final key = _nameKey(name);
          final b = byName.putIfAbsent(
            key,
            () => _Builder(
              id: '${idPrefix}_${byName.length}',
              name: name,
              category: mapCategory?.call(pendingGroup, name) ??
                  categoryForGroup(pendingGroup, name),
              country: mapCountry?.call(pendingGroup, name) ??
                  _defaultCountry(pendingGroup, name),
              group: pendingGroup,
              logo: pendingLogo,
            ),
          );
          b.addUrl(url);
        }

        pendingName = '';
        pendingGroup = '';
        pendingLogo = '';
      }
    }

    flushOrphanUrls();

    if (kDebugMode) {
      debugPrint('[M3uParser] Input lines: ${lines.length}');
      debugPrint('[M3uParser] #EXTINF lines: $extinfCount');
      debugPrint('[M3uParser] URL-like lines: $urlCount');
      debugPrint('[M3uParser] Unique channels parsed: ${byName.length}');
      debugPrint('[M3uParser] Orphan URLs: ${orphanUrls.length}');
    }

    return byName.values
        .map((b) => b.build())
        .where((c) => c.streamUrl.isNotEmpty)
        .toList();
  }

  static String _nameKey(String name) =>
      ChannelPlaybackLinks.mergeKeyForName(name);

  static String _afterComma(String l) {
    final i = l.lastIndexOf(',');
    return i == -1 ? '' : l.substring(i + 1).trim();
  }

  static String _attr(String l, String k) =>
      RegExp('$k="([^"]*)"', caseSensitive: false).firstMatch(l)?.group(1) ??
      '';

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
