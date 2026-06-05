import '../config/channel_categories.dart';
import '../models/model.dart';
import 'sports_channel_priority.dart';

/// Bottom-nav Live tab: Appwrite catalog streams that are HLS (.m3u8).
class LiveTabChannels {
  LiveTabChannels._();

  static const Set<String> allowedCategories = {'Sports', 'Movies'};

  static bool isM3u8(ChannelModel c) {
    final u = c.streamUrl.trim().toLowerCase();
    return u.isNotEmpty && u.contains('.m3u8');
  }

  static bool isAllowedCategory(String category) =>
      allowedCategories.contains(ChannelCategoryRegistry.normalizeId(category));

  /// Sports + Movies from catalog, m3u8 only, deduped by name|url.
  static List<ChannelModel> filter(List<ChannelModel> catalog) {
    final seen = <String>{};
    final out = <ChannelModel>[];
    for (final c in catalog) {
      if (!isM3u8(c) || !isAllowedCategory(c.category)) continue;
      final key = '${c.name.toLowerCase()}|${c.streamUrl}';
      if (seen.add(key)) out.add(c);
    }
    return out;
  }

  static List<ChannelModel> sports(List<ChannelModel> pool) {
    final list = pool.where((c) => c.category == 'Sports').toList();
    return SportsChannelPriority.sortLiveSports(list);
  }

  static List<ChannelModel> movies(List<ChannelModel> pool) {
    final list = pool.where((c) => c.category == 'Movies').toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
