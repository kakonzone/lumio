import 'dart:convert';
import 'dart:io';

import '../models/model.dart';
import 'ad_debug_log.dart';

/// Splits multi-link "hub" channels (e.g. many Akash TV streams) into a parent
/// hub + named child channels, and auto-detects similar URL-prefix groups.
class ChannelHubProcessor {
  ChannelHubProcessor._();

  static const _debugSessionId = 'f0885a';

  static final RegExp _akashSlug = RegExp(
    r'gpcdn\.net/akash/([^/]+)/',
    caseSensitive: false,
  );

  /// Same channel ID, different renditions (index/audio) — not sub-channels.
  static final RegExp _bpkMirrorOnly = RegExp(
    r'gpcdn\.net/bpk-tv/\d+/output/',
    caseSensitive: false,
  );

  /// Minimum streams to treat as a hub (parent + children).
  static const int minHubStreams = 3;

  static List<ChannelModel> expand(List<ChannelModel> channels) {
    final out = <ChannelModel>[];
    var expandedHubs = 0;
    var expandedChildren = 0;

    for (final c in channels) {
      final split = _trySplitChannel(c);
      if (split != null) {
        out.addAll(split);
        expandedHubs++;
        expandedChildren += split.length - 1;
      } else {
        out.add(c);
      }
    }

    // #region agent log
    _agentLog(
      location: 'channel_hub_processor.dart:expand',
      message: 'hub expand complete',
      hypothesisId: 'H-hub-expand',
      data: {
        'inputCount': channels.length,
        'outputCount': out.length,
        'expandedHubs': expandedHubs,
        'expandedChildren': expandedChildren,
        'hubGroups': out.where((c) => c.hubGroupId != null).map((c) => c.hubGroupId).toSet().length,
      },
    );
    // #endregion

    return out;
  }

  /// Related list for player: hub children / siblings first, then category fallback.
  static List<ChannelModel> relatedForChannel(
    ChannelModel? current,
    List<ChannelModel> all, {
    String? excludeUrl,
    int limit = 24,
  }) {
    if (current == null) return const [];

    final hubId = current.hubGroupId;
    if (hubId != null && hubId.isNotEmpty) {
      final siblings = all
          .where((c) =>
              c.hubGroupId == hubId &&
              c.id != current.id &&
              c.streamUrl.isNotEmpty &&
              !c.isHubParent)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      // #region agent log
      _agentLog(
        location: 'channel_hub_processor.dart:relatedForChannel',
        message: 'hub siblings',
        hypothesisId: 'H-hub-related',
        data: {
          'current': current.name,
          'hubGroupId': hubId,
          'siblingCount': siblings.length,
        },
      );
      // #endregion
      return siblings.take(limit).toList();
    }

    if (current.isHubParent) {
      final children = all
          .where((c) =>
              c.hubGroupId == current.id &&
              c.streamUrl.isNotEmpty &&
              !c.isHubParent)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      // #region agent log
      _agentLog(
        location: 'channel_hub_processor.dart:relatedForChannel',
        message: 'hub children',
        hypothesisId: 'H-hub-related',
        data: {
          'hub': current.name,
          'hubId': current.id,
          'childCount': children.length,
        },
      );
      // #endregion
      return children.take(limit).toList();
    }

    return const [];
  }

  static List<ChannelModel>? _trySplitChannel(ChannelModel c) {
    final streams = c.allStreams.where((s) => s.url.isNotEmpty).toList();
    if (streams.length < minHubStreams) return null;

    final akashSlugs = <String>[];
    for (final s in streams) {
      final m = _akashSlug.firstMatch(s.url);
      if (m == null) return null;
      akashSlugs.add(m.group(1)!);
    }
    if (akashSlugs.toSet().length >= minHubStreams) {
      return _buildHubFamily(
        hubId: 'hub_akash',
        hubName: 'Akash TV',
        category: c.category.isNotEmpty ? c.category : 'Entertainment',
        country: c.country,
        logoUrl: c.logoUrl,
        streams: streams,
        slugOf: (url) => _akashSlug.firstMatch(url)?.group(1),
        childName: (slug) => 'Akash ${_titleSlug(slug)}',
      );
    }

    if (streams.every((s) => _bpkMirrorOnly.hasMatch(s.url))) {
      return null;
    }

    final prefix = _longestSharedPathPrefix(streams.map((s) => s.url).toList());
    if (prefix == null || prefix.length < 24) return null;

    final slugs = <String>[];
    for (final url in streams.map((s) => s.url)) {
      final slug = _slugAfterPrefix(url, prefix);
      if (slug == null || slug.isEmpty) return null;
      slugs.add(slug);
    }
    if (slugs.toSet().length < minHubStreams) return null;

    final n = c.name.trim().toLowerCase();
    if (n.startsWith('stream ') || n.startsWith('multi link')) return null;

    final hubKey = _hubKeyFromPrefix(prefix, c.name);
    return _buildHubFamily(
      hubId: hubKey,
      hubName: c.name,
      category: c.category.isNotEmpty ? c.category : 'Entertainment',
      country: c.country,
      logoUrl: c.logoUrl,
      streams: streams,
      slugOf: (url) => _slugAfterPrefix(url, prefix),
      childName: (slug) => '${c.name} ${_titleSlug(slug)}',
    );
  }

  static List<ChannelModel> _buildHubFamily({
    required String hubId,
    required String hubName,
    required String category,
    required String country,
    required String logoUrl,
    required List<StreamLink> streams,
    required String? Function(String url) slugOf,
    required String Function(String slug) childName,
  }) {
    final children = <ChannelModel>[];
    final seenSlugs = <String>{};

    for (final link in streams) {
      final slug = slugOf(link.url);
      if (slug == null || !seenSlugs.add(slug)) continue;
      children.add(
        ChannelModel(
          id: '${hubId}_$slug',
          name: childName(slug),
          category: category,
          country: country,
          streamUrl: link.url,
          logoUrl: logoUrl,
          isLive: true,
          viewers: 0,
          currentShow: hubName,
          headers: link.headers,
          hubGroupId: hubId,
        ),
      );
    }

    if (children.length < minHubStreams) return [];

    children.sort((a, b) => a.name.compareTo(b.name));
    final first = children.first;

    final hub = ChannelModel(
      id: hubId,
      name: hubName,
      category: category,
      country: country,
      streamUrl: first.streamUrl,
      logoUrl: logoUrl,
      isLive: true,
      viewers: 0,
      currentShow: '${children.length} channels',
      headers: first.headers,
      hubGroupId: hubId,
      isHubParent: true,
    );

    return [hub, ...children];
  }

  static String _hubKeyFromPrefix(String prefix, String name) {
    final cleaned = prefix
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final namePart = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final raw = 'hub_${namePart}_$cleaned';
    return raw.length <= 56 ? raw : raw.substring(0, 56);
  }

  static String? _slugAfterPrefix(String url, String prefix) {
    if (!url.startsWith(prefix)) return null;
    final rest = url.substring(prefix.length);
    final seg = rest.split('/').firstWhere((s) => s.isNotEmpty, orElse: () => '');
    return seg.isEmpty ? null : seg;
  }

  static String? _longestSharedPathPrefix(List<String> urls) {
    if (urls.length < minHubStreams) return null;
    var prefix = urls.first;
    for (var i = 1; i < urls.length; i++) {
      final u = urls[i];
      var end = prefix.length < u.length ? prefix.length : u.length;
      var j = 0;
      while (j < end && prefix.codeUnitAt(j) == u.codeUnitAt(j)) {
        j++;
      }
      prefix = prefix.substring(0, j);
      if (prefix.isEmpty) return null;
    }
    // Require prefix to end at path boundary (trailing /)
    final lastSlash = prefix.lastIndexOf('/');
    if (lastSlash <= 'https://'.length) return null;
    return prefix.substring(0, lastSlash + 1);
  }

  static String _titleSlug(String slug) {
    return slug
        .split(RegExp(r'[_\-]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  static void _agentLog({
    required String location,
    required String message,
    required String hypothesisId,
    Map<String, Object?> data = const {},
  }) {
    final payload = <String, Object?>{
      'sessionId': _debugSessionId,
      'location': location,
      'message': message,
      'hypothesisId': hypothesisId,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    agentDebugLogToFile(
      sessionId: _debugSessionId,
      fileName: 'debug-f0885a.log',
      location: location,
      message: message,
      hypothesisId: hypothesisId,
      data: Map<String, dynamic>.from(data),
    );
    // Remote debug ingest removed (Phase 8 R04 category-c).
  }
}
