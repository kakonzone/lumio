import '../models/model.dart';
import '../services/special_link/gitun_playlist_service.dart';
import '../utils/channel_catalog.dart';
import '../utils/channel_hub_processor.dart';

/// Channel catalog — loaded only from your GitHub playlist ([SpecialLinkConfig.appCatalogPlaylistUrl]).
class CatalogService {
  CatalogService._();
  static final CatalogService instance = CatalogService._();

  Future<CatalogLoadResult> loadCatalog({bool forceRefresh = false}) async {
    String? error;
    final channels = await GitunPlaylistService.instance.loadAppCatalogChannels(
      forceRefresh: forceRefresh,
    );

    if (channels.isEmpty) {
      error =
          'Could not load channels from your GitHub playlist. Check connection and pull to refresh.';
    }

    final normalized =
        ChannelHubProcessor.expand(ChannelCatalog.normalizeAll(channels));

    return CatalogLoadResult(
      channels: normalized,
      errorMessage: error,
    );
  }
}

class CatalogLoadResult {
  const CatalogLoadResult({
    required this.channels,
    this.errorMessage,
  });

  final List<ChannelModel> channels;
  final String? errorMessage;
}
