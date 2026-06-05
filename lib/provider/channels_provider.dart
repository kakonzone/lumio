import 'package:flutter/foundation.dart';

import '../models/model.dart';
import '../services/appwrite_service.dart';

/// Appwrite catalog channels (same source as home / sports / live).
class ChannelsProvider extends ChangeNotifier {
  List<ChannelModel> _remote = const [];
  bool _loading = false;

  List<ChannelModel> get remoteChannels => List.unmodifiable(_remote);
  bool get loading => _loading;

  Future<void> loadRemote({bool force = false}) async {
    _loading = true;
    notifyListeners();
    try {
      _remote = await AppwriteService.instance.fetchChannels(
        forceRefresh: force,
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
