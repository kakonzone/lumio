import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../screens/player_screen.dart';

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
