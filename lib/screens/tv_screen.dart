// lib/screens/tv_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lumio_tv/models/model.dart';
import 'package:lumio_tv/provider/app_provider.dart';
import 'package:lumio_tv/theme/app_theme.dart';
import 'package:lumio_tv/models/live_event_match.dart';
import 'package:lumio_tv/utils/channel_player.dart';
import 'package:lumio_tv/widgets/shell_app_bar.dart';
import 'package:lumio_tv/utils/bdt_time.dart';
import 'package:lumio_tv/widgets/team_avatar.dart';
import 'package:lumio_tv/ads/ad_manager.dart';
import 'package:lumio_tv/ads/adsterra/adsterra_banner.dart';
import 'package:lumio_tv/ads/adsterra/adsterra_native.dart';
import 'package:lumio_tv/ads/widgets/floating_native_card.dart';
import 'package:lumio_tv/widgets/list_skeletons.dart';
import 'package:lumio_tv/widgets/home_promo_carousel.dart';
import 'package:lumio_tv/widgets/home_category_grid.dart';
import 'package:lumio_tv/core/performance_tuning.dart';

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  TvScreenState createState() => TvScreenState();
}

class TvScreenState extends State<TvScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String? _highlightCategory;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadAll();
    });
  }

  void goToTab(int index) {
    if (!mounted) return;
    final i = index.clamp(0, 3);
    if (_tabs.index != i) {
      _tabs.animateTo(i);
      setState(() {});
    }
  }

  void focusSearch() {
    if (!mounted) return;
    _searchFocus.requestFocus();
    setState(() {});
  }

  void filterCategory(String cat) {
    setState(() => _highlightCategory = cat == 'All' ? null : cat);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPlayer(
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

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    return TabAdOverlay(
      showFloatingCard: true,
      floatingPlacement: 'home_floating_native',
      child: ColoredBox(
        color: context.bg,
        child: Column(children: [
          const ShellAppBar(centerLumioTvBrand: true),
          _searchBar(context, prov),
          HomePromoCarousel(
            onLiveTabTap: () {
              if (_tabs.index != 1) {
                _tabs.animateTo(1);
                setState(() {});
              }
            },
          ),
          _tabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _HomeTab(
                  prov: prov,
                  onPlay: _openPlayer,
                  highlightCategory: _highlightCategory,
                  onCategoryTap: (cat) =>
                      setState(() => _highlightCategory = cat),
                ),
                _LiveNowTab(prov: prov, onPlay: _openPlayer),
                _TodayTab(prov: prov, onPlay: _openPlayer),
                _UpcomingTab(prov: prov, onPlay: _openPlayer),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _searchBar(BuildContext context, AppProvider prov) {
    final results = _searchCtrl.text.trim().isEmpty
        ? <ChannelModel>[]
        : prov.search(_searchCtrl.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.bg3,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.brd),
            boxShadow: [
              BoxShadow(
                color: context.shadowColor,
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded,
                  size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13, color: context.txt),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Search channels, sports, events...',
                  hintStyle: TextStyle(color: context.txt3, fontSize: 13),
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
                child: Icon(Icons.close, size: 18, color: context.txt3),
              ),
          ]),
        ),
        if (results.isNotEmpty)
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final ch = results[i];
                return GestureDetector(
                  onTap: () => _openPlayer(
                    context,
                    url: ch.streamUrl,
                    title: ch.name,
                    subtitle: ch.category,
                    category: ch.category,
                    channel: ch,
                    browseCategory: prov.categoryForRelated(ch),
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.bg2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.brd),
                    ),
                    child: Text(
                      ch.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.txt,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _tabBar(BuildContext context) {
    const tabs = [
      (Icons.home_rounded, 'Home', [Color(0xFF3949AB), Color(0xFF5C6BC0)]),
      (Icons.sensors_rounded, 'Live', [Color(0xFFB71C1C), Color(0xFFE53935)]),
      (Icons.today_rounded, 'Today', [Color(0xFF00695C), Color(0xFF00897B)]),
      (Icons.schedule_rounded, 'Soon', [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: context.isDark
              ? context.bg3.withValues(alpha: 0.9)
              : context.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.brd),
          boxShadow: [
            BoxShadow(
              color: context.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _tabs.index == i;
            final (icon, label, grad) = tabs[i];
            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_tabs.index != i) {
                      _tabs.animateTo(i);
                      setState(() {});
                    }
                  },
                  borderRadius: BorderRadius.circular(11),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: active
                          ? LinearGradient(
                              colors: grad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: grad.last.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 15,
                              color: active ? Colors.white : context.txt3,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: GF.body(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: active ? Colors.white : context.txt3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ── Callback type ─────────────────────────────────────────────
typedef PlayerCallback = void Function(
  BuildContext context, {
  required String url,
  required String title,
  String subtitle,
  String category,
  ChannelModel? channel,
  String? browseCategory,
});

// ── HOME TAB ──────────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  final AppProvider prov;
  final PlayerCallback onPlay;
  final String? highlightCategory;
  final ValueChanged<String>? onCategoryTap;

  const _HomeTab({
    required this.prov,
    required this.onPlay,
    this.highlightCategory,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final liveEvents = prov.sortedLiveEvents;
    final featuredEvents = prov.featuredLiveEvents;
    final showFeaturedSection = prov.featuredLiveEventsLoading ||
        featuredEvents.isNotEmpty;
    final showLiveEventsSection =
        prov.liveEventsLoading || liveEvents.isNotEmpty;
    final cats = prov.homeCategoryTiles.isNotEmpty
        ? prov.homeCategoryTiles
        : AppProvider.homeCategories;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: prov.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: PerformanceTuning.listCacheExtent,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          if (prov.channelsLoading && prov.channels.isEmpty)
            const ChannelListSkeleton(count: 5),
          if (AdManager.instance.adsEnabled) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: AdsterraNativeBanner(
                height: 100,
                placement: 'home_native_top',
              ),
            ),
          ],
          const HomeSectionHeader(
            title: 'Browse',
            subtitle: 'Tap a category to explore live channels',
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HomeCategoryGrid(
              prov: prov,
              categories: cats,
              highlightCategory: highlightCategory,
              onCategoryTap: onCategoryTap,
            ),
          ),
          if (showFeaturedSection) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              title: prov.featuredLiveEventsSectionTitle,
              trailing: prov.featuredLiveEventsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : _LiveBadge(label: '${featuredEvents.length} featured'),
            ),
            if (prov.featuredLiveEventsSectionSubtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  prov.featuredLiveEventsSectionSubtitle,
                  style: TextStyle(fontSize: 11, color: context.txt3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (prov.featuredLiveEventsLoading &&
                !prov.hasFeaturedLiveEventsData &&
                featuredEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Loading featured matches…',
                  style: TextStyle(fontSize: 12, color: context.txt3),
                ),
              )
            else
              ...featuredEvents.map(
                (e) => RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _LiveEventCard(event: e),
                  ),
                ),
              ),
          ],
          if (showLiveEventsSection) ...[
            const SizedBox(height: 16),
            _SectionHeader(
              title: 'All Live Events',
              trailing: prov.liveEventsLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : _LiveBadge(label: '${liveEvents.length} events'),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'FootyStream + ESPN/Cricbuzz — same match shown once',
                style: TextStyle(fontSize: 11, color: context.txt3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            if (prov.liveEventsLoading &&
                !prov.hasLiveEventsData &&
                liveEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Loading live events…',
                  style: TextStyle(fontSize: 12, color: context.txt3),
                ),
              )
            else
              ...liveEvents.map(
                (e) => RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _LiveEventCard(event: e),
                  ),
                ),
              ),
          ],
          if (AdManager.instance.adsEnabled) ...[
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: AdsterraBanner728(placement: 'home_bottom_banner'),
            ),
          ],
          const SizedBox(height: 72),
        ],
      ),
    );
  }
}

// ── LIVE NOW TAB ──────────────────────────────────────────────
class _LiveNowTab extends StatefulWidget {
  final AppProvider prov;
  final PlayerCallback onPlay;
  const _LiveNowTab({required this.prov, required this.onPlay});

  @override
  State<_LiveNowTab> createState() => _LiveNowTabState();
}

class _LiveNowTabState extends State<_LiveNowTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prov = widget.prov;
    final events = prov.sortedLiveEvents;
    final empty = events.isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        _SectionHeader(
          title: 'All Live Events',
          trailing: prov.liveEventsLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : _LiveBadge(label: '${events.length} events'),
        ),
        const SizedBox(height: 10),
        if (prov.liveEventsLoading && !prov.hasLiveEventsData && empty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Loading live events…',
              style: TextStyle(fontSize: 12, color: context.txt3),
            ),
          )
        else if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'আজকে কোনো live event নেই',
              style: TextStyle(fontSize: 12, color: context.txt3),
            ),
          )
        else
          ...events.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _LiveEventCard(event: e),
            ),
          ),
      ],
    );
  }
}

// ── TODAY TAB ─────────────────────────────────────────────────
class _TodayTab extends StatelessWidget {
  final AppProvider prov;
  final PlayerCallback onPlay;
  const _TodayTab({required this.prov, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        _SectionHeader(
          title: "Today's Schedule",
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF0D3D1A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'FootyStream · ${DateTime.now().day}/${DateTime.now().month}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Today: FootyStream schedule merged with ESPN/Cricbuzz scores',
            style: TextStyle(fontSize: 11, color: context.txt3),
          ),
        ),
        const SizedBox(height: 10),
        ...prov.todayMatches.map((m) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _TodayCard(
                match: m,
                onTap: () => onPlay(
                  context,
                  url: m.streamUrl,
                  title: '${m.teamA} vs ${m.teamB}',
                  subtitle: '${m.sport} • ${m.channel}',
                  category: 'Sports',
                  browseCategory: 'Sports',
                ),
              ),
            )),
      ],
    );
  }
}

// ── UPCOMING TAB ──────────────────────────────────────────────
class _UpcomingTab extends StatelessWidget {
  final AppProvider prov;
  final PlayerCallback onPlay;
  const _UpcomingTab({required this.prov, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      children: [
        _SectionHeader(
          title: 'Upcoming Events',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: const Color(0xFF1A1A3A),
                borderRadius: BorderRadius.circular(12)),
            child: Text('${prov.upcomingMatches.length} events',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue)),
          ),
        ),
        const SizedBox(height: 10),
        ...prov.upcomingMatches.map((m) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _UpcomingCard(
                match: m,
                onTap: () => onPlay(
                  context,
                  url: m.streamUrl,
                  title: '${m.teamA} vs ${m.teamB}',
                  subtitle: '${m.sport} • ${m.time}',
                  category: 'Sports',
                  browseCategory: 'Sports',
                ),
              ),
            )),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
// CARD WIDGETS
// ═════════════════════════════════════════════════════════════

class ScoreCardsSection extends StatelessWidget {
  final String title;
  final List<MatchModel> matches;
  final bool loading;
  final PlayerCallback onPlay;

  const ScoreCardsSection({
    required this.title,
    required this.matches,
    required this.loading,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          trailing: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : _LiveBadge(label: '● ${matches.length} matches'),
        ),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'আজকে এই সেকশনে কোনো ম্যাচ নেই',
              style: TextStyle(fontSize: 12, color: context.txt3),
            ),
          )
        else
          LayoutBuilder(
            builder: (ctx, constraints) {
              final screenW = MediaQuery.sizeOf(ctx).width;
              final cardW = (screenW * 0.76).clamp(210.0, 320.0);
              const listH = 172.0;
              return SizedBox(
                height: listH,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final m = matches[i];
                    return SizedBox(
                      width: cardW,
                      height: listH,
                      child: _ScoreCard(
                        match: m,
                        onTap: m.streamUrl.isNotEmpty
                            ? () => onPlay(
                                  context,
                                  url: m.streamUrl,
                                  title: '${m.teamA} vs ${m.teamB}',
                                  subtitle:
                                      '${m.sport} • ${m.channel.isNotEmpty ? m.channel : m.scoreSource}',
                                  category: 'Sports',
                                  browseCategory: 'Sports',
                                )
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  const _ScoreCard({required this.match, this.onTap});

  String get _scoreA => match.scoreA.trim();
  String get _scoreB => match.scoreB.trim();

  bool get _hasScores => _scoreA.isNotEmpty || _scoreB.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final statusLabel = match.isLive
        ? '● LIVE'
        : match.isFinished
            ? 'FT'
            : match.time;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: context.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.brd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.channel.isNotEmpty
                        ? match.channel
                        : (match.scoreSource.isNotEmpty
                            ? match.scoreSource
                            : match.sport.toUpperCase()),
                    style: TextStyle(
                      fontSize: 9,
                      color: context.txt3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: match.isLive ? AppColors.accentDim : context.bg3,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: match.isLive ? AppColors.accent : context.txt3,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_hasScores || match.isLive || match.isFinished) ...[
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _hasScores
                            ? '${_scoreA.isEmpty ? '0' : _scoreA} - ${_scoreB.isEmpty ? '0' : _scoreB}'
                            : (match.isLive ? 'LIVE' : '—'),
                        style: const TextStyle(
                          fontFamily: 'BarlowCondensed',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  _teamLine(context, match.teamA),
                  const SizedBox(height: 4),
                  _teamLine(context, match.teamB),
                  if (!_hasScores && !match.isLive && match.time.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      match.time,
                      style: TextStyle(fontSize: 10, color: context.txt3),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamLine(BuildContext ctx, String team) => Row(
        children: [
          Text(match.sportEmoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              team,
              style: TextStyle(
                fontSize: 11,
                color: ctx.txt2,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
}

List<Color> _liveEventCardGradient(MatchModel m, bool effectiveLive) {
  final sport = m.sport.toLowerCase();
  if (effectiveLive) {
    return switch (sport) {
      'cricket' => const [
          Color(0xFF004D40),
          Color(0xFF00897B),
          Color(0xFF1B5E20),
        ],
      'football' => const [
          Color(0xFF0D47A1),
          Color(0xFF1976D2),
          Color(0xFF00695C),
        ],
      'basketball' => const [
          Color(0xFFE65100),
          Color(0xFFFF6F00),
          Color(0xFF4A148C),
        ],
      _ => const [
          Color(0xFF4A148C),
          Color(0xFF7B1FA2),
          Color(0xFF1565C0),
        ],
    };
  }
  return switch (sport) {
    'cricket' => const [
        Color(0xFF1B4332),
        Color(0xFF2D6A4F),
        Color(0xFF081C15),
      ],
    'football' => const [
        Color(0xFF0D1B2A),
        Color(0xFF1B3A5C),
        Color(0xFF081C15),
      ],
    _ => const [
        Color(0xFF1A1A2E),
        Color(0xFF2D2D44),
        Color(0xFF0F0F1A),
      ],
  };
}

String _browseCategoryForMatch(MatchModel m) {
  final blob = '${m.teamA} ${m.teamB} ${m.channel}'.toLowerCase();
  if (blob.contains('bangladesh')) return 'Bangladesh';
  if (blob.contains('pakistan')) return 'Pakistan';
  if (blob.contains('india')) return 'India';
  return 'Sports';
}

class _LiveEventCard extends StatefulWidget {
  final LiveEventMatch event;

  const _LiveEventCard({required this.event});

  @override
  State<_LiveEventCard> createState() => _LiveEventCardState();
}

class _LiveEventCardState extends State<_LiveEventCard> {
  Timer? _tick;

  bool _needsTick(MatchModel m) {
    if (m.isLive || m.isFinished) return false;
    return m.isUpcoming ||
        BdtTime.untilKickoff(m.matchDate).inSeconds > 0;
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    if (_needsTick(widget.event.match)) _startTick();
  }

  @override
  void didUpdateWidget(covariant _LiveEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.match.id != widget.event.match.id) {
      _tick?.cancel();
      _tick = null;
      if (_needsTick(widget.event.match)) _startTick();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _openChannelsPopup(
    BuildContext context, {
    required LiveEventMatch event,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => _LiveEventChannelsDialog(
        event: event,
        parentContext: context,
      ),
    );
  }

  bool _showScheduleFooter(MatchModel m, bool effectiveLive, bool finished) {
    if (effectiveLive || finished || m.isLive) return false;
    if (BdtTime.untilKickoff(m.matchDate).inSeconds > 0) return true;
    return m.isUpcoming && m.time.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final m = event.match;
    final effectiveLive = m.isLive ||
        (m.isUpcoming &&
            BdtTime.untilKickoff(m.matchDate).inSeconds <= 0);
    final finished = m.isFinished;
    final showFooter = _showScheduleFooter(m, effectiveLive, finished);
    final hasScores = m.scoreA.trim().isNotEmpty || m.scoreB.trim().isNotEmpty;
    final gradient = _liveEventCardGradient(m, effectiveLive);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openChannelsPopup(context, event: event),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            border: Border.all(
              color: effectiveLive
                  ? AppColors.accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.12),
              width: effectiveLive ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (effectiveLive ? AppColors.accent : gradient.first)
                    .withValues(alpha: effectiveLive ? 0.28 : 0.18),
                blurRadius: effectiveLive ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                right: -28,
                top: 8,
                child: Opacity(
                  opacity: 0.16,
                  child: TeamAvatar(
                    name: m.teamA,
                    logoUrl: m.teamALogo,
                    sport: m.sport,
                    size: 96,
                  ),
                ),
              ),
              Positioned(
                left: -24,
                bottom: 4,
                child: Opacity(
                  opacity: 0.12,
                  child: TeamAvatar(
                    name: m.teamB,
                    logoUrl: m.teamBLogo,
                    sport: m.sport,
                    size: 80,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SportChip(
                        sport: m.sport,
                        onGradient: true,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.tournament,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.2,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (effectiveLive)
                        _LiveCornerBadge(onGradient: true)
                      else if (finished)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'FINAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white60,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LiveEventTeamRow(
                    name: m.teamA,
                    logoUrl: m.teamALogo,
                    sport: m.sport,
                    score: _displayScore(
                      m.scoreA,
                      showScores: hasScores || effectiveLive || finished,
                    ),
                    emphasizeScore:
                        effectiveLive && m.scoreA.trim().isNotEmpty,
                    onGradient: true,
                  ),
                  const SizedBox(height: 12),
                  _LiveEventTeamRow(
                    name: m.teamB,
                    logoUrl: m.teamBLogo,
                    sport: m.sport,
                    score: _displayScore(
                      m.scoreB,
                      showScores: hasScores || effectiveLive || finished,
                    ),
                    emphasizeScore:
                        effectiveLive && m.scoreB.trim().isNotEmpty,
                    onGradient: true,
                  ),
                  if (showFooter) ...[
                    const SizedBox(height: 14),
                    _LiveEventCardFooter(match: m, onGradient: true),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayScore(String raw, {required bool showScores}) {
    if (!showScores) return '';
    final s = raw.trim();
    return s.isEmpty ? '—' : s;
  }
}

class _SportChip extends StatelessWidget {
  final String sport;
  final bool onGradient;

  const _SportChip({required this.sport, this.onGradient = false});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (sport.toLowerCase()) {
      'cricket' => '🏏',
      'football' => '⚽',
      'basketball' => '🏀',
      'tennis' => '🎾',
      _ => '🏆',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: onGradient
            ? Colors.white.withValues(alpha: 0.16)
            : context.bg3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onGradient
              ? Colors.white.withValues(alpha: 0.22)
              : context.brd.withValues(alpha: 0.8),
        ),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 13, height: 1.1)),
    );
  }
}

/// Team crest + name; score aligned right (ESPN / Cricbuzz).
class _LiveEventTeamRow extends StatelessWidget {
  final String name;
  final String logoUrl;
  final String sport;
  final String score;
  final bool emphasizeScore;
  final bool onGradient;

  const _LiveEventTeamRow({
    required this.name,
    required this.logoUrl,
    required this.sport,
    required this.score,
    this.emphasizeScore = false,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = onGradient ? Colors.white : context.txt;
    final scoreColor = onGradient
        ? (emphasizeScore ? AppColors.accent : Colors.white)
        : (emphasizeScore ? context.scoreLive : context.txt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: onGradient ? 0.35 : 0),
              width: 1.5,
            ),
            boxShadow: onGradient
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: TeamAvatar(
            name: name,
            logoUrl: logoUrl,
            sport: sport,
            size: 46,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: nameColor,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                score,
                style: GF.head(
                  fontSize: emphasizeScore ? 22 : 18,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                  height: 1,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// LIVE pill — top-right of event card header.
class _LiveCornerBadge extends StatelessWidget {
  final bool onGradient;

  const _LiveCornerBadge({this.onGradient = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: onGradient
                  ? AppColors.accent
                  : (context.isDark
                      ? AppColors.liveRed
                      : const Color(0xFFC62828)),
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
}

/// Footer: live countdown (primary) + schedule time (subtitle).
class _LiveEventCardFooter extends StatefulWidget {
  final MatchModel match;
  final bool onGradient;

  const _LiveEventCardFooter({
    required this.match,
    this.onGradient = false,
  });

  @override
  State<_LiveEventCardFooter> createState() => _LiveEventCardFooterState();
}

class _LiveEventCardFooterState extends State<_LiveEventCardFooter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = BdtTime.untilKickoff(widget.match.matchDate);
    final showSchedule = remaining.inSeconds > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: widget.onGradient
            ? Colors.white.withValues(alpha: 0.12)
            : (context.isDark
                ? context.bg3.withValues(alpha: 0.65)
                : context.bg3.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.onGradient
              ? Colors.white.withValues(alpha: 0.2)
              : context.brd,
        ),
      ),
      child: Column(
        children: [
          Text(
            BdtTime.formatCountdownLabel(widget.match.matchDate),
            style: GF.head(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: widget.onGradient ? Colors.white : context.txt2,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          if (showSchedule) ...[
            const SizedBox(height: 4),
            Text(
              BdtTime.formatScheduleSubtitle(widget.match.matchDate),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: widget.onGradient ? Colors.white60 : context.txt3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Center popup — all matched channels unlocked; tap opens player immediately.
class _LiveEventChannelsDialog extends StatefulWidget {
  final LiveEventMatch event;
  final BuildContext parentContext;

  const _LiveEventChannelsDialog({
    required this.event,
    required this.parentContext,
  });

  @override
  State<_LiveEventChannelsDialog> createState() =>
      _LiveEventChannelsDialogState();
}

class _LiveEventChannelsDialogState extends State<_LiveEventChannelsDialog> {
  void _onLinkTap(ChannelModel ch, StreamLink link) {
    Navigator.pop(context);
    openChannelPlayer(
      widget.parentContext,
      channel: ch,
      subtitle: widget.event.tournament,
      browseCategory: _browseCategoryForMatch(widget.event.match),
      initialStreamUrl: link.url,
    );
  }

  List<({ChannelModel ch, StreamLink link})> _linkRows(List<ChannelModel> channels) {
    final rows = <({ChannelModel ch, StreamLink link})>[];
    final seenUrls = <String>{};
    for (final ch in channels) {
      for (final link in ch.allStreams) {
        if (link.url.isEmpty) continue;
        if (seenUrls.add(link.url)) {
          rows.add((ch: ch, link: link));
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final m = widget.event.match;
    final channels = widget.event.relatedChannels;
    final browseCat = _browseCategoryForMatch(m);
    final recommended = prov
        .recommendedChannels(category: browseCat)
        .where((c) => !channels.any((x) => x.id == c.id))
        .take(8)
        .toList();
    final linkRows = _linkRows(channels);
    final size = MediaQuery.sizeOf(context);
    final dialogW = (size.width * 0.92).clamp(280.0, 420.0);
    final maxH = size.height * 0.72;

    return Dialog(
      backgroundColor: context.bg2,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: context.brd),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: (size.width - dialogW) / 2,
        vertical: size.height * 0.08,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogW, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                children: [
                  Text(
                    'Watch on Channel',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.txt,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TeamAvatar(
                        name: m.teamA,
                        logoUrl: m.teamALogo,
                        sport: m.sport,
                        size: 36,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.txt3,
                          ),
                        ),
                      ),
                      TeamAvatar(
                        name: m.teamB,
                        logoUrl: m.teamBLogo,
                        sport: m.sport,
                        size: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${m.teamA} vs ${m.teamB}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.txt2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All channels unlocked — tap to watch',
                    style: TextStyle(fontSize: 11, color: context.txt3),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.brd),
            if (linkRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                child: Text(
                  'No channels found for this match',
                  style: TextStyle(fontSize: 14, color: context.txt3),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    ...linkRows.map((row) {
                      final ch = row.ch;
                      final link = row.link;
                      final urlLive = prov.isStreamUrlLive(link.url);
                      final multi = ch.hasMultipleUserStreams;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onLinkTap(ch, link),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ch.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: context.txt,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (multi)
                                        Text(
                                          link.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.txt3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                if (urlLive)
                                  const Text(
                                    '● LIVE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.play_circle_filled_rounded,
                                    size: 24,
                                    color: AppColors.accent.withValues(
                                      alpha: 0.85,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (recommended.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                        child: Text(
                          'RECOMMENDED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: context.txt3,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      ...recommended.expand((ch) {
                        return ch.userStreamLinks.map((link) {
                          final urlLive = prov.isStreamUrlLive(link.url);
                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 18),
                            title: Text(
                              ch.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.txt2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: urlLive
                                ? const Text(
                                    '● LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  )
                                : null,
                            onTap: () => _onLinkTap(ch, link),
                          );
                        });
                      }),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  const _TodayCard({required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
            color: context.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.brd)),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: context.bg3, borderRadius: BorderRadius.circular(10)),
            child: Center(
                child: Text(match.sportEmoji,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${match.teamA} vs ${match.teamB}',
                  style: TextStyle(
                      fontSize: 12,
                      color: context.txt,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              Text('${match.sport} • ${match.channel}',
                  style: TextStyle(fontSize: 10, color: context.txt3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ]),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.isLive ? '● LIVE' : match.time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        match.isLive ? AppColors.accent : AppColors.green,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (match.isLive && match.scoreA.isNotEmpty)
                  Text(
                    '${match.scoreA}-${match.scoreB}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.txt,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'vs',
                    style: TextStyle(fontSize: 12, color: context.txt3),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  final MatchModel match;
  final VoidCallback? onTap;
  const _UpcomingCard({required this.match, this.onTap});

  static const _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC'
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: context.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.brd)),
        child: Row(children: [
          // Date box — fixed size
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
                color: context.bg3, borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${match.matchDate.day}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.txt,
                      height: 1)),
              Text(_months[match.matchDate.month - 1],
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: context.txt3)),
            ]),
          ),
          const SizedBox(width: 10),
          // Content — Expanded prevents overflow
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${match.teamA}${match.teamB.isNotEmpty ? " vs ${match.teamB}" : ""}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.txt),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              // ✅ Fix: long text wrapped in separate lines
              Text('${match.sport} • ${match.time}',
                  style: TextStyle(fontSize: 10, color: context.txt3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              Text(match.channel,
                  style: TextStyle(fontSize: 10, color: context.txt3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: context.bg3, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  match.sport,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: context.txt3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          // Bell icon — fixed size
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: context.bg3,
                shape: BoxShape.circle,
                border: Border.all(color: context.brd)),
            child:
                Icon(Icons.notifications_none, size: 15, color: context.txt2),
          ),
        ]),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
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
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  final String label;
  const _LiveBadge({this.label = '● LIVE'});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.2).animate(_c),
        child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle)),
      );
}
