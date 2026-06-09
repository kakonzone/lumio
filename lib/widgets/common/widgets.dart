import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/model.dart';
import '../../provider/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/channel_list_style.dart';
import '../../theme/tokens/colors.dart';

// ═══════════════════════════════════════════════════════════════
// SCORE CARD — horizontal scroll live match card
// ═══════════════════════════════════════════════════════════════
class ScoreCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  const ScoreCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = match.status == 'live';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.brd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sport label + live/time badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match.sport.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: context.txt3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                _StatusBadge(isLive: live, time: match.time),
              ],
            ),
            const SizedBox(height: 10),
            _teamRow(context, match.teamA, match.scoreA, isLeading: true),
            Divider(height: 10, color: context.brd),
            _teamRow(context, match.teamB, match.scoreB, isLeading: false),
            const SizedBox(height: 8),
            Center(
              child: Text(
                live ? match.time : match.formattedDate,
                style: TextStyle(fontSize: 10, color: context.txt3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamRow(
    BuildContext context,
    String team,
    String score, {
    required bool isLeading,
  }) {
    return Row(
      children: [
        Text(match.sportEmoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            team.isEmpty ? 'TBD' : team,
            style: TextStyle(
              fontSize: 12,
              color: context.txt2,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          score.isEmpty ? '—' : score,
          style: TextStyle(
            fontFamily: 'BarlowCondensed',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color:
                isLeading && score.isNotEmpty ? AppTokens.accent : context.txt,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EVENT CARD — full-width live match row
// ═══════════════════════════════════════════════════════════════
class EventCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onPlay;
  const EventCard({super.key, required this.match, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final live = match.status == 'live';
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.brd),
        ),
        child: Row(
          children: [
            // Sport icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  match.sportEmoji,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Match info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.teamB.isEmpty
                        ? match.teamA
                        : '${match.teamA}  vs  ${match.teamB}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.txt,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${match.channel.isEmpty ? match.sport : match.channel}'
                    ' • ${match.time}',
                    style: TextStyle(fontSize: 11, color: context.txt3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right side: live badge + play button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (live) _LiveDot(),
                const SizedBox(height: 6),
                if (match.streamUrl.isNotEmpty)
                  _PlayCircle(onTap: onPlay)
                else
                  _UpcomingBadge(time: match.time),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHANNEL CARD — full-width channel list row
// ═══════════════════════════════════════════════════════════════
class ChannelCard extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback? onPlay;
  const ChannelCard({super.key, required this.channel, this.onPlay});

  @override
  Widget build(BuildContext context) {
    final showLive = context.watch<AppProvider>().isStreamLive(channel);
    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: ChannelListStyle.card(
          context: context,
          showLive: showLive,
          isPendingTap: false,
        ),
        child: Row(
          children: [
            // Logo or emoji fallback
            _ChannelLogo(
              logoUrl: channel.logoUrl,
              category: channel.category,
            ),
            const SizedBox(width: 12),
            // Channel name + show
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.txt,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    channel.currentShow.isEmpty
                        ? channel.category
                        : channel.currentShow,
                    style: TextStyle(fontSize: 11, color: context.txt3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Live badge + viewer count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showLive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: ChannelListStyle.liveBadge(),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                if (showLive) const SizedBox(height: 4),
                Text(
                  channel.formattedViewers,
                  style: TextStyle(fontSize: 10, color: context.txt3),
                ),
              ],
            ),
            const SizedBox(width: 8),
            _PlayCircle(onTap: onPlay, size: 26, iconSize: 14),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREDICTION CARD — win-chance bar card
// ═══════════════════════════════════════════════════════════════
class PredictionCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  const PredictionCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final live = match.status == 'live';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 204,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.brd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sport + status label
            Text(
              '${match.sport} • ${live ? "LIVE" : "UPCOMING"}'.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: live ? AppTokens.accent : context.txt3,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 10),
            // Teams
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _PredTeam(name: match.teamA, emoji: match.sportEmoji),
                Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.txt3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _PredTeam(name: match.teamB, emoji: match.sportEmoji),
              ],
            ),
            const SizedBox(height: 10),
            // Win-chance bar
            _WinChanceBar(
              chanceA: match.winChanceA,
              draw: match.drawChance,
              chanceB: match.winChanceB,
              context: context,
            ),
            const SizedBox(height: 6),
            // Percentage labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${match.winChanceA.toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.accent,
                  ),
                ),
                Text(
                  'Draw ${match.drawChance.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.txt3,
                  ),
                ),
                Text(
                  '${match.winChanceB.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// NEWS CARD — article card with emoji banner
// ═══════════════════════════════════════════════════════════════
class NewsCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback? onTap;
  const NewsCard({super.key, required this.news, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.brd),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner — image or emoji fallback
            news.imageUrl.isNotEmpty
                ? Image.network(
                    news.imageUrl,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _NewsBanner(news: news),
                  )
                : _NewsBanner(news: news),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.accent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    news.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.txt,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${news.timeAgo} • ${news.source}',
                    style: TextStyle(fontSize: 11, color: context.txt3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CATEGORY FILTER CHIP ROW
// ═══════════════════════════════════════════════════════════════
class CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppTokens.accent : context.bg2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppTokens.accent : context.brd,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : context.txt2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'BarlowCondensed',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.txt3,
              letterSpacing: 1.5,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LIVE BADGE (standalone pill)
// ═══════════════════════════════════════════════════════════════
class LiveBadge extends StatelessWidget {
  final String label;
  final Color? color;
  const LiveBadge({super.key, this.label = '● LIVE', this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? AppTokens.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHIMMER SKELETONS
// ═══════════════════════════════════════════════════════════════

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:
          context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor:
          context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ChannelCardShimmer extends StatelessWidget {
  const ChannelCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:
          context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor:
          context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Container(height: 11, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreCardShimmer extends StatelessWidget {
  const ScoreCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:
          context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor:
          context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        width: 172,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 10, width: 80, color: Colors.white),
            const SizedBox(height: 14),
            Container(height: 12, width: double.infinity, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 12, width: double.infinity, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 10, width: 60, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class NewsCardShimmer extends StatelessWidget {
  const NewsCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:
          context.isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
      highlightColor:
          context.isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              height: 110,
              width: double.infinity,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 10, width: 60, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(
                    height: 13,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 4),
                  Container(height: 13, width: 200, color: Colors.white),
                  const SizedBox(height: 6),
                  Container(height: 11, width: 100, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ERROR STATE VIEW
// ═══════════════════════════════════════════════════════════════
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: context.txt3,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.txt,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.txt3, height: 1.5),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE VIEW
// ═══════════════════════════════════════════════════════════════
class EmptyView extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  const EmptyView({
    super.key,
    this.emoji = '📭',
    required this.title,
    this.subtitle = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.txt,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: context.txt3, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════
class LumioSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const LumioSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search channels…',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.bg2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.brd),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 18, color: context.txt3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: context.txt),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: context.txt3),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                onClear?.call();
                onChanged?.call('');
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.close_rounded, size: 16, color: context.txt3),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIVATE HELPERS (internal to this file)
// ═══════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final bool isLive;
  final String time;
  const _StatusBadge({required this.isLive, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isLive ? AppTokens.accentDim : context.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isLive ? '● LIVE' : time,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isLive ? AppTokens.accent : context.txt3,
        ),
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTokens.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTokens.accent,
            ),
          ),
        ],
      );
}

class _PlayCircle extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  const _PlayCircle({this.onTap, this.size = 28, this.iconSize = 16});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppTokens.accent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
        ),
      );
}

class _UpcomingBadge extends StatelessWidget {
  final String time;
  const _UpcomingBadge({required this.time});

  @override
  Widget build(BuildContext context) => Text(
        time,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.txt3,
        ),
      );
}

class _ChannelLogo extends StatelessWidget {
  final String logoUrl;
  final String category;
  const _ChannelLogo({required this.logoUrl, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.bg3,
        borderRadius: BorderRadius.circular(10),
      ),
      child: logoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    _catEmoji(category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                _catEmoji(category),
                style: const TextStyle(fontSize: 20),
              ),
            ),
    );
  }

  String _catEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'sports':
        return '🏆';
      case 'bangladesh':
        return '🇧🇩';
      case 'india':
        return '🇮🇳';
      case 'pakistan':
        return '🇵🇰';
      case 'english':
        return '🌍';
      case 'hindi':
        return '📺';
      case 'movies':
        return '🎬';
      case 'kdrama':
        return '🇰🇷';
      case 'kids':
        return '🧒';
      case 'entertainment':
        return '🎭';
      default:
        return '📡';
    }
  }
}

class _NewsBanner extends StatelessWidget {
  final NewsModel news;
  const _NewsBanner({required this.news});

  @override
  Widget build(BuildContext context) => Container(
        height: 110,
        width: double.infinity,
        color: context.bg3,
        child: Center(
          child: Text(
            news.categoryEmoji,
            style: const TextStyle(fontSize: 40),
          ),
        ),
      );
}

class _PredTeam extends StatelessWidget {
  final String name;
  final String emoji;
  const _PredTeam({required this.name, required this.emoji});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            name.length > 8 ? '${name.substring(0, 7)}…' : name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.txt2,
            ),
          ),
        ],
      );
}

class _WinChanceBar extends StatelessWidget {
  final double chanceA;
  final double draw;
  final double chanceB;
  final BuildContext context;
  const _WinChanceBar({
    required this.chanceA,
    required this.draw,
    required this.chanceB,
    required this.context,
  });

  @override
  Widget build(BuildContext _) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: [
            Expanded(
              flex: chanceA.toInt().clamp(1, 100),
              child: Container(height: 6, color: AppTokens.accent),
            ),
            if (draw > 0)
              Expanded(
                flex: draw.toInt().clamp(1, 100),
                child: Container(height: 6, color: context.bg3),
              ),
            Expanded(
              flex: chanceB.toInt().clamp(1, 100),
              child: Container(height: 6, color: AppTokens.success),
            ),
          ],
        ),
      );
}

