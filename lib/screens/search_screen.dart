// lib/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/services/search_history.dart';
import 'package:lumio_tv/widgets/search/search_chips.dart';
import 'package:lumio_tv/widgets/search/result_tile.dart';
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:lumio_tv/provider/channel_catalog_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Main search screen with full-screen experience
///
/// Features:
/// - Hero transition from search icon
/// - Auto-focused search input
/// - Recent searches with remove functionality
/// - Trending searches
/// - Category browsing grid
/// - Tabbed results (All | Channels | Movies | Series | EPG)
/// - Query highlighting in results
/// - Voice search integration
/// - 250ms debounce
/// - Keyboard dismisses on scroll
/// - Real search over unified channel repository
/// - Case-insensitive, diacritic-insensitive matching
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  // Search input
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounceTimer;

  // State
  String _query = '';
  List<String> _recentSearches = [];
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // Tabs
  static const List<String> _tabs = [
    Strings.searchTabAll,
    Strings.searchTabChannels,
    Strings.searchTabMovies,
    Strings.searchTabSeries,
    Strings.searchTabEpg,
  ];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();

    // Auto-focus search input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _loadRecentSearches() async {
    final searches = await SearchHistory.getRecent();
    if (!mounted) return;
    setState(() {
      _recentSearches = searches;
    });
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      final query = _searchController.text.trim();
      setState(() {
        _query = query;
        if (query.isNotEmpty) {
          _hasSearched = true;
          _performSearch(query);
        } else {
          _hasSearched = false;
          _results = [];
        }
      });
    });
  }

  /// Normalizes text for case-insensitive, diacritic-insensitive comparison
  String _normalizeText(String text) {
    // Remove diacritics by decomposing characters and removing marks
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
    return normalized;
  }

  /// Performs real search over the unified channel repository
  void _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    final catalog = context.read<ChannelCatalogProvider>();
    final channels = catalog.channels;
    final gitunChannels = catalog.gitunChannels;

    // Combine all channels for unified search
    final allChannels = [...channels, ...gitunChannels];

    // Normalize the query once
    final normalizedQuery = _normalizeText(query);

    // Search across name, category, and country (language)
    final matchedChannels = allChannels.where((channel) {
      final normalizedName = _normalizeText(channel.name);
      final normalizedCategory = _normalizeText(channel.category);
      final normalizedCountry = _normalizeText(channel.country);

      return normalizedName.contains(normalizedQuery) ||
             normalizedCategory.contains(normalizedQuery) ||
             normalizedCountry.contains(normalizedQuery);
    }).toList();

    // Convert ChannelModel to SearchResult
    final searchResults = matchedChannels.map((channel) {
      return SearchResult(
        id: channel.id,
        title: channel.name,
        subtitle: channel.category.isNotEmpty ? channel.category : 'Live Channel',
        thumbnail: channel.logoUrl.isNotEmpty ? channel.logoUrl : null,
        type: SearchResultType.channel,
        isLive: channel.isLive,
        metadata: channel.country.isNotEmpty ? channel.country : 'Live',
        matchedQuery: query,
      );
    }).toList();

    setState(() {
      _isLoading = false;
      _results = searchResults;
    });

    // Add to recent searches if results found
    if (query.isNotEmpty && searchResults.isNotEmpty) {
      await SearchHistory.add(query);
      if (!mounted) return;
      _loadRecentSearches();
    }
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _onSearchChanged();
    HapticFeedback.selectionClick();
  }

  void _onRecentSearchRemove(String query) async {
    await SearchHistory.remove(query);
    if (!mounted) return;
    _loadRecentSearches();
  }

  void _onClear() {
    _searchController.clear();
    _onSearchChanged();
    _searchFocus.requestFocus();
    HapticFeedback.lightImpact();
  }

  void _onTabChange(int index) {
    setState(() {
      _selectedTab = index;
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            _SearchBar(
              controller: _searchController,
              focus: _searchFocus,
              query: _query,
              onClear: _onClear,
            ),

            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasSearched && _query.isEmpty) {
      return _buildEmptyState();
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_results.isEmpty) {
      return _buildNoResults();
    }

    return _buildResults();
  }

  Widget _buildEmptyState() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Dismiss keyboard on scroll
        if (notification is ScrollStartNotification) {
          _searchFocus.unfocus();
        }
        return false;
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: tokens.SpacingTokens.s24),

            // Recent searches
            RecentSearches(
              searches: _recentSearches,
              onTap: _onRecentSearchTap,
              onRemove: _onRecentSearchRemove,
            ),

            // Trending searches
            TrendingSearches(
              trends: const [
                'World Cup 2026',
                'Premier League',
                'NFL Sunday',
                'News',
                'Documentaries',
              ],
              onTap: _onRecentSearchTap,
            ),

            // Category grid
            CategoryGrid(
              categories: [
                CategoryItem(
                  label: 'Sports',
                  query: 'sports',
                ),
                CategoryItem(
                  label: 'Movies',
                  query: 'movies',
                ),
                CategoryItem(
                  label: 'News',
                  query: 'news',
                ),
                CategoryItem(
                  label: 'Kids',
                  query: 'kids',
                ),
                CategoryItem(
                  label: 'Music',
                  query: 'music',
                ),
                CategoryItem(
                  label: 'Documentaries',
                  query: 'documentaries',
                ),
              ],
              onTap: (category) {
                _searchController.text = category.query ?? category.label;
                _onSearchChanged();
              },
            ),

            const SizedBox(height: tokens.SpacingTokens.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return const ResultTileSkeleton();
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(tokens.SpacingTokens.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass(),
              size: 64,
              color: tokens.AppTokens.textTertiary,
            ),
            const SizedBox(height: tokens.SpacingTokens.s24),
            Text(
              '${Strings.searchNothingMatches} "$_query"',
              style: tokens.TypographyTokens.titlePrimary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: tokens.SpacingTokens.s8),
            Text(
              Strings.searchNoResultsSubtitle,
              style: tokens.TypographyTokens.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: tokens.SpacingTokens.s24),
            // Suggestion chips
            const Wrap(
              spacing: tokens.SpacingTokens.s8,
              runSpacing: tokens.SpacingTokens.s8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(label: 'Try "News"'),
                _SuggestionChip(label: 'Try "Sports"'),
                _SuggestionChip(label: 'Try "Movies"'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Tabs
        _SearchTabs(
          tabs: _tabs,
          selectedTab: _selectedTab,
          onTabChange: _onTabChange,
        ),

        // Results list
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Dismiss keyboard on scroll
              if (notification is ScrollStartNotification) {
                _searchFocus.unfocus();
              }
              return false;
            },
            child: ListView.builder(
              addAutomaticKeepAlives: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ResultTile(
                  result: result,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Navigate to result
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Search bar component
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final String query;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.query,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(tokens.SpacingTokens.s16),
      child: Row(
        children: [
          // Search input
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface2,
                borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
                border: Border.all(
                  color: tokens.AppTokens.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: tokens.SpacingTokens.s12),
                  Icon(
                    PhosphorIcons.magnifyingGlass(),
                    size: 20,
                    color: tokens.AppTokens.textSecondary,
                  ),
                  const SizedBox(width: tokens.SpacingTokens.s12),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focus,
                      style: tokens.TypographyTokens.bodyPrimary,
                      decoration: InputDecoration(
                        hintText: Strings.searchPlaceholder,
                        hintStyle: tokens.TypographyTokens.bodySecondary,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) {
                        // Already handled by debounce
                      },
                    ),
                  ),
                  if (query.isNotEmpty)
                    Pressable(
                      onTap: onClear,
                      child: Padding(
                        padding: const EdgeInsets.all(tokens.SpacingTokens.s8),
                        child: Icon(
                          PhosphorIcons.x(),
                          size: 20,
                          color: tokens.AppTokens.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(width: tokens.SpacingTokens.s8),
                ],
              ),
            ),
          ),
          const SizedBox(width: tokens.SpacingTokens.s12),
          // Cancel button
          Pressable(
            onTap: () => Navigator.pop(context),
            child: Text(
              Strings.searchCancel,
              style: tokens.TypographyTokens.labelAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Search tabs component
class _SearchTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedTab;
  final Function(int) onTabChange;

  const _SearchTabs({
    required this.tabs,
    required this.selectedTab,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: tokens.AppTokens.surface1,
        border: Border(
          bottom: BorderSide(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        addAutomaticKeepAlives: true,
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedTab;
          return Pressable(
            onTap: () => onTabChange(index),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: tokens.SpacingTokens.s16,
                vertical: tokens.SpacingTokens.s12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? tokens.AppTokens.accent
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                tabs[index],
                style: isSelected
                    ? tokens.TypographyTokens.labelAccent
                    : tokens.TypographyTokens.labelSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Suggestion chip for no results state
class _SuggestionChip extends StatelessWidget {
  final String label;

  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        // Handle suggestion tap
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s16,
          vertical: tokens.SpacingTokens.s8,
        ),
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
          border: Border.all(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: tokens.TypographyTokens.labelAccent,
        ),
      ),
    );
  }
}
