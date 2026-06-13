import 'package:flutter/foundation.dart';
import '../models/model.dart';

/// Pending taps and lightweight UI selection state.
class UiStateProvider extends ChangeNotifier {
  String? _pendingChannelTapId;
  String? _pendingNewsArticleId;

  String? get pendingChannelTapId => _pendingChannelTapId;

  bool isPendingChannelTap(String channelKey) =>
      channelKey.isNotEmpty && _pendingChannelTapId == channelKey;

  bool isPendingChannelTapChannel(ChannelModel channel) => isPendingChannelTap(
        channel.id.isNotEmpty ? channel.id : channel.name,
      );

  void setPendingChannelTap(String? channelId) {
    if (_pendingChannelTapId == channelId) return;
    _pendingChannelTapId = channelId;
    notifyListeners();
  }

  bool isPendingNewsArticle(String articleId) =>
      articleId.isNotEmpty && _pendingNewsArticleId == articleId;

  void setPendingNewsArticle(String? articleId) {
    if (_pendingNewsArticleId == articleId) return;
    _pendingNewsArticleId = articleId;
    notifyListeners();
  }
}
