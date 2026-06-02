import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ad_manager.dart';
import '../ads/ad_placement_news.dart';
import '../ads/adsterra/adsterra_banner.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../screens/tv_screen.dart' show ScoreCardsSection;
import '../theme/app_theme.dart';
import '../utils/channel_player.dart';
import '../utils/news_priority.dart';
import '../widgets/news_article_card.dart';
import '../widgets/section_nav_bar.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/list_skeletons.dart';
import '../widgets/common/widgets.dart';

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
      final prov = context.read<AppProvider>();
      prov.ensureMatchesLoaded();
      prov.loadNews();
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
    final prov = context.read<AppProvider>();
    prov.setPendingNewsArticle(news.id);

    final result = await AdManager.instance.handleNewsArticleTap(article: news);
    if (!mounted) return;

    if (result.opened) {
      prov.setPendingNewsArticle(null);
      await openNewsArticle(news, context: context);
      return;
    }
    if (!result.showTapAgainHint) {
      prov.setPendingNewsArticle(null);
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
    final prov = context.watch<AppProvider>();
    final internationalScores = prov.internationalScoreMatches;
    final premierScores = prov.premierLeagueScoreMatches;
    final allNews = prov.news;
    final filtered = _filtered(allNews);
    final hero = _pickHero(filtered);
    final rest = hero != null
        ? filtered.where((n) => n.id != hero.id).toList()
        : filtered;

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          await prov.ensureMatchesLoaded();
          await prov.loadNews();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: ShellAppBar()),
            SliverToBoxAdapter(
              child: SectionScreenHeader(
                title: 'Sports News',
                subtitle: 'World Cup & cricket first · headlines with photos',
                leadingIcons: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.9),
                          AppColors.accent.withValues(alpha: 0.55),
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
            if (AdManager.instance.adsEnabled)
              const SliverPersistentHeader(
                pinned: true,
                delegate: _NewsStickyBannerDelegate(),
              ),
            SliverToBoxAdapter(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SectionNavBar(
                items: _categories,
                selected: _category,
                onSelected: (v) => setState(() => _category = v),
              ),
              ),
            ),
            if (AdManager.instance.adsEnabled)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: AdsterraNativeBanner(
                    placement: 'news_headlines',
                    height: 90,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _NewsSectionHeader(
              title: 'Live scores',
              icon: Icons.sports_score_rounded,
              ),
            ),
            if (prov.matchesLoading &&
                internationalScores.isEmpty &&
                premierScores.isEmpty)
              const SliverToBoxAdapter(child: ScoreRowSkeleton())
            else ...[
              SliverToBoxAdapter(
                child: ScoreCardsSection(
                  title: 'Cricket & international',
                  matches: internationalScores,
                  loading: prov.matchesLoading,
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
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: ScoreCardsSection(
                  title: 'Premier League',
                  matches: premierScores,
                  loading: prov.matchesLoading,
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
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (filtered.any(NewsPriority.isWorldCup) ||
                filtered.any(NewsPriority.isCricket))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (filtered.any(NewsPriority.isWorldCup))
                        _HighlightChip(
                          label: 'World Cup',
                          icon: Icons.emoji_events_rounded,
                          colors: const [
                            Color(0xFF1565C0),
                            Color(0xFF0D47A1),
                          ],
                        ),
                      if (filtered.any(NewsPriority.isCricket))
                        _HighlightChip(
                          label: 'Cricket',
                          icon: Icons.sports_cricket_rounded,
                          colors: const [
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
                trailing: prov.newsLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accent,
                        ),
                      )
                    : Text(
                        '${filtered.length} stories',
                        style: TextStyle(fontSize: 11, color: context.txt3),
                      ),
              ),
            ),
            if (prov.newsLoading && allNews.isEmpty)
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Text(
                    prov.newsError != null
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
                    Icon(Icons.info_outline, size: 14, color: context.txt3),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'News © ESPN & BBC Sport. First tap opens offer; tap again to read the story.',
                        style: TextStyle(
                            fontSize: 10, color: context.txt3, height: 1.35),
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
    );
  }
}

class _NewsStickyBannerDelegate extends SliverPersistentHeaderDelegate {
  const _NewsStickyBannerDelegate();

  static const double _height = 98;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: AdsterraBanner728(placement: 'news_top_sticky'),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
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
