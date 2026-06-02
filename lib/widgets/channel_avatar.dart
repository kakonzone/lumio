import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/model.dart';
import '../utils/lumio_image_cache.dart';
import '../utils/sport_channel_icons.dart';

/// Channel thumbnail: sport icons, network logo, or emoji fallback.
class ChannelAvatar extends StatelessWidget {
  final ChannelModel channel;
  final double size;
  final double borderRadius;
  final String? emojiFallback;

  const ChannelAvatar({
    super.key,
    required this.channel,
    this.size = 44,
    this.borderRadius = 10,
    this.emojiFallback,
  });

  @override
  Widget build(BuildContext context) {
    final sportAsset = SportChannelIcons.assetFor(channel);
    final logo = channel.logoUrl.trim();

    Widget child;
    if (sportAsset != null) {
      child = Image.asset(
        sportAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _emoji(emojiFallback ?? '⚽'),
      );
    } else if (logo.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: logo,
        cacheManager: lumioImageCache,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _emoji(emojiFallback ?? '📺'),
        errorWidget: (_, __, ___) => _emoji(emojiFallback ?? '📺'),
      );
    } else {
      child = _emoji(emojiFallback ?? _categoryEmoji(channel));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  static String _categoryEmoji(ChannelModel channel) {
    switch (channel.category.toLowerCase()) {
      case 'sports':
        return '⚽';
      case 'bangladesh':
      case 'bangla':
        return '🇧🇩';
      case 'movies':
        return '🎬';
      case 'hindi':
        return '🇮🇳';
      case 'english':
        return '🇬🇧';
      default:
        return '📺';
    }
  }

  Widget _emoji(String e) => Container(
        color: const Color(0xFF1A2332),
        alignment: Alignment.center,
        child: Text(e, style: TextStyle(fontSize: size * 0.45)),
      );
}

/// Sport grid tile icon (Cricket / Football categories on Sports screen).
class SportTypeIcon extends StatelessWidget {
  final String sportName;
  final double size;

  const SportTypeIcon({
    super.key,
    required this.sportName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final asset = SportChannelIcons.assetForSportName(sportName);
    if (asset == null) {
      return Text(
        sportName == 'Cricket' ? '🏏' : '⚽',
        style: TextStyle(fontSize: size * 0.65),
      );
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
