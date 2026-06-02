import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/special_link_config.dart';
import '../../models/model.dart';

/// Disk cache for GitHub playlist channel lists.
class SpecialLinkCache {
  SpecialLinkCache._();
  static final SpecialLinkCache instance = SpecialLinkCache._();

  static const _appCatalogBodyKey = 'lumio_app_catalog_channels_v1';
  static const _appCatalogTsKey = 'lumio_app_catalog_ts_v1';
  static const _gitunBodyKey = 'lumio_special_gitun_channels_v4_sports';
  static const _gitunTsKey = 'lumio_special_gitun_ts_v4_sports';

  Future<List<ChannelModel>?> readAppCatalogChannels() =>
      _read(_appCatalogBodyKey, _appCatalogTsKey);

  Future<void> writeAppCatalogChannels(List<ChannelModel> channels) =>
      _write(_appCatalogBodyKey, _appCatalogTsKey, channels);

  Future<List<ChannelModel>?> readGitunChannels() =>
      _read(_gitunBodyKey, _gitunTsKey);

  Future<void> writeGitunChannels(List<ChannelModel> channels) =>
      _write(_gitunBodyKey, _gitunTsKey, channels);

  Future<List<ChannelModel>?> _read(String bodyKey, String tsKey) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(tsKey);
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > SpecialLinkConfig.gitunCacheTtl.inMilliseconds) return null;

    final raw = prefs.getString(bodyKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChannelModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.streamUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(
    String bodyKey,
    String tsKey,
    List<ChannelModel> channels,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = channels.map((c) => c.toJson()).toList();
    await prefs.setString(bodyKey, jsonEncode(payload));
    await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
  }
}
