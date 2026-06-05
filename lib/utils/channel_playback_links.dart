import '../models/model.dart';
import '../services/appwrite_channel_mapper.dart';
import 'channel_name_normalizer.dart';

/// Resolves every stream the user should see in the player link bar.
class ChannelPlaybackLinks {
  ChannelPlaybackLinks._();

  /// Hub parent + all children, or merged M3U alternates on one row.
  static List<StreamLink> resolve(
    ChannelModel channel,
    List<ChannelModel> catalog,
  ) {
    if (channel.isHubParent) {
      return _hubFamilyLinks(channel, catalog);
    }

    if (_isAppwriteMergeGroup(channel.hubGroupId)) {
      final grouped = _appwriteMergeGroupLinks(channel, catalog);
      if (grouped.length > 1) return grouped;
    }

    final own = channel.userStreamLinks;
    if (own.length > 1) return own;

    final peers = _peersWithSameMergeKey(channel, catalog);
    if (peers.length > 1) {
      return _mergeLinksFromChannels(peers);
    }

    return own;
  }

  static int count(ChannelModel channel, List<ChannelModel> catalog) =>
      resolve(channel, catalog).length;

  static bool hasMultiple(ChannelModel channel, List<ChannelModel> catalog) =>
      count(channel, catalog) > 1;

  /// M3U import: merge rows that share the same broadcaster (T Sports / T Sports HD).
  static String mergeKeyForName(String name) => _mergeKey(name);

  static bool _isAppwriteMergeGroup(String? hubGroupId) =>
      hubGroupId != null &&
      hubGroupId.startsWith(AppwriteChannelMapper.mergeGroupPrefix);

  /// Same [mergeKey] / [channelKey] in Appwrite → one player link bar.
  static List<StreamLink> _appwriteMergeGroupLinks(
    ChannelModel channel,
    List<ChannelModel> catalog,
  ) {
    final groupId = channel.hubGroupId;
    if (groupId == null || groupId.isEmpty) return channel.userStreamLinks;

    final members = catalog
        .where(
          (c) =>
              c.hubGroupId == groupId &&
              !c.isHubParent &&
              c.streamUrl.isNotEmpty,
        )
        .toList();
    if (members.length <= 1) return channel.userStreamLinks;
    return _mergeLinksFromChannels(members);
  }

  static List<StreamLink> _hubFamilyLinks(
    ChannelModel hub,
    List<ChannelModel> catalog,
  ) {
    final members = <ChannelModel>[hub];
    for (final ch in catalog) {
      if (ch.hubGroupId == hub.id && !ch.isHubParent && ch.streamUrl.isNotEmpty) {
        members.add(ch);
      }
    }
    return _mergeLinksFromChannels(members);
  }

  /// Same broadcaster name variants in the catalog (e.g. T Sports / T Sports HD).
  static List<ChannelModel> _peersWithSameMergeKey(
    ChannelModel channel,
    List<ChannelModel> catalog,
  ) {
    final key = _mergeKey(channel.name);
    final groupId = channel.hubGroupId;
    if (key.isEmpty && !_isAppwriteMergeGroup(groupId)) return [channel];

    final out = <ChannelModel>[];
    for (final ch in catalog) {
      if (ch.streamUrl.isEmpty || ch.isHubParent) continue;
      if (_isAppwriteMergeGroup(groupId) &&
          ch.hubGroupId == groupId) {
        out.add(ch);
        continue;
      }
      if (_mergeKey(ch.name) == key) out.add(ch);
    }
    return out.isEmpty ? [channel] : out;
  }

  static String _mergeKey(String name) {
    var s = ChannelNameNormalizer.clean(name).toLowerCase();
    s = s.replaceAll(RegExp(r'[+_|]'), ' ');
    s = s
        .replaceAll(
          RegExp(r'\b(hd|fhd|sd|4k|uhd|hevc|live)\b'),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (RegExp(r't\s*sports?|tsports').hasMatch(s)) return 't sports';
    if (RegExp(r'^btv\b|bangladesh television').hasMatch(s)) return 'btv';
    if (s.contains('fifa')) return 'fifa';
    if (RegExp(r'bein\s*sport|bein\s*\d|beinsport').hasMatch(s)) {
      return s.replaceAll(RegExp(r'\s+'), ' ');
    }
    return s;
  }

  static List<StreamLink> _mergeLinksFromChannels(List<ChannelModel> channels) {
    final seen = <String>{};
    final out = <StreamLink>[];

    for (final ch in channels) {
      for (final link in ch.userStreamLinks) {
        if (link.url.isEmpty || seen.contains(link.url)) continue;
        seen.add(link.url);
        final label = _labelForMergedLink(ch, link, out.length);
        out.add(
          StreamLink(
            url: link.url,
            label: label,
            headers: link.headers.isNotEmpty ? link.headers : ch.headers,
          ),
        );
      }
    }
    return out;
  }

  static String _labelForMergedLink(
    ChannelModel ch,
    StreamLink link,
    int index,
  ) {
    if (!ch.isHubParent &&
        link.label.trim().isNotEmpty &&
        link.label.toLowerCase() != 'sd' &&
        !link.label.toLowerCase().startsWith('link ')) {
      return link.label;
    }
    if (!ch.isHubParent && ch.name.trim().isNotEmpty) {
      return ch.name;
    }
    return 'Link ${index + 1}';
  }
}
