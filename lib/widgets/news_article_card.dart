import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/model.dart';
import '../provider/app_provider.dart';
import '../theme/app_theme.dart';

Future<void> openNewsArticle(NewsModel news) async {
  final uri = Uri.tryParse(news.url.trim());
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Large featured story (ESPN / BBC).
class NewsHeroCard extends StatelessWidget {
  final NewsModel news;
  final VoidCallback? onTap;

  const NewsHeroCard({super.key, required this.news, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPending = context.watch<AppProvider>().isPendingNewsArticle(news.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPending ? AppColors.accent : context.brd,
                width: isPending ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.shadowColor,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: _NewsImage(news: news, fit: BoxFit.cover),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CategoryChip(label: news.category, compact: true),
                          const SizedBox(height: 8),
                          Text(
                            news.title,
                            style: GF.head(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.25,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'TOP STORY',
                          style: GF.body(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
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
                          maxLines: 3,
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
                          Text(
                            'Read',
                            style: GF.body(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.open_in_new_rounded,
                            size: 14,
                            color: AppColors.accent,
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

/// Compact list row for headlines.
class NewsArticleTile extends StatelessWidget {
  final NewsModel news;
  final VoidCallback? onTap;

  const NewsArticleTile({super.key, required this.news, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPending = context.watch<AppProvider>().isPendingNewsArticle(news.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: isPending ? AppColors.accentDim : context.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPending ? AppColors.accent : context.brd,
              width: isPending ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: _NewsImage(news: news, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryChip(label: news.category),
                    const SizedBox(height: 6),
                    Text(
                      news.title,
                      style: GF.body(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.txt,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (news.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        news.summary,
                        style: GF.body(
                          fontSize: 11,
                          color: context.txt3,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${news.timeAgo} · ${news.source}',
                      style: GF.body(fontSize: 10, color: context.txt3),
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
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool compact;

  const _CategoryChip({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 7,
        vertical: compact ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: context.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: GF.body(
          fontSize: compact ? 9 : 9,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
          letterSpacing: 0.6,
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

  const _NewsImage({required this.news, required this.fit});

  @override
  Widget build(BuildContext context) {
    if (news.imageUrl.isEmpty) {
      return ColoredBox(
        color: context.bg3,
        child: Center(
          child: Text(
            news.categoryEmoji,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: news.imageUrl,
      fit: fit,
      placeholder: (_, __) => ColoredBox(
        color: context.bg3,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: context.bg3,
        child: Center(
          child: Text(
            news.categoryEmoji,
            style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }
}
