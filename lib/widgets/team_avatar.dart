import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import '../theme/app_theme.dart';

/// Team crest: network logo, else colored initials + sport hint.
class TeamAvatar extends StatelessWidget {
  final String name;
  final String logoUrl;
  final String sport;
  final double size;

  const TeamAvatar({
    super.key,
    required this.name,
    this.logoUrl = '',
    this.sport = '',
    this.size = 40,
  });

  static const _palette = [
    Color(0xFF2D4A6E),
    Color(0xFF3D5A40),
    Color(0xFF5C3D6E),
    Color(0xFF6E4A2D),
    Color(0xFF2D5C5C),
    Color(0xFF4A3D6E),
  ];

  @override
  Widget build(BuildContext context) {
    final url = logoUrl.trim();
    final radius = size * 0.28;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: context.brd.withValues(alpha: 0.85),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              httpHeaders: const {'User-Agent': 'Mozilla/5.0'},
              placeholder: (_, __) => _initials(context),
              errorWidget: (_, __, ___) => _initials(context),
            )
          : _initials(context),
    );
  }

  Widget _initials(BuildContext context) {
    final label = _initialsLabel(name);
    final bg = _palette[name.hashCode.abs() % _palette.length];
    final sportHint = _sportEmoji(sport);

    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Text(
              label,
              style: GF.head(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1,
              ),
            ),
          ),
          if (sportHint.isNotEmpty)
            Positioned(
              right: 2,
              bottom: 1,
              child: Text(
                sportHint,
                style: TextStyle(fontSize: size * 0.22),
              ),
            ),
        ],
      ),
    );
  }

  static String _initialsLabel(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.length >= 2
          ? w.substring(0, 2).toUpperCase()
          : w[0].toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  static String _sportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'cricket':
        return '🏏';
      case 'football':
        return '⚽';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      default:
        return '';
    }
  }
}
