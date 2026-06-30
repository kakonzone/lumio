import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ad_manager.dart';
import '../ads/ad_placement_news.dart';
import '../ads/widgets/lazy_adsterra_strip.dart';
import '../models/model.dart';
import '../provider/app_config_provider.dart';
import '../provider/live_score_provider.dart';
import '../provider/news_provider.dart';
import '../provider/ui_state_provider.dart';
import '../screens/tv_screen.dart' show ScoreCardsSection;
import '../theme/app_theme.dart';
import '../utils/channel_player.dart';
import '../utils/news_priority.dart';
import '../widgets/news_article_card.dart';
import '../widgets/section_nav_bar.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/list_skeletons.dart';
import '../widgets/common/widgets.dart';
import '../theme/tokens/colors.dart';

/// Sports news hub — ESPN (+ BBC fallback), live scores, ads.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  String _category = 'All';

  static const _categories = [
    'All',
    'Top Stories',
    'Cricket',
    'Football',
    'NBA',
    'NFL',
    'Tennis',
    'Sports',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scoreProv = context.read<LiveScoreProvider>();
      final newsProv = context.read<NewsProvider>();
      final config = context.read<AppConfigProvider>().config;
      
      scoreProv.loadMatches();
      if (config.newsEnabled) {
        newsProv.loadNews();
      }
    });
  }

  List<NewsModel> _filtered(List<NewsModel> all) {
    final base = _category == 'All'
        ? all
        : all.where((n) => n.category == _category).toList();
    return NewsPriority.sort(base);
  }

  NewsModel? _pickHero(List<NewsModel> sorted) {
    if (sorted.isEmpty) return null;
    for (final n in sorted) {
      if (n.imageUrl.isNotEmpty &&
          (NewsPriority.isWorldCup(n) || NewsPriority.isCricket(n))) {
        return n;
      }
    }
    for (final n in sorted) {
      if (n.imageUrl.isNotEmpty) return n;
    }
    return sorted.first;
  }

  Future<void> _onNewsArticleTap(NewsModel news) async {
    final uiProv = context.read<UiStateProvider>();
    uiProv.setPendingNewsArticle(news.id);

    final result = await AdManager.instance.handleNewsArticleTap(article: news);
    if (!mounted) return;

    if (result.opened) {
      uiProv.setPendingNewsArticle(null);
      await openNewsArticle(news, context: context);
      return;
    }
    if (!result.showTapAgainHint) {
      uiProv.setPendingNewsArticle(null);
    }
  }

  void _playScore(
    BuildContext context, {
    required String url,
    required String title,
    required String subtitle,
  }) {
    if (url.isEmpty) return;
    openStreamPlayer(
      context,
      url: url,
      title: title,
      subtitle: subtitle,
      category: 'Sports',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreProv = context.watch<LiveScoreProvider>();
    final newsProv = context.watch<NewsProvider>();
    final premierScores = scoreProv.premierLeagueScoreMatches;
    final allNews = newsProv.news;
    final filtered = _filtered(allNews);
    final hero = _pickHero(filtered);
    final rest = hero != null
        ? filtered.where((n) => n.id != hero.id).toList()
        : filtered;

    final showScores = scoreProv.matchesLoading || premierScores.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          const ShellAppBar(blendWithScaffold: true),
          Expanded(
            child: RefreshIndicator(
              color: AppTokens.accent,
              onRefresh: () async {
                await scoreProv.loadMatches();
                await newsProv.loadNews();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SectionScreenHeader(
                      title: 'Sports News',
                      subtitle:
                          'World Cup & cricket first · headlines with photos',
                      leadingIcons: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTokens.accent.withValues(alpha: 0.9),
                                AppTokens.accent.withValues(alpha: 0.55),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.newspaper_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: SectionNavBar(
                        items: _categories,
                        selected: _category,
                        onSelected: (v) => setState(() => _category = v),
                      ),
                    ),
                  ),
                  if (AdManager.instance.showAdsterraWebViewSlots) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child:
                            LazyAdsterraBanner728(placement: 'news_top_sticky'),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: LazyAdsterraNativeBanner(
                          placement: 'news_headlines',
                          height: 90,
                        ),
                      ),
                    ),
                  ],
                  if (showScores) ...[
                    if (scoreProv.matchesLoading && premierScores.isEmpty)
                      const SliverToBoxAdapter(child: ScoreRowSkeleton())
                    else
                      SliverToBoxAdapter(
                        child: ScoreCardsSection(
                          title: '',
                          matches: premierScores,
                          loading: scoreProv.matchesLoading,
                          showHeader: false,
                          showEmptyMessage: false,
                          onPlay: (ctx,
                                  {required url,
                                  required title,
                                  subtitle = '',
                                  category = '',
                                  channel,
                                  browseCategory}) =>
                              _playScore(ctx,
                                  url: url, title: title, subtitle: subtitle),
                        ),
                      ),
                  ],
                  if (filtered.any(NewsPriority.isWorldCup) ||
                      filtered.any(NewsPriority.isCricket))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            if (filtered.any(NewsPriority.isWorldCup))
                              const _HighlightChip(
                                label: 'World Cup',
                                icon: Icons.emoji_events_rounded,
                                colors: [
                                  Color(0xFF1565C0),
                                  Color(0xFF0D47A1),
                                ],
                              ),
                            if (filtered.any(NewsPriority.isCricket))
                              const _HighlightChip(
                                label: 'Cricket',
                                icon: Icons.sports_cricket_rounded,
                                colors: [
                                  Color(0xFF00897B),
                                  Color(0xFF004D40),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: _NewsSectionHeader(
                      title: 'Headlines',
                      icon: Icons.article_outlined,
                      trailing: newsProv.newsLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTokens.accent,
                              ),
                            )
                          : Text(
                              '${filtered.length} stories',
                              style:
                                  TextStyle(fontSize: 11, color: context.txt3),
                            ),
                    ),
                  ),
                  if (newsProv.newsLoading && allNews.isEmpty)
                    SliverList(
                      delegate: SliverChildListDelegate(
                        List.generate(
                          4,
                          (_) => const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: NewsCardShimmer(),
                          ),
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        child: Text(
                          newsProv.newsError != null
                              ? 'Could not load news. Pull to refresh.'
                              : 'No stories in $_category. Try another category.',
                          style: TextStyle(fontSize: 13, color: context.txt3),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildListDelegate([
                        if (hero != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                            child: NewsHeroCard(
                              news: hero,
                              onTap: () => _onNewsArticleTap(hero),
                            ),
                          ),
                        ...AdPlacementNews.buildArticleList(
                          articleCount: rest.length,
                          buildArticleAt: (i) {
                            final article = rest[i];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: NewsArticleTile(
                                news: article,
                                onTap: () => _onNewsArticleTap(article),
                              ),
                            );
                          },
                        ),
                      ]),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 14, color: context.txt3),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'News © ESPN & BBC Sport. First tap opens offer; tap again to read the story.',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.txt3,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 72)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;

  const _HighlightChip({
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GF.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _NewsSectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTokens.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: GF.head(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.txt,
                letterSpacing: 1.1,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
