// lib/screens/other_screens.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/provider/app_provider.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/widgets/channel_avatar.dart';
import 'package:lumio_tv/widgets/shell_app_bar.dart';
import 'package:lumio_tv/ads/widgets/floating_native_card.dart';
import 'package:lumio_tv/config/ad_config.dart';
import 'package:lumio_tv/widgets/ad_list_injector.dart';
import 'package:lumio_tv/widgets/channel_list_tile.dart';
import 'package:lumio_tv/utils/sport_channel_icons.dart';
import 'package:lumio_tv/utils/channel_player.dart';
import 'package:lumio_tv/screens/category_channels_screen.dart';
import 'package:lumio_tv/screens/special_link/special_link_hub_screen.dart';
import 'package:lumio_tv/widgets/add_favorite_dialog.dart';
import 'package:lumio_tv/widgets/section_nav_bar.dart';
import 'package:lumio_tv/utils/sports_channel_priority.dart';
import 'package:lumio_tv/utils/live_nav_top_sports.dart';
import 'package:lumio_tv/utils/live_tab_channels.dart';
import 'package:lumio_tv/ads/ad_manager.dart';
import 'package:lumio_tv/ads/widgets/lazy_adsterra_strip.dart';
import 'package:lumio_tv/ads/widgets/sticky_bottom_native.dart';
import 'package:lumio_tv/widgets/list_skeletons.dart';
import 'package:lumio_tv/core/performance_tuning.dart';
import 'package:lumio_tv/theme/tokens/colors.dart';

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

  List<ChannelModel> _sportsPool(AppProvider prov) => prov.sportsBrowseChannels;

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
    ('Other Sports', '🏟️'),
  ];

  static List<Color> _sportCardGradient(String sport) {
    return switch (sport) {
      'Cricket' => [const Color(0xFF00897B), const Color(0xFF004D40)],
      'Football' => [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      'Basketball' => [const Color(0xFFE65100), const Color(0xFFBF360C)],
      'Tennis' => [const Color(0xFFF9A825), const Color(0xFFE65100)],
      'Formula 1' => [const Color(0xFFC62828), const Color(0xFF1A1A2E)],
      'Boxing' => [const Color(0xFF6A1B9A), const Color(0xFF311B92)],
      'Hockey' => [const Color(0xFF0277BD), const Color(0xFF01579B)],
      'Volleyball' => [const Color(0xFF00838F), const Color(0xFF006064)],
      'WWE' => [const Color(0xFFAD1457), const Color(0xFF880E4F)],
      'Swimming' => [const Color(0xFF039BE5), const Color(0xFF01579B)],
      'Snooker' => [const Color(0xFF558B2F), const Color(0xFF33691E)],
      'Racing' => [const Color(0xFF5D4037), const Color(0xFF3E2723)],
      'Other Sports' => [const Color(0xFF455A64), const Color(0xFF263238)],
      _ => [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
    };
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();

    return TabAdOverlay(
      showFloatingCard: true,
      floatingPlacement: 'sports_floating_native',
      child: Scaffold(
        backgroundColor: context.bg,
        body: Column(
          children: [
            const ShellAppBar(blendWithScaffold: true),
            Expanded(
              child: RefreshIndicator(
                color: AppTokens.accent,
                onRefresh: prov.refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  cacheExtent: PerformanceTuning.listCacheExtent,
                  slivers: [
                    SliverToBoxAdapter(
                      child: SectionScreenHeader(
                        title: 'Sports',
                        subtitle:
                            'Vibrant categories — cricket, football, F1 & more',
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
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: SectionNavBar(
                          items: _pills,
                          selected: _sel,
                          onSelected: (v) => setState(() => _sel = v),
                        ),
                      ),
                    ),
                    if (AdManager.instance.showAdsterraWebViewSlots)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                          child: LazyAdsterraBanner728(placement: 'sports_top'),
                        ),
                      ),
                    if (_sel == 'All') ...[
                      ..._sportsAllSlivers(context, prov),
                    ] else ...[
                      ..._sportCategoryHeaderSlivers(context, prov),
                      ..._sportChannelSlivers(context, prov),
                    ],
                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sportsAllSlivers(BuildContext context, AppProvider prov) {
    final pool = _sportsPool(prov);
    final counts = SportChannelIcons.countBySportType(pool);

    if (prov.channelsLoading && pool.isEmpty) {
      return const [
        SliverToBoxAdapter(child: ChannelListSkeleton(count: 4)),
        SliverToBoxAdapter(child: CategoryGridSkeleton(count: 6)),
      ];
    }

    final width = MediaQuery.sizeOf(context).width;
    final aspect = width < 340 ? 0.92 : 1.0;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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

              final colors = _sportCardGradient(sportName);
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
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SportTypeIcon(sportName: sportName, size: 44),
                        const SizedBox(height: 8),
                        Text(
                          sportName,
                          style: GF.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          count == 0 ? 'No channels' : '$count Live',
                          style: GF.body(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color:
                                count == 0 ? Colors.white54 : Colors.white,
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
      if (AdManager.instance.showAdsterraWebViewSlots)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: LazyAdsterraNativeBanner(
              placement: 'sports_categories',
              height: 100,
            ),
          ),
        ),
    ];
  }

  List<Widget> _sportCategoryHeaderSlivers(
    BuildContext context,
    AppProvider prov,
  ) {
    final channels = _filteredSportsChannels(prov);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SportTypeIcon(sportName: _sel, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sel,
                      style: GF.head(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.txt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channels.isEmpty
                          ? 'No live channels'
                          : '${channels.length} channels • Hold to add favourite',
                      style: TextStyle(fontSize: 12, color: context.txt3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _sportChannelSliversForList(
    BuildContext context,
    AppProvider prov,
    List<ChannelModel> channels,
  ) {
    if (prov.channelsLoading && channels.isEmpty) {
      return const [
        SliverToBoxAdapter(child: ChannelListSkeleton()),
      ];
    }
    if (channels.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Text(
              '$_sel এ কোনো channel নেই',
              style: TextStyle(fontSize: 13, color: context.txt3),
            ),
          ),
        ),
      ];
    }
    return [
      AdListInjector.buildSeparatedChannelSliver(
        itemCount: channels.length,
        screen: AdListScreen.sports,
        placementPrefix: AdListInjector.placementPrefixForSport(_sel),
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
                ? const Icon(Icons.favorite, color: AppTokens.accent, size: 18)
                : null,
          );
        },
      ),
    ];
  }

  List<Widget> _sportChannelSlivers(BuildContext context, AppProvider prov) {
    return _sportChannelSliversForList(
      context,
      prov,
      _filteredSportsChannels(prov),
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
  List<_LiveRow>? _liveRowsCache;
  int? _liveRowsToken;

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final pool = prov.liveTabChannels;
    final topSports = prov
        .liveNavTopSportsChannels()
        .where(LiveTabChannels.isM3u8)
        .where((c) => LiveTabChannels.isAllowedCategory(c.category))
        .toList();
    final sportsRaw = LiveTabChannels.sports(pool)
        .where((c) => !LiveNavTopSports.isPinned(c, topSports))
        .toList();
    final sportsGrouped = SportsChannelPriority.groupedByRegion(sportsRaw);
    final movies = LiveTabChannels.movies(pool);

    final totalLive = topSports.length + sportsRaw.length + movies.length;

    final listBody = _LiveChannelListBody(
      prov: prov,
      topSports: topSports,
      sportsGrouped: sportsGrouped,
      movies: movies,
      sportsNotEmpty: sportsRaw.isNotEmpty,
      topSportsNotEmpty: topSports.isNotEmpty,
      moviesNotEmpty: movies.isNotEmpty,
    );

    final rowsToken = Object.hash(
      totalLive,
      prov.channels.length,
      prov.channelsLoading,
    );
    if (_liveRowsToken != rowsToken) {
      _liveRowsToken = rowsToken;
      _liveRowsCache = listBody.flattenRows();
    }

    return ColoredBox(
      color: context.bg,
      child: Column(
        children: [
          const ShellAppBar(blendWithScaffold: true),
          Expanded(
            child: RefreshIndicator(
              color: AppTokens.accent,
              onRefresh: prov.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: PerformanceTuning.listCacheExtent,
                slivers: [
                  SliverToBoxAdapter(
                    child: SectionScreenHeader(
                      title: 'Live',
                      subtitle:
                          'Sports & movies · HLS (.m3u8) from Appwrite catalog',
                      leadingIcons: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTokens.liveRedDim,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTokens.liveRed.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.sensors_rounded,
                            color: AppTokens.liveRed,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: ScreenStatChips(
                      chips: [
                        (
                          icon: Icons.live_tv_rounded,
                          label: '$totalLive live now',
                        ),
                        if (topSports.isNotEmpty || sportsRaw.isNotEmpty)
                          (
                            icon: Icons.sports_soccer_rounded,
                            label:
                                '${topSports.length + sportsRaw.length} sports',
                          ),
                        if (movies.isNotEmpty)
                          (
                            icon: Icons.movie_rounded,
                            label: '${movies.length} movies',
                          ),
                      ],
                    ),
                  ),
                  if (AdManager.instance.showAdsterraWebViewSlots)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                        child: LazyAdsterraBanner728(placement: 'live_top'),
                      ),
                    ),
                  ...listBody.toSlivers(context, rows: _liveRowsCache),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

Widget _liveSectionLabel(BuildContext ctx, String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTokens.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GF.head(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ctx.txt3,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );

enum _LiveRowKind { section, channel, ad, gap }

class _LiveRow {
  const _LiveRow._(this.kind, {this.label, this.channel, this.browseCategory, this.ad, this.gap = 14});

  const _LiveRow.section(String label)
      : this._(_LiveRowKind.section, label: label);

  const _LiveRow.channel(ChannelModel channel, String browseCategory)
      : this._(_LiveRowKind.channel, channel: channel, browseCategory: browseCategory);

  const _LiveRow.ad(Widget ad) : this._(_LiveRowKind.ad, ad: ad);

  const _LiveRow.gap([double h = 14]) : this._(_LiveRowKind.gap, gap: h);

  final _LiveRowKind kind;
  final String? label;
  final ChannelModel? channel;
  final String? browseCategory;
  final Widget? ad;
  final double gap;
}

/// Live channel rows flattened for [CustomScrollView] slivers.
class _LiveChannelListBody {
  const _LiveChannelListBody({
    required this.prov,
    required this.topSports,
    required this.sportsGrouped,
    required this.movies,
    required this.sportsNotEmpty,
    required this.topSportsNotEmpty,
    required this.moviesNotEmpty,
  });

  final AppProvider prov;
  final List<ChannelModel> topSports;
  final List<({int region, List<ChannelModel> channels})> sportsGrouped;
  final List<ChannelModel> movies;
  final bool sportsNotEmpty;
  final bool topSportsNotEmpty;
  final bool moviesNotEmpty;

  List<_LiveRow> flattenRows() => _flattenRows();

  List<_LiveRow> _flattenRows() {
    final rows = <_LiveRow>[];
    var channelCount = 0;

    void afterChannel() {
      channelCount++;
      final ad = AdListInjector.maybeNativeAdAfterChannels(
        channelsSoFar: channelCount,
        screen: AdListScreen.live,
        placementPrefix: 'live_list',
      );
      if (ad != null) {
        rows.add(
          _LiveRow.ad(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ad,
            ),
          ),
        );
      }
    }

    if (topSportsNotEmpty) {
      rows.add(const _LiveRow.section('TOP SPORTS'));
      for (final c in topSports) {
        rows.add(_LiveRow.channel(c, 'Sports'));
        afterChannel();
      }
      rows.add(const _LiveRow.gap());
    }

    if (sportsNotEmpty) {
      rows.add(const _LiveRow.section('LIVE SPORTS CHANNELS'));
      for (final group in sportsGrouped) {
        rows.add(
          _LiveRow.section(
            SportsChannelPriority.regionSectionTitle(group.region),
          ),
        );
        for (final c in group.channels) {
          rows.add(_LiveRow.channel(c, 'Sports'));
          afterChannel();
        }
        rows.add(const _LiveRow.gap(6));
      }
      rows.add(const _LiveRow.gap());
    }

    if (moviesNotEmpty) {
      rows.add(const _LiveRow.section('MOVIES'));
      for (final c in movies) {
        rows.add(_LiveRow.channel(c, 'Movies'));
        afterChannel();
      }
    }

    return rows;
  }

  /// Channel rows as slivers inside the page [CustomScrollView].
  List<Widget> toSlivers(BuildContext context, {List<_LiveRow>? rows}) {
    if (prov.channelsLoading &&
        topSports.isEmpty &&
        sportsGrouped.every((g) => g.channels.isEmpty) &&
        movies.isEmpty) {
      return const [
        SliverToBoxAdapter(child: ChannelListSkeleton()),
      ];
    }

    final flat = rows ?? _flattenRows();
    if (flat.isEmpty && !prov.channelsLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    style: TextStyle(fontSize: 12, color: context.txt3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, index) => _buildRowWidget(context, flat[index]),
          childCount: flat.length,
        ),
      ),
    ];
  }

  Widget _buildRowWidget(BuildContext context, _LiveRow row) {
    switch (row.kind) {
      case _LiveRowKind.section:
        return _liveSectionLabel(context, row.label!);
      case _LiveRowKind.gap:
        return SizedBox(height: row.gap);
      case _LiveRowKind.ad:
        return row.ad!;
      case _LiveRowKind.channel:
        final c = row.channel!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: RepaintBoundary(
            child: ChannelListTile(
              channel: c,
              onTap: () => _play(
                context,
                url: c.streamUrl,
                title: c.name,
                subtitle: c.currentShow,
                category: c.category,
                channel: c,
                browseCategory: row.browseCategory!,
              ),
              onLongPress: () => showAddFavoriteDialog(context, c),
            ),
          ),
        );
    }
  }
}

// =============================================================================
// NEWS SCREEN
// =============================================================================

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
    case 'Bangla':
      return Icons.language_rounded;
    case 'English':
      return Icons.public_rounded;
    case 'Hindi':
      return Icons.movie_filter_rounded;
    case 'Pakistan':
      return Icons.flag_rounded;
    default:
      return null;
  }
}

List<Color> _genreNavGradient(String name) {
  switch (name) {
    case 'Sports':
      return const [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF1B5E20)];
    case 'Entertainment':
      return const [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAD1457)];
    case 'Movies':
      return const [Color(0xFFE65100), Color(0xFFFF6F00), Color(0xFFFFB300)];
    case 'KDrama':
      return const [Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFEC407A)];
    case 'Kids':
      return const [Color(0xFF1B5E20), Color(0xFF43A047), Color(0xFF7CB342)];
    case 'Bangla':
      return const [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF2E7D32)];
    case 'English':
      return const [Color(0xFF0D47A1), Color(0xFF283593), Color(0xFF5C6BC0)];
    case 'Hindi':
      return const [Color(0xFFE65100), Color(0xFFFF8F00), Color(0xFFFFB300)];
    case 'Pakistan':
      return const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00695C)];
    default:
      return const [Color(0xFF37474F), Color(0xFF455A64), Color(0xFF546E7A)];
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
    final gradient = _genreNavGradient(title);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Stack(
              children: [
                Positioned(
                  right: -12,
                  bottom: -16,
                  child: Icon(
                    icon ?? Icons.category_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
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
                            onGradient: true,
                          ),
                          const Spacer(),
                          _GenreBadge(label: badge, isLive: isLive, onGradient: true),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: GF.body(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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

class _WideGenreCard extends StatelessWidget {
  final String emoji;
  final IconData? icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool isLive;
  final Color accent;
  final VoidCallback onTap;

  const _WideGenreCard({
    required this.emoji,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isLive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = _genreNavGradient(title);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: gradient,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.38),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              _GenreIconBox(
                emoji: emoji,
                icon: icon,
                accent: accent,
                size: 48,
                onGradient: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GF.body(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _GenreBadge(label: badge, isLive: isLive, onGradient: true),
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
  final bool onGradient;

  const _GenreIconBox({
    required this.emoji,
    required this.icon,
    required this.accent,
    this.size = 42,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onGradient
            ? Colors.white.withValues(alpha: 0.2)
            : accent.withValues(alpha: context.isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onGradient
              ? Colors.white.withValues(alpha: 0.35)
              : accent.withValues(alpha: context.isDark ? 0.35 : 0.2),
        ),
        boxShadow: onGradient
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(
              icon,
              size: size * 0.52,
              color: onGradient ? Colors.white : accent,
            )
          : Text(emoji, style: TextStyle(fontSize: size * 0.52)),
    );
  }
}

class _GenreBadge extends StatelessWidget {
  final String label;
  final bool isLive;
  final bool onGradient;

  const _GenreBadge({
    required this.label,
    required this.isLive,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final liveStyle = isLive && onGradient;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: liveStyle
            ? AppTokens.liveRed.withValues(alpha: 0.92)
            : (isLive
                ? (context.isDark
                    ? AppTokens.accent.withValues(alpha: 0.18)
                    : AppTokens.accentLight)
                : (onGradient
                    ? Colors.white.withValues(alpha: 0.16)
                    : context.bg3)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: liveStyle
              ? Colors.white.withValues(alpha: 0.35)
              : (isLive
                  ? AppTokens.accent.withValues(alpha: 0.35)
                  : (onGradient
                      ? Colors.white.withValues(alpha: 0.25)
                      : context.brd)),
        ),
        boxShadow: liveStyle
            ? [
                BoxShadow(
                  color: AppTokens.liveRed.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: liveStyle
              ? Colors.white
              : (isLive ? AppTokens.accent : (onGradient ? Colors.white70 : context.txt3)),
          letterSpacing: 0.25,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static String _categoryBadge(
    AppProvider prov,
    String catName, {
    bool preferLive = false,
  }) {
    if (catName == 'Special Link') return 'GITUN';
    final n = prov
        .byCategory(catName)
        .where((c) => c.streamUrl.isNotEmpty)
        .length;
    if (n == 0) return preferLive ? 'No live' : 'No ch';
    return preferLive ? '$n Live' : '$n ch';
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final genreRows = prov.categoriesGenreRows.isNotEmpty
        ? prov.categoriesGenreRows
        : const [
            ['⚽', 'Sports', 'Cricket, Football & more', true, 0xFFFF6B1A],
            ['🇧🇩', 'Bangla', 'BD channels', true, 0xFF009688],
            ['🔗', 'Special Link', 'GITUN playlists', true, 0xFF5E35B1],
          ];

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShellAppBar(blendWithScaffold: true),
          Expanded(
            child: RefreshIndicator(
              color: AppTokens.accent,
              onRefresh: prov.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                cacheExtent: PerformanceTuning.listCacheExtent,
                slivers: [
                  if (prov.channelsLoading && prov.channels.isEmpty)
                    const SliverToBoxAdapter(
                      child: CategoryGridSkeleton(count: 8),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                          color: AppTokens.accent.withValues(
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
                              style: GF.body(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${prov.channelCountLabel} channels available',
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
                          prov.channelCountLabel,
                          style: GF.head(
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
                const SizedBox(height: 16),
                Text(
                  'Categories',
                  style: GF.head(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.txt,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a genre — vibrant live channels inside',
                  style: TextStyle(fontSize: 11, color: context.txt3),
                ),
                const SizedBox(height: 12),

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
                  itemCount: genreRows.length,
                  itemBuilder: (ctx, i) {
                    final c = genreRows[i];
                    final catName = c[1] as String;
                    return _GenreCategoryCard(
                      emoji: c[0] as String,
                      icon: _genreMaterialIcon(catName),
                      title: catName,
                      subtitle: c[2] as String,
                      badge: _categoryBadge(
                        prov,
                        catName,
                        preferLive: c[3] as bool,
                      ),
                      isLive: c[3] as bool,
                      accent: Color(c[4] as int),
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
                const SizedBox(height: 90),
              ],
            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const StickyBottomNative(),
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
    if (catName == 'Special Link') {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const SpecialLinkHubScreen(),
        ),
      );
      return;
    }
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
                    color: AppTokens.accent,
                  ),
                )
              else if (showLive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTokens.accentDim,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '● LIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.accent,
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
              color: AppTokens.accent,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
          ),
        ]),
      ),
    );
  }
}

