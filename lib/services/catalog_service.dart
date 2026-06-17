import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../utils/channel_catalog.dart';
import '../utils/stream_url_upgrade.dart';
import '../utils/channel_hub_processor.dart';
import '../utils/priority_broadcasters.dart';
import 'appwrite_service.dart';
import 'remote_channels_service.dart';
import 'special_link/special_link_cache.dart';

/// CPU-heavy catalog normalization — off main isolate when list is large.
List<ChannelModel> normalizeAndExpandCatalogIsolate(List<ChannelModel> raw) {
  var list = ChannelHubProcessor.expand(ChannelCatalog.normalizeAll(raw));
  list = list.map((ch) {
    final primary = ch.streamUrl.trim();
    if (primary.isEmpty) return ch;
    final upgraded = StreamUrlUpgrade.preferHttps(primary);
    if (upgraded == primary) return ch;
    return ch.copyWith(streamUrl: upgraded);
  }).toList();
  return PriorityBroadcasters.sort(list);
}

/// Channel catalog — loaded from Appwrite ([AppwriteService]) for the whole app.
/// Special Link / GITUN uses Appwrite `special_links` ([GitunPlaylistService]).
class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  Future<CatalogLoadResult> loadCatalog({bool forceRefresh = false}) async {
    String? error;
    var fromStaleCache = false;

    // 1. Try RemoteChannelsService (Cloudflare Worker / GitHub M3U)
    var channels = await RemoteChannelsService.fetch(force: forceRefresh);

    // 2. Fallback: NY Appwrite (if remote returns empty)
    if (channels.isEmpty) {
      channels = await AppwriteService.instance.fetchChannels(
        forceRefresh: forceRefresh,
      );
    }

    // 3. Fallback: stale disk cache
    if (channels.isEmpty) {
      final stale = await SpecialLinkCache.instance.readAppCatalogChannels(
        ignoreTtl: true,
      );
      if (stale != null && stale.isNotEmpty) {
        channels = stale;
        fromStaleCache = true;
        error = 'Using cached channel list. Pull to refresh when online.';
      } else {
        error = AppwriteService.instance.lastFetchError ??
            'Could not load channels. Check connection and pull to refresh.';
      }
    }

    // 4. Save to disk cache on success
    if (channels.isNotEmpty && !fromStaleCache) {
      await SpecialLinkCache.instance.writeAppCatalogChannels(channels);
    }

    final List<ChannelModel> normalized;
    if (channels.length >= 200) {
      normalized = await compute(normalizeAndExpandCatalogIsolate, channels);
    } else {
      normalized = normalizeAndExpandCatalogIsolate(channels);
    }

    return CatalogLoadResult(
      channels: normalized,
      errorMessage: error,
      fromStaleCache: fromStaleCache,
    );
  }
}

class CatalogLoadResult {
  const CatalogLoadResult({
    required this.channels,
    this.errorMessage,
    this.fromStaleCache = false,
  });

  final List<ChannelModel> channels;
  final String? errorMessage;
  final bool fromStaleCache;
}
