import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ads/ad_manager.dart';
import 'ad_debug_log.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../screens/player_screen.dart';
import '../services/ad_trigger_manager.dart';
import '../services/channel_resolver.dart';
import 'channel_tap_key.dart';

String? _lastChannelTapKey;
DateTime? _lastChannelTapAt;

/// Opens [PlayerScreen] with multi-link support when channel has backups.
Future<void> openChannelPlayer(
  BuildContext context, {
  required ChannelModel channel,
  String? subtitle,
  /// Category list the user browsed from (e.g. Bangla → filters Bangladesh).
  String? browseCategory,
  /// Open a specific backup link (live-event popup per-link tap).
  String? initialStreamUrl,
}) async {
  final prov = context.read<AppProvider>();
  final links = prov.playbackLinksFor(channel);
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

  final relatedCategory =
      prov.categoryForRelated(channel, browseCategory: browseCategory);
  final isGitun = relatedCategory == 'GITUN';

  Future<void> pushPlayer() async {
    if (isGitun) {
      await prov.ensureGitunChannelsLoaded();
      if (!context.mounted) return;
    }
    var startUrl = initialStreamUrl != null && initialStreamUrl.isNotEmpty
        ? initialStreamUrl
        : links.first.url;

    final resolution = await ChannelResolver.instance.resolveForPlayback(
      channel: channel,
      embeddedUrl: startUrl,
      tokenTimeout: const Duration(seconds: 2),
    );
    if (!context.mounted) return;
    startUrl = resolution.url;
    final startLink = links.firstWhere(
      (l) => l.url == startUrl,
      orElse: () => links.first,
    );

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
    final related = isGitun
        ? prov.gitunRelatedChannels(
            currentTitle: channel.name,
            currentUrl: startUrl,
          )
        : null;

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
          relatedChannels: related,
        ),
      ),
    );
  }

  await _runChannelTapWithAds(
    context,
    channel: channel,
    onPlay: pushPlayer,
  );
}

Future<void> _runChannelTapWithAds(
  BuildContext context, {
  required ChannelModel channel,
  required Future<void> Function() onPlay,
}) async {
  final key = channelTapKey(channel);
  final readyForPlayer =
      AdTriggerManager.instance.hasChannelTapBrowserShown(key);

  // Debounce only duplicate first-tap spam — never block the 2nd "play" tap.
  if (!readyForPlayer) {
    final now = DateTime.now();
    if (_lastChannelTapKey == key &&
        _lastChannelTapAt != null &&
        now.difference(_lastChannelTapAt!) <
            const Duration(milliseconds: 400)) {
      return;
    }
    _lastChannelTapKey = key;
    _lastChannelTapAt = now;
  }

  final prov = context.read<AppProvider>();
  if (!readyForPlayer) {
    prov.setPendingChannelTap(key);
  }

  final result = await AdManager.instance.handleChannelTap(
    context: context,
    channel: channel,
    onPlay: () async {
      prov.setPendingChannelTap(null);
      await onPlay();
    },
  );
  if (!context.mounted) return;
  if (result.played) {
    prov.setPendingChannelTap(null);
    return;
  }
  if (result.showTapAgainHint) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tap again to watch'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  prov.setPendingChannelTap(null);
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
  var links = channel != null
      ? List<StreamLink>.from(prov.playbackLinksFor(channel))
      : <StreamLink>[
          StreamLink(
            url: url,
            label: 'Link 1',
            headers: const {'User-Agent': 'Mozilla/5.0'},
          ),
        ];
  if (links.isEmpty || links.every((l) => l.url.isEmpty)) {
    links = [
      StreamLink(
        url: url,
        label: 'Link 1',
        headers: channel?.headers ?? const {'User-Agent': 'Mozilla/5.0'},
      ),
    ];
  }

  Future<void> pushPlayer() async {
    var playUrl = links.first.url;
    if (channel != null) {
      final resolution = await ChannelResolver.instance.resolveForPlayback(
        channel: channel,
        embeddedUrl: playUrl,
        tokenTimeout: const Duration(seconds: 2),
      );
      if (!context.mounted) return;
      playUrl = resolution.url;
    }

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
          streamUrl: playUrl,
          title: title,
          subtitle: subtitle,
          category: relatedCategory ?? channel?.category ?? category,
          headers: links.first.headers,
          streamLinks: links,
          relatedChannels: null,
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
        onPlay: pushPlayer,
      ),
    );
  }
}
