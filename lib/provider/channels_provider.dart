import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../services/special_link/gitun_playlist_service.dart';

/// Your GitHub catalog channels (same source as home / sports / live).
class ChannelsProvider extends ChangeNotifier {
  List<ChannelModel> _remote = const [];
  bool _loading = false;

  List<ChannelModel> get remoteChannels => List.unmodifiable(_remote);
  bool get loading => _loading;

  Future<void> loadRemote({bool force = false}) async {
    _loading = true;
    notifyListeners();
    try {
      _remote = await GitunPlaylistService.instance.loadAppCatalogChannels(
        forceRefresh: force,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
