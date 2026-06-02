import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_bootstrap.dart';

/// Stores install attribution from deep links / campaign URLs (World Cup UA).
class AttributionService {
  AttributionService._();
  static final AttributionService instance = AttributionService._();

  static const _kSource = 'attr_utm_source';
  static const _kMedium = 'attr_utm_medium';
  static const _kCampaign = 'attr_utm_campaign';
  static const _kPendingChannel = 'attr_pending_channel_id';
  static const _kPendingTab = 'attr_pending_tab';
  static const _kLogged = 'attr_install_logged';

  String? _pendingChannelId;
  int? _pendingTabIndex;

  String? get pendingChannelId => _pendingChannelId;
  int? get pendingTabIndex => _pendingTabIndex;

  String? consumePendingChannelId() {
    final id = _pendingChannelId;
    _pendingChannelId = null;
    return id;
  }

  int? consumePendingTabIndex() {
    final tab = _pendingTabIndex;
    _pendingTabIndex = null;
    return tab;
  }

  Future<void> handleUri(Uri uri) async {
    final params = uri.queryParameters;
    final source = _first(params, const ['source', 'utm_source', 'src']);
    final medium = _first(params, const ['medium', 'utm_medium']);
    final campaign = _first(params, const ['campaign', 'utm_campaign', 'c']);
    final channelId = _first(params, const ['channel', 'channel_id', 'ch']);
    final tab = _first(params, const ['tab']);

    if (channelId != null && channelId.isNotEmpty) {
      _pendingChannelId = channelId;
    }
    final tabIndex = _tabIndexFromName(tab);
    if (tabIndex != null) _pendingTabIndex = tabIndex;

    final prefs = await SharedPreferences.getInstance();
    var changed = false;
    if (source != null && source.isNotEmpty) {
      await prefs.setString(_kSource, source);
      changed = true;
    }
    if (medium != null && medium.isNotEmpty) {
      await prefs.setString(_kMedium, medium);
      changed = true;
    }
    if (campaign != null && campaign.isNotEmpty) {
      await prefs.setString(_kCampaign, campaign);
      changed = true;
    }
    if (channelId != null && channelId.isNotEmpty) {
      await prefs.setString(_kPendingChannel, channelId);
    }
    if (tabIndex != null) {
      await prefs.setInt(_kPendingTab, tabIndex);
    }

    if (!changed && channelId == null && tabIndex == null) return;

    final alreadyLogged = prefs.getBool(_kLogged) ?? false;
    if (!alreadyLogged && FirebaseBootstrap.isInitialized) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'lumio_install_attribution',
        parameters: {
          if (source != null && source.isNotEmpty) 'utm_source': source,
          if (medium != null && medium.isNotEmpty) 'utm_medium': medium,
          if (campaign != null && campaign.isNotEmpty) 'utm_campaign': campaign,
          if (channelId != null && channelId.isNotEmpty) 'channel_id': channelId,
          'link_host': uri.host,
        },
      );
      await prefs.setBool(_kLogged, true);
    }

    if (kDebugMode) {
      debugPrint(
        '[Attribution] source=$source campaign=$campaign channel=$channelId tab=$tab',
      );
    }
  }

  Future<void> restorePendingFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingChannelId ??= prefs.getString(_kPendingChannel);
    _pendingTabIndex ??= prefs.getInt(_kPendingTab);
  }

  Future<Map<String, String>> storedAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      if (prefs.containsKey(_kSource)) 'utm_source': prefs.getString(_kSource)!,
      if (prefs.containsKey(_kMedium)) 'utm_medium': prefs.getString(_kMedium)!,
      if (prefs.containsKey(_kCampaign))
        'utm_campaign': prefs.getString(_kCampaign)!,
    };
  }

  String? _first(Map<String, String> params, List<String> keys) {
    for (final k in keys) {
      final v = params[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  int? _tabIndexFromName(String? tab) {
    if (tab == null || tab.isEmpty) return null;
    switch (tab.toLowerCase()) {
      case 'home':
      case '0':
        return 0;
      case 'sports':
      case '1':
        return 1;
      case 'live':
      case '2':
        return 2;
      case 'news':
      case '3':
        return 3;
      case 'categories':
      case 'category':
      case '4':
        return 4;
      default:
        return null;
    }
  }
}
