import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ads/ad_manager.dart';
import 'ad_debug_log.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../screens/player_screen.dart';
import 'channel_tap_key.dart';

String? _lastChannelTapKey;
DateTime? _lastChannelTapAt;

/// Opens [PlayerScreen] with multi-link support when channel has backups.
void openChannelPlayer(
  BuildContext context, {
  required ChannelModel channel,
  String? subtitle,
  /// Category list the user browsed from (e.g. Bangla → filters Bangladesh).
  String? browseCategory,
  /// Open a specific backup link (live-event popup per-link tap).
  String? initialStreamUrl,
}) {
  final links = channel.allStreams;
  if (links.isEmpty || links.first.url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('এই channel এর stream link নেই'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  final startUrl = initialStreamUrl != null && initialStreamUrl.isNotEmpty
      ? initialStreamUrl
      : links.first.url;
  final startLink = links.firstWhere(
    (l) => l.url == startUrl,
    orElse: () => links.first,
  );

  final prov = context.read<AppProvider>();
  final relatedCategory =
      prov.categoryForRelated(channel, browseCategory: browseCategory);
  final related = prov.recommendedChannels(
    excludeStreamUrl: startUrl,
    category: relatedCategory,
  );
  final moreChannels = prov.playerRelatedChannels(
    currentTitle: channel.name,
    currentUrl: startUrl,
    relatedCategory: relatedCategory,
    fallback: related,
  );
  unawaited(
    prov.ensureStreamHealth(moreChannels, priority: true),
  );

  void pushPlayer() {
    // #region agent log
    adDebugLog(
      location: 'channel_player.dart:pushPlayer',
      message: 'navigator push PlayerScreen',
      hypothesisId: 'H-player-open',
      data: {
        'channel': channel.name,
        'channelId': channel.id,
      },
    );
    // #endregion
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: startUrl,
          title: channel.name,
          subtitle: subtitle ?? channel.currentShow,
          category: relatedCategory,
          headers: startLink.headers,
          streamLinks: links,
          relatedChannels: moreChannels,
        ),
      ),
    );
  }

  unawaited(_runChannelTapWithAds(
    context,
    channel: channel,
    onPlay: pushPlayer,
  ));
}

Future<void> _runChannelTapWithAds(
  BuildContext context, {
  required ChannelModel channel,
  required VoidCallback onPlay,
}) async {
  final key = channelTapKey(channel);
  final now = DateTime.now();
  if (_lastChannelTapKey == key &&
      _lastChannelTapAt != null &&
      now.difference(_lastChannelTapAt!) < const Duration(milliseconds: 700)) {
    return;
  }
  _lastChannelTapKey = key;
  _lastChannelTapAt = now;

  final prov = context.read<AppProvider>();
  prov.setPendingChannelTap(key);

  final result = await AdManager.instance.handleChannelTap(
    context: context,
    channel: channel,
    onPlay: () async {
      prov.setPendingChannelTap(null);
      onPlay();
    },
  );
  if (!context.mounted) return;
  if (result.played) {
    prov.setPendingChannelTap(null);
    return;
  }
  if (!result.showTapAgainHint) {
    prov.setPendingChannelTap(null);
  }
}

/// Opens player from a raw URL; resolves [ChannelModel] for multi-links.
void openStreamPlayer(
  BuildContext context, {
  required String url,
  required String title,
  String subtitle = '',
  String category = '',
  List<ChannelModel>? related,
}) {
  if (url.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('এই channel এর stream link নেই'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }

  final prov = context.read<AppProvider>();
  final channel =
      prov.channelForStream(url) ?? prov.findChannel(name: title);
  final relatedCategory = channel != null
      ? prov.categoryForRelated(
          channel,
          browseCategory: category.isNotEmpty ? category : null,
        )
      : (category.isNotEmpty ? category : null);
  final links = channel?.allStreams ??
      [
        StreamLink(
          url: url,
          label: 'Link 1',
          headers: channel?.headers ?? const {'User-Agent': 'Mozilla/5.0'},
        ),
      ];

  final relatedList = related ??
      prov.recommendedChannels(
        excludeStreamUrl: url,
        category: relatedCategory,
      );
  final moreChannels = prov.playerRelatedChannels(
    currentTitle: title,
    currentUrl: url,
    relatedCategory: relatedCategory ?? channel?.category ?? category,
    fallback: relatedList,
  );
  unawaited(
    prov.ensureStreamHealth(moreChannels, priority: true),
  );

  void pushPlayer() {
    // #region agent log
    adDebugLog(
      location: 'channel_player.dart:pushPlayer',
      message: 'navigator push PlayerScreen',
      hypothesisId: 'H-player-open',
      data: {
        'channel': channel?.name ?? title,
        'channelId': channel?.id ?? '',
      },
    );
    // #endregion
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: links.first.url,
          title: title,
          subtitle: subtitle,
          category: relatedCategory ?? channel?.category ?? category,
          headers: links.first.headers,
          streamLinks: links,
          relatedChannels: moreChannels,
        ),
      ),
    );
  }

  if (channel != null) {
    unawaited(_runChannelTapWithAds(
      context,
      channel: channel,
      onPlay: pushPlayer,
    ));
  } else {
    unawaited(
      AdManager.instance.handleChannelTap(
        context: context,
        channel: ChannelModel(
          id: title,
          name: title,
          category: category,
          country: '',
          streamUrl: url,
        ),
        onPlay: () async => pushPlayer(),
      ),
    );
  }
}
