import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ads/ad_manager.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../screens/news_article_reader_screen.dart';
import '../theme/app_theme.dart';
import '../utils/lumio_image_cache.dart';
import '../utils/news_priority.dart';

Future<void> openNewsArticle(NewsModel news, {BuildContext? context}) async {
  await AdManager.instance.maybeMonetizeNewsReadMore();
  if (context != null && context.mounted) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NewsArticleReaderScreen(article: news),
      ),
    );
    return;
  }
  final uri = Uri.tryParse(news.url.trim());
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Large featured story with image + priority badge.
class NewsHeroCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback? onTap;

  const NewsHeroCard({super.key, required this.news, this.onTap});

  List<Color> get _accentGradient {
    if (NewsPriority.isWorldCup(news)) {
      return [const Color(0xFF1565C0), const Color(0xFF0D47A1)];
    }
    if (NewsPriority.isCricket(news)) {
      return [const Color(0xFF00897B), const Color(0xFF004D40)];
    }
    return [AppColors.accent, const Color(0xFFE65100)];
  }

  @override
  Widget build(BuildContext context) {
    final isPending = context.watch<AppProvider>().isPendingNewsArticle(news.id);
    final priority = NewsPriority.priorityLabel(news);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _accentGradient.map((c) => c.withValues(alpha: 0.35)).toList(),
            ),
            border: Border.all(
              color: isPending ? AppColors.accent : Colors.white24,
              width: isPending ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentGradient.first.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 210,
                      width: double.infinity,
                      child: _NewsImage(
                        news: news,
                        fit: BoxFit.cover,
                        memWidth: 720,
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.82),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (priority != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _PriorityBadge(label: priority),
                      ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryChip(
                            label: news.category,
                            accent: _accentGradient.first,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            news.title,
                            style: GF.head(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.22,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (news.summary.isNotEmpty) ...[
                        Text(
                          news.summary,
                          style: GF.body(
                            fontSize: 13,
                            color: context.txt2,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 14, color: context.txt3),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${news.timeAgo} · ${news.source}',
                              style: GF.body(fontSize: 11, color: context.txt3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: _accentGradient),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Headline row — always shows image slot (photo or gradient fallback).
class NewsArticleTile extends StatelessWidget {
  final NewsModel news;
  final VoidCallback? onTap;

  const NewsArticleTile({super.key, required this.news, this.onTap});

  Color get _accent {
    if (NewsPriority.isWorldCup(news)) return const Color(0xFF1976D2);
    if (NewsPriority.isCricket(news)) return const Color(0xFF00897B);
    return AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    final isPending = context.watch<AppProvider>().isPendingNewsArticle(news.id);
    final priority = NewsPriority.priorityLabel(news);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isPending ? AppColors.accentDim : context.bg2,
            border: Border.all(
              color: isPending ? AppColors.accent : context.brd,
              width: isPending ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_accent, _accent.withValues(alpha: 0.4)],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 108,
                            height: 80,
                            child: _NewsImage(
                              news: news,
                              fit: BoxFit.cover,
                              memWidth: 320,
                              accent: _accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _CategoryChip(
                                    label: news.category,
                                    accent: _accent,
                                  ),
                                  if (priority != null) ...[
                                    const SizedBox(width: 6),
                                    _PriorityBadge(
                                      label: priority,
                                      compact: true,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                news.title,
                                style: GF.body(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: context.txt,
                                  height: 1.28,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${news.timeAgo} · ${news.source}',
                                style: GF.body(
                                  fontSize: 10,
                                  color: context.txt3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const _PriorityBadge({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isWc = label.contains('WORLD');
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWc
              ? [const Color(0xFF1976D2), const Color(0xFF0D47A1)]
              : [const Color(0xFF00897B), const Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: (isWc ? Colors.blue : Colors.teal).withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _CategoryChip({required this.label, this.accent = AppColors.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GF.body(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NewsImage extends StatelessWidget {
  final NewsModel news;
  final BoxFit fit;
  final int memWidth;
  final Color? accent;

  const _NewsImage({
    required this.news,
    required this.fit,
    this.memWidth = 400,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (memWidth * dpr).round();

    if (news.imageUrl.isEmpty) {
      final c = accent ?? AppColors.accent;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              c.withValues(alpha: 0.55),
              context.bg3,
            ],
          ),
        ),
        child: Center(
          child: Text(
            news.categoryEmoji,
            style: const TextStyle(fontSize: 36),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: news.imageUrl,
      cacheManager: lumioImageCache,
      fit: fit,
      memCacheWidth: cacheW,
      fadeInDuration: const Duration(milliseconds: 180),
      fadeOutDuration: const Duration(milliseconds: 120),
      placeholder: (_, __) => ColoredBox(
        color: context.bg3,
        child: Center(
          child: Icon(Icons.image_outlined, color: context.txt3, size: 28),
        ),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: context.bg3,
        child: Center(
          child: Text(
            news.categoryEmoji,
            style: const TextStyle(fontSize: 30),
          ),
        ),
      ),
    );
  }
}
