// lib/screens/other_screens.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/provider/app_provider.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/widgets/channel_avatar.dart';
import 'package:lumio_tv/widgets/shell_app_bar.dart';
import 'package:lumio_tv/widgets/channel_list_tile.dart';
import 'package:lumio_tv/utils/sport_channel_icons.dart';
import 'package:lumio_tv/utils/channel_player.dart';
import 'package:lumio_tv/screens/category_channels_screen.dart';
import 'package:lumio_tv/screens/tv_screen.dart' show ScoreCardsSection;
import 'package:lumio_tv/widgets/add_favorite_dialog.dart';
import 'package:lumio_tv/widgets/section_nav_bar.dart';
import 'package:lumio_tv/utils/sports_channel_priority.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// MODEL EXTENSIONS
// =============================================================================

extension ChannelUiExt on ChannelModel {
  String get categoryIcon {
    switch (category.toLowerCase()) {
      case 'sports':
        return '⚽';
      case 'entertainment':
        return '🎭';
      case 'movies':
        return '🎬';
      case 'kdrama':
        return '🇰🇷';
      case 'kids':
        return '🧒';
      case 'bangla':
        return '🇧🇩';
      case 'english':
        return '🇬🇧';
      case 'hindi':
        return '🇮🇳';
      case 'pakistan':
        return '🇵🇰';
      case 'news':
        return '📰';
      default:
        return '📺';
    }
  }

  String get formattedViewers {
    if (viewers >= 1000000)
      return '${(viewers / 1000000).toStringAsFixed(1)}M viewers';
    if (viewers >= 1000)
      return '${(viewers / 1000).toStringAsFixed(1)}K viewers';
    if (viewers == 0) return '';
    return '$viewers viewers';
  }
}

extension MatchUiExt on MatchModel {
  bool get isLive => status == 'live';

  String get sportEmoji {
    switch (sport.toLowerCase()) {
      case 'football':
      case 'soccer':
        return '⚽';
      case 'cricket':
        return '🏏';
      case 'basketball':
        return '🏀';
      case 'tennis':
        return '🎾';
      case 'formula 1':
      case 'f1':
        return '🏎️';
      case 'boxing':
        return '🥊';
      case 'hockey':
        return '🏒';
      case 'volleyball':
        return '🏐';
      case 'wwe':
      case 'wrestling':
        return '🤼';
      case 'swimming':
        return '🏊';
      case 'snooker':
        return '🎱';
      case 'racing':
        return '🏇';
      case 'rugby':
        return '🏉';
      case 'golf':
        return '⛳';
      default:
        return '🏆';
    }
  }
}

// =============================================================================
// OPEN PLAYER HELPER
// =============================================================================

void _play(
  BuildContext context, {
  required String url,
  required String title,
  String subtitle = '',
  String category = '',
  ChannelModel? channel,
  String? browseCategory,
}) {
  if (channel != null) {
    openChannelPlayer(
      context,
      channel: channel,
      subtitle: subtitle,
      browseCategory: browseCategory,
    );
    return;
  }
  openStreamPlayer(
    context,
    url: url,
    title: title,
    subtitle: subtitle,
    category: browseCategory ?? category,
  );
}

// =============================================================================
// SPORTS SCREEN
// =============================================================================

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  State<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen> {
  String _sel = 'All';

  List<ChannelModel> _sportsPool(AppProvider prov) =>
      SportChannelIcons.browseChannels(prov.channels);

  List<ChannelModel> _filteredSportsChannels(AppProvider prov) {
    final list = _sportsPool(prov)
        .where(
          (c) =>
              _sel == 'All' || SportChannelIcons.matchesSportFilter(c, _sel),
        )
        .toList();
    if (_sel == 'Cricket' || _sel == 'Football' || _sel == 'All') {
      return SportsChannelPriority.sortLiveSports(list);
    }
    list.sort((a, b) => b.viewers.compareTo(a.viewers));
    return list;
  }

  static const _pills = SportChannelIcons.sportFilterPills;

  static const _sportGridMeta = [
    ('Cricket', '🏏'),
    ('Football', '⚽'),
    ('Basketball', '🏀'),
    ('Tennis', '🎾'),
    ('Formula 1', '🏎️'),
    ('Boxing', '🥊'),
    ('Hockey', '🏒'),
    ('Volleyball', '🏐'),
    ('WWE', '🤼'),
    ('Swimming', '🏊'),
    ('Snooker', '🎱'),
    ('Racing', '🏇'),
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShellAppBar(),
          SectionScreenHeader(
            title: 'Sports',
            subtitle: 'Cricket, football & live sports channels',
            leadingIcons: [
              Image.asset(
                SportChannelIcons.cricketAsset,
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Image.asset(
                SportChannelIcons.footballAsset,
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SectionNavBar(
              items: _pills,
              selected: _sel,
              onSelected: (v) => setState(() => _sel = v),
            ),
          ),
          Expanded(
            child: _sel == 'All'
                ? _buildSportsAllView(context, prov)
                : _buildSportChannelList(context, prov),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsAllView(BuildContext context, AppProvider prov) {
    final pool = _sportsPool(prov);
    final counts = SportChannelIcons.countBySportType(pool);
    final allSorted = SportsChannelPriority.sortLiveSports(pool);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final aspect = constraints.maxWidth < 340 ? 0.92 : 1.0;
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: aspect,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final meta = _sportGridMeta[i];
                  final sportName = meta.$1;
                  final count = counts[sportName] ?? 0;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (count == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$sportName এ কোনো channel নেই'),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setState(() => _sel = sportName);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [context.bg2, context.bg3],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.brd),
                          boxShadow: [
                            BoxShadow(
                              color: context.shadowColor,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SportTypeIcon(sportName: sportName, size: 42),
                            const SizedBox(height: 8),
                            Text(
                              sportName,
                              style: GoogleFonts.barlow(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.txt,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              count == 0 ? 'No channels' : '$count Live',
                              style: GoogleFonts.barlow(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: count == 0
                                    ? context.txt3
                                    : AppColors.accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _sportGridMeta.length,
              ),
            ),
            ),
            if (allSorted.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _sectionLabel(context, 'ALL SPORTS CHANNELS'),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final ch = allSorted[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ChannelListTile(
                        channel: ch,
                        onTap: () => _play(
                          context,
                          url: ch.streamUrl,
                          title: ch.name,
                          subtitle: ch.currentShow,
                          category: 'Sports',
                          channel: ch,
                          browseCategory: 'Sports',
                        ),
                        onLongPress: () =>
                            showAddFavoriteDialog(context, ch),
                        trailing: prov.isFavorite(ch.id)
                            ? const Icon(
                                Icons.favorite,
                                color: AppColors.accent,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  },
                  childCount: allSorted.length,
                ),
              ),
            ),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext ctx, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ctx.txt3,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      );

  Widget _buildSportChannelList(BuildContext context, AppProvider prov) {
    final channels = _filteredSportsChannels(prov);
    if (channels.isEmpty) {
      return Center(
        child: Text(
          '$_sel এ কোনো channel নেই',
          style: TextStyle(fontSize: 13, color: context.txt3),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: channels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final ch = channels[i];
        return ChannelListTile(
          channel: ch,
          onTap: () => _play(
            context,
            url: ch.streamUrl,
            title: ch.name,
            subtitle: ch.currentShow,
            category: 'Sports',
            channel: ch,
            browseCategory: 'Sports',
          ),
          onLongPress: () => showAddFavoriteDialog(context, ch),
          trailing: prov.isFavorite(ch.id)
              ? const Icon(Icons.favorite, color: AppColors.accent, size: 18)
              : null,
        );
      },
    );
  }
}

// =============================================================================
// LIVE SCREEN
// =============================================================================

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final sportsRaw =
        prov.liveChannels.where((c) => c.category == 'Sports').toList();
    final sportsGrouped = SportsChannelPriority.groupedByRegion(sportsRaw);
    final sports = SportsChannelPriority.sortLiveSports(sportsRaw);
    final other = prov.liveChannels
        .where((c) => c.category != 'Sports')
        .toList()
      ..sort((a, b) {
        if (a.category == 'Bangladesh' && b.category != 'Bangladesh') return -1;
        if (b.category == 'Bangladesh' && a.category != 'Bangladesh') return 1;
        return b.viewers.compareTo(a.viewers);
      });

    final totalLive = sports.length + other.length;

    return ColoredBox(
      color: context.bg,
      child: Column(
        children: [
          const ShellAppBar(),
          SectionScreenHeader(
            title: 'Live',
            subtitle: 'Channels streaming right now',
            leadingIcons: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.liveRedDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.liveRed.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.liveRed,
                  size: 22,
                ),
              ),
            ],
          ),
          ScreenStatChips(
            chips: [
              (
                icon: Icons.live_tv_rounded,
                label: '$totalLive live now',
              ),
              if (sports.isNotEmpty)
                (
                  icon: Icons.sports_soccer_rounded,
                  label: '${sports.length} sports',
                ),
              if (other.isNotEmpty)
                (
                  icon: Icons.tv_rounded,
                  label: '${other.length} other',
                ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: prov.refresh,
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (prov.channelsLoading && sports.isEmpty && other.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  if (sports.isNotEmpty) ...[
                    _sectionLabel(context, 'LIVE SPORTS CHANNELS'),
                    for (final group in sportsGrouped) ...[
                      _sectionLabel(
                        context,
                        SportsChannelPriority.regionSectionTitle(
                          group.region,
                        ),
                      ),
                      ...group.channels.map(
                        (c) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: RepaintBoundary(
                            child: _ChannelCard(
                              channel: c,
                              onPlay: () => _play(
                                context,
                                url: c.streamUrl,
                                title: c.name,
                                subtitle: c.currentShow,
                                category: c.category,
                                channel: c,
                                browseCategory: 'Sports',
                              ),
                              onLongPress: () =>
                                  showAddFavoriteDialog(context, c),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    const SizedBox(height: 14),
                  ],
                  if (other.isNotEmpty) ...[
                    _sectionLabel(context, 'ENTERTAINMENT & OTHER'),
                    ...other.map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: RepaintBoundary(
                          child: _ChannelCard(
                          channel: c,
                          onPlay: () => _play(
                            context,
                            url: c.streamUrl,
                            title: c.name,
                            subtitle: c.currentShow,
                            category: c.category,
                            channel: c,
                            browseCategory: prov.categoryForRelated(c),
                          ),
                          onLongPress: () =>
                              showAddFavoriteDialog(context, c),
                        ),
                        ),
                      ),
                    ),
                  ],
                  if (!prov.channelsLoading &&
                      sports.isEmpty &&
                      other.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Column(children: [
                          const Text('📡', style: TextStyle(fontSize: 42)),
                          const SizedBox(height: 12),
                          Text(
                            'No live channels right now',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.txt2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.txt3,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext ctx, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.barlowCondensed(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ctx.txt3,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      );
}

// =============================================================================
// NEWS SCREEN
// =============================================================================

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().ensureMatchesLoaded();
    });
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

    return Scaffold(
      backgroundColor: context.bg,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          await prov.ensureMatchesLoaded();
          await prov.loadNews();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const ShellAppBar(),
            SectionScreenHeader(
              title: 'News',
              subtitle: 'Live scores, match predictions & headlines',
              leadingIcons: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(
                      alpha: context.isDark ? 0.2 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.newspaper_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
              ],
            ),

            if (prov.matchesLoading &&
                internationalScores.isEmpty &&
                premierScores.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Loading scores…',
                  style: TextStyle(fontSize: 12, color: context.txt3),
                ),
              )
            else ...[
              ScoreCardsSection(
                title: 'Live Cricket & Football',
                matches: internationalScores,
                loading: prov.matchesLoading,
                onPlay: (ctx, {required url, required title, subtitle = '', category = '', channel, browseCategory}) =>
                    _playScore(
                  ctx,
                  url: url,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
              const SizedBox(height: 12),
              ScoreCardsSection(
                title: 'Premier League',
                matches: premierScores,
                loading: prov.matchesLoading,
                onPlay: (ctx, {required url, required title, subtitle = '', category = '', channel, browseCategory}) =>
                    _playScore(
                  ctx,
                  url: url,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
            ],
            const SizedBox(height: 16),

          // ── Predictions section ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Text(
                  'PREDICTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.txt3,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'See all',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          if (prov.liveMatches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No live matches right now',
                style: TextStyle(fontSize: 13, color: context.txt3),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: prov.liveMatches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final match = prov.liveMatches[i];
                  return _PredictionCard(
                    match: match,
                    onTap: () => _play(
                      context,
                      url: match.streamUrl,
                      title: '${match.teamA} vs ${match.teamB}',
                      subtitle: '${match.sport} • LIVE',
                      category: 'Sports',
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),

          // ── Latest news (moved from Home) ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: Text(
                  'LATEST NEWS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.txt3,
                    letterSpacing: 1.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (prov.newsLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),

          if (prov.newsLoading && prov.news.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Loading latest sports news…',
                style: TextStyle(fontSize: 13, color: context.txt3),
              ),
            )
          else if (prov.news.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'No news available',
                style: TextStyle(fontSize: 13, color: context.txt3),
              ),
            )
          else
            ...prov.news.map(
              (n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NewsCard(news: n),
              ),
            ),

          const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORIES SCREEN
// =============================================================================

IconData? _genreMaterialIcon(String name) {
  switch (name) {
    case 'Sports':
      return Icons.sports_soccer_rounded;
    case 'Entertainment':
      return Icons.theaters_rounded;
    case 'Movies':
      return Icons.movie_rounded;
    case 'KDrama':
      return Icons.live_tv_rounded;
    case 'Kids':
      return Icons.child_care_rounded;
    default:
      return null;
  }
}

class _GenreCategoryCard extends StatelessWidget {
  final String emoji;
  final IconData? icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool isLive;
  final Color accent;
  final VoidCallback onTap;

  const _GenreCategoryCard({
    required this.emoji,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isLive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.brd),
            boxShadow: [
              BoxShadow(
                color: context.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GenreIconBox(
                    emoji: emoji,
                    icon: icon,
                    accent: accent,
                  ),
                  const Spacer(),
                  _GenreBadge(label: badge, isLive: isLive),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: GoogleFonts.barlow(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.txt,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: context.txt3,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideGenreCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String badge;
  final bool isLive;
  final Color accent;
  final VoidCallback onTap;

  const _WideGenreCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isLive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.brd),
            boxShadow: [
              BoxShadow(
                color: context.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              _GenreIconBox(emoji: emoji, icon: null, accent: accent, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.barlow(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.txt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: context.txt3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _GenreBadge(label: badge, isLive: isLive),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreIconBox extends StatelessWidget {
  final String emoji;
  final IconData? icon;
  final Color accent;
  final double size;

  const _GenreIconBox({
    required this.emoji,
    required this.icon,
    required this.accent,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: context.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent.withValues(alpha: context.isDark ? 0.35 : 0.2),
        ),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, size: size * 0.52, color: accent)
          : Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

class _GenreBadge extends StatelessWidget {
  final String label;
  final bool isLive;

  const _GenreBadge({required this.label, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLive
            ? (context.isDark
                ? AppColors.accent.withValues(alpha: 0.18)
                : AppColors.accentLight)
            : context.bg3,
        borderRadius: BorderRadius.circular(20),
        border: isLive
            ? Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
              )
            : Border.all(color: context.brd),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isLive ? AppColors.accent : context.txt3,
          letterSpacing: 0.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const _cats = [
    ['⚽', 'Sports', 'Cricket, Football & more', '142 Live', true, 0xFFFF6B1A],
    ['🎭', 'Entertainment', 'Drama, Reality, Talk', '89 ch', false, 0xFF9C27B0],
    ['🎬', 'Movies', 'Action, Romance, Thriller', '56 ch', false, 0xFFE91E63],
    ['🇰🇷', 'KDrama', 'Korean dramas & shows', '44 ch', false, 0xFFFF4081],
    ['🧒', 'Kids', 'Cartoon, Education', '31 ch', false, 0xFF4CAF50],
    ['🇧🇩', 'Bangla', 'BD & Kolkata channels', '38 Live', true, 0xFF009688],
    ['🇬🇧', 'English', 'UK, US & International', '62 ch', false, 0xFF2196F3],
    ['🇮🇳', 'Hindi', 'Bollywood & Hindi shows', '96 Live', true, 0xFFFF9800],
  ];

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: context.bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const ShellAppBar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── All Channels banner ────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    final ch = prov.channels
                        .where((c) => c.streamUrl.isNotEmpty)
                        .toList();
                    if (ch.isNotEmpty) {
                      _play(
                        context,
                        url: ch.first.streamUrl,
                        title: ch.first.name,
                        subtitle: 'All Channels',
                        category: ch.first.category,
                        channel: ch.first,
                      );
                    }
                  },
                  child: Container(
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: context.isDark
                            ? const [Color(0xFFFF6B1A), Color(0xFFE65100)]
                            : const [Color(0xFFFF7A2E), Color(0xFFFF5722)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(
                            alpha: context.isDark ? 0.25 : 0.22,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.live_tv_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Channels',
                              style: GoogleFonts.barlow(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${prov.channels.length} channels available',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${prov.channels.length}',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),

                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final aspect =
                        constraints.maxWidth < 360 ? 1.35 : 1.48;
                    return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: aspect,
                  ),
                  itemCount: _cats.length,
                  itemBuilder: (ctx, i) {
                    final c = _cats[i];
                    final catName = c[1] as String;
                    return _GenreCategoryCard(
                      emoji: c[0] as String,
                      icon: _genreMaterialIcon(catName),
                      title: catName,
                      subtitle: c[2] as String,
                      badge: c[3] as String,
                      isLive: c[4] as bool,
                      accent: Color(c[5] as int),
                      onTap: () => _openCategory(
                        context,
                        prov,
                        catName,
                        icon: c[0] as String,
                      ),
                    );
                  },
                );
                  },
                ),
                const SizedBox(height: 12),

                _WideGenreCard(
                  emoji: '🇵🇰',
                  title: 'Pakistan',
                  subtitle: 'ARY, Geo, PTV, HUM TV & more',
                  badge: '27 Live',
                  isLive: true,
                  accent: const Color(0xFF2E7D32),
                  onTap: () => _openCategory(context, prov, 'Pakistan'),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCategory(
    BuildContext context,
    AppProvider prov,
    String catName, {
    String icon = '📺',
  }) {
    final catChannels = prov
        .byCategory(catName)
        .where((ch) => ch.streamUrl.isNotEmpty)
        .toList();
    if (catChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$catName এ কোনো live channel নেই'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryChannelsScreen(
          categoryName: catName,
          categoryIcon: icon,
        ),
      ),
    );
  }
}

// =============================================================================
// SHARED CARD WIDGETS
// =============================================================================

class _ChannelCard extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback? onPlay;
  final VoidCallback? onLongPress;

  const _ChannelCard({
    required this.channel,
    this.onPlay,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final showLive = prov.isStreamLive(channel);
    final checking = prov.isStreamHealthPending(channel);
    return GestureDetector(
      onTap: onPlay,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.brd),
        ),
        child: Row(children: [
          ChannelAvatar(
            channel: channel,
            emojiFallback: channel.categoryIcon,
          ),
          const SizedBox(width: 12),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  channel.currentShow.isEmpty
                      ? channel.category
                      : channel.currentShow,
                  style: TextStyle(fontSize: 11, color: context.txt3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (checking)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else if (showLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '● LIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              if (showLive) const SizedBox(height: 4),
              if (channel.formattedViewers.isNotEmpty)
                Text(
                  channel.formattedViewers,
                  style: TextStyle(fontSize: 10, color: context.txt3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
        ]),
      ),
    );
  }
}

// ─── Prediction Card ─────────────────────────────────────────────────────────

class _PredictionCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;

  const _PredictionCard({required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final total = match.winChanceA + match.winChanceB + match.drawChance;
    final safeTotal = total > 0 ? total : 100.0;
    final flexA = ((match.winChanceA / safeTotal) * 100).round().clamp(1, 98);
    final flexDraw =
        ((match.drawChance / safeTotal) * 100).round().clamp(1, 98);
    final flexB = (100 - flexA - flexDraw).clamp(1, 98);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
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
            Text(
              '${match.sport} • ${match.isLive ? "LIVE" : "Today"}'
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: context.txt3,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _teamPill(match.teamA, match.sportEmoji)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'VS',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.txt3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(child: _teamPill(match.teamB, match.sportEmoji)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(children: [
                Expanded(
                    flex: flexA,
                    child: Container(height: 6, color: AppColors.accent)),
                Expanded(
                    flex: flexDraw,
                    child: Container(height: 6, color: context.bg3)),
                Expanded(
                    flex: flexB,
                    child: Container(height: 6, color: AppColors.green)),
              ]),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${match.winChanceA.toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  '${match.drawChance.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.txt3,
                  ),
                ),
                Text(
                  '${match.winChanceB.toInt()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamPill(String name, String emoji) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFAAAAAA),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      );
}

// ─── News Card ────────────────────────────────────────────────────────────────

class _NewsCard extends StatelessWidget {
  final NewsModel news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            height: 90,
            width: double.infinity,
            color: context.bg3,
            child: news.imageUrl.isNotEmpty
                ? Image.network(
                    news.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        news.categoryEmoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      news.categoryEmoji,
                      style: const TextStyle(fontSize: 36),
                    ),
                  ),
          ),
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
                    color: AppColors.accent,
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
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${news.timeAgo} • ${news.source}',
                  style: TextStyle(fontSize: 11, color: context.txt3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
