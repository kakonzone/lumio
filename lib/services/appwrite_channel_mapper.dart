import 'dart:convert';

import 'package:dart_appwrite/models.dart' as aw_models;

import '../config/channel_categories.dart';
import '../models/model.dart';
import '../utils/channel_playback_links.dart';

/// Maps Appwrite `channels` rows → [ChannelModel] (multi-link aware).
class AppwriteChannelMapper {
  AppwriteChannelMapper._();

  /// Prefix on [ChannelModel.hubGroupId] for same-logical-channel grouping in player.
  static const mergeGroupPrefix = 'merge_';

  static ChannelModel? fromDocument(aw_models.Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    final name = _str(data, const [
      'name',
      'title',
      'channelName',
      'channel_name',
      'tvgName',
      'tvg-name',
    ]);
    if (name.isEmpty) return null;

    final group = _str(data, const [
      'group',
      'groupTitle',
      'group_title',
      'group-title',
      'currentShow',
    ]);

    var category = _str(data, const ['category', 'genre', 'type']);
    if (category.isEmpty) {
      category = ChannelCategoryRegistry.fromGroupTitle(group, name);
    } else {
      category = ChannelCategoryRegistry.normalizeId(category);
    }

    final country = _str(data, const ['country', 'region', 'language']);
    final logo =
        _str(data, const ['logo', 'logoUrl', 'logo_url', 'tvgLogo', 'icon']);

    final linkEntries = _collectLinkEntries(data);
    if (linkEntries.isEmpty) return null;

    final alts = <StreamLink>[];
    for (var i = 1; i < linkEntries.length; i++) {
      alts.add(linkEntries[i]);
    }

    final mergeKey = catalogMergeKey(data, name);

    return ChannelModel(
      id: doc.$id.isNotEmpty ? doc.$id : 'appwrite_${name.hashCode}',
      name: name,
      category: category,
      country: country.isNotEmpty ? country : 'International',
      streamUrl: linkEntries.first.url,
      logoUrl: logo,
      isLive: true,
      currentShow: group,
      alternateStreams: alts,
      hubGroupId: mergeKey.isNotEmpty ? '$mergeGroupPrefix$mergeKey' : null,
    );
  }

  /// Key used when merging rows + player multi-link bar.
  static String catalogMergeKey(Map<String, dynamic> data, String name) {
    final explicit = _str(data, const [
      'mergeKey',
      'merge_key',
      'channelKey',
      'channel_key',
      'channelId',
      'channel_id',
      'groupKey',
      'group_key',
      'slug',
    ]);
    if (explicit.isNotEmpty) {
      return explicit.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return ChannelPlaybackLinks.mergeKeyForName(name);
  }

  static String? playlistBody(Map<String, dynamic> data) {
    for (final key in const [
      'm3u',
      'm3u8',
      'playlist',
      'playlistBody',
      'content',
      'body',
      'data',
    ]) {
      final raw = data[key];
      if (raw is String && raw.trim().isNotEmpty) return raw;
    }
    return null;
  }

  static ChannelModel mergeRows(ChannelModel a, ChannelModel b) {
    final seen = <String>{};
    final links = <StreamLink>[];

    void addFrom(ChannelModel ch) {
      for (final link in ch.userStreamLinks) {
        if (link.url.isEmpty || seen.contains(link.url)) continue;
        seen.add(link.url);
        links.add(
          StreamLink(
            url: link.url,
            label:
                link.label.trim().isNotEmpty && link.label.toLowerCase() != 'sd'
                    ? link.label
                    : 'Link ${links.length + 1}',
            headers: link.headers.isNotEmpty ? link.headers : ch.headers,
          ),
        );
      }
    }

    addFrom(a);
    addFrom(b);

    if (links.isEmpty) return a;

    final mergeKey = _pickMergeKey(a, b);

    return a.copyWith(
      streamUrl: links.first.url,
      alternateStreams: links.length > 1 ? links.sublist(1) : const [],
      logoUrl: a.logoUrl.isNotEmpty ? a.logoUrl : b.logoUrl,
      headers: links.first.headers,
      isLive: true,
      hubGroupId:
          mergeKey.isNotEmpty ? '$mergeGroupPrefix$mergeKey' : a.hubGroupId,
    );
  }

  static String _pickMergeKey(ChannelModel a, ChannelModel b) {
    final ka = _hubMergeKey(a.hubGroupId);
    final kb = _hubMergeKey(b.hubGroupId);
    if (ka.isNotEmpty) return ka;
    if (kb.isNotEmpty) return kb;
    return ChannelPlaybackLinks.mergeKeyForName(a.name);
  }

  static String _hubMergeKey(String? hubGroupId) {
    if (hubGroupId == null || !hubGroupId.startsWith(mergeGroupPrefix)) {
      return '';
    }
    return hubGroupId.substring(mergeGroupPrefix.length);
  }

  static List<StreamLink> _collectLinkEntries(Map<String, dynamic> data) {
    final seen = <String>{};
    final out = <StreamLink>[];

    void add(String? url, {String? label}) {
      final u = (url ?? '').trim();
      if (u.isEmpty || seen.contains(u)) return;
      seen.add(u);
      out.add(
        StreamLink(
          url: u,
          label: label?.trim().isNotEmpty == true
              ? label!.trim()
              : 'Link ${out.length + 1}',
        ),
      );
    }

    add(
      _str(data, const ['streamUrl', 'stream_url', 'url', 'link', 'src']),
      label: _str(data, const ['label', 'linkLabel', 'stream_label']),
    );

    for (var i = 2; i <= 12; i++) {
      add(
        _str(data, [
          'streamUrl$i',
          'stream_url$i',
          'url$i',
          'link$i',
          'backupUrl$i',
          'backup_url$i',
        ]),
        label: _str(data, ['label$i', 'linkLabel$i']),
      );
    }

    add(
      _str(data, const ['streamUrl2', 'backupUrl', 'backup_url', 'altUrl']),
      label: _str(data, const ['backupLabel', 'altLabel']),
    );

    _parseLinkList(
        data['alternateStreams'] ??
            data['alternate_streams'] ??
            data['links'] ??
            data['streams'],
        add);
    _parseLinkList(data['urls'], add);

    final linksJson = data['linksJson'] ?? data['links_json'];
    if (linksJson is String) {
      _parseLinkList(linksJson, add);
    }

    return out;
  }

  static void _parseLinkList(
    dynamic raw,
    void Function(String? url, {String? label}) add,
  ) {
    if (raw == null) return;

    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is String) {
      final s = raw.trim();
      if (!s.contains('http')) return;
      try {
        final decoded = jsonDecode(s);
        if (decoded is! List) return;
        list = decoded;
      } catch (_) {
        for (final part in s.split(RegExp(r'[\n,;]'))) {
          add(part.trim());
        }
        return;
      }
    } else {
      return;
    }

    for (final item in list) {
      if (item is String) {
        add(item);
      } else if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        add(
          map['url'] as String? ??
              map['streamUrl'] as String? ??
              map['stream_url'] as String?,
          label: map['label'] as String? ?? map['name'] as String?,
        );
      }
    }
  }

  static String _str(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}
