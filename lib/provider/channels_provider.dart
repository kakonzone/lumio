import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../services/catalog_service.dart';

/// Channel catalog (same source as home / sports / live via CatalogService).
/// Routes through CatalogService which uses RemoteChannelsService as primary source.
class ChannelsProvider extends ChangeNotifier {
  List<ChannelModel> _remote = const [];
  bool _loading = false;
  bool _isDisposed = false;

  List<ChannelModel> get remoteChannels => List.unmodifiable(_remote);
  bool get loading => _loading;

  Future<void> loadRemote({bool force = false}) async {
    _loading = true;
    if (!_isDisposed) notifyListeners();
    try {
      final result = await CatalogService.instance.loadCatalog(forceRefresh: force);
      _remote = result.channels;
    } finally {
      _loading = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
