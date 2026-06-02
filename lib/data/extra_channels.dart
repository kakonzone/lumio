import '../models/model.dart';

/// Channel merge helpers — catalog is loaded from GitHub only.
class ExtraChannels {
  ExtraChannels._();

  static List<ChannelModel> get userChannels => const [];

  static List<ChannelModel> get all => const [];

  static ChannelModel fromMultiLinkPaste(
    String name,
    String category,
    String rawLinks, {
    String id = '',
    String country = 'India',
    int viewers = 2000,
  }) {
    final urls = rawLinks
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) =>
            l.startsWith('http') || l.startsWith('rtmp') || l.startsWith('rtsp'))
        .toList();
    if (urls.isEmpty) {
      return ChannelModel(
        id: id.isEmpty ? 'user_empty' : id,
        name: name,
        category: category,
        country: country,
        streamUrl: '',
      );
    }
    final links = urls
        .map((u) => StreamLink(url: u, label: 'Link'))
        .toList();
    return ChannelModel(
      id: id.isEmpty ? 'user_${name.hashCode}' : id,
      name: name,
      category: category,
      country: country,
      streamUrl: links.first.url,
      isLive: true,
      viewers: viewers,
      currentShow: 'Live',
      alternateStreams: links.length > 1 ? links.sublist(1) : const [],
    );
  }

  static List<ChannelModel> merge(
    List<ChannelModel> base,
    List<ChannelModel> extra,
  ) {
    if (extra.isEmpty) return base;
    if (base.isEmpty) return List<ChannelModel>.from(extra);

    final byKey = <String, ChannelModel>{};
    for (final ch in base) {
      byKey[_mergeKey(ch.name)] = ch;
    }
    for (final ch in extra) {
      final key = _mergeKey(ch.name);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = ch;
      } else {
        byKey[key] = _mergeChannels(existing, ch);
      }
    }
    return byKey.values.toList();
  }

  static String _mergeKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static ChannelModel _mergeChannels(ChannelModel a, ChannelModel b) {
    final seen = <String>{};
    final links = <StreamLink>[];

    void addFrom(ChannelModel ch) {
      for (final link in ch.allStreams) {
        if (link.url.isEmpty || seen.contains(link.url)) continue;
        seen.add(link.url);
        links.add(
          StreamLink(
            url: link.url,
            label: 'Link ${links.length + 1}',
            headers: link.headers,
          ),
        );
      }
    }

    addFrom(a);
    addFrom(b);
    if (links.isEmpty) return a;

    return a.copyWith(
      streamUrl: links.first.url,
      alternateStreams: links.length > 1 ? links.sublist(1) : const [],
      headers: links.first.headers,
    );
  }
}
