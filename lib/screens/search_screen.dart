// lib/screens/search_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/services/search_history.dart';
import 'package:lumio_tv/widgets/search/search_chips.dart';
import 'package:lumio_tv/widgets/search/result_tile.dart';
import 'package:lumio_tv/widgets/common/pressable.dart';
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
/// - 300ms debounce
/// - Keyboard dismisses on scroll
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
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
  
  // Voice search
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
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

  void _initSpeech() async {
    await _speechToText.initialize();
  }

  void _loadRecentSearches() async {
    final searches = await SearchHistory.getRecent();
    setState(() {
      _recentSearches = searches;
    });
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
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

  void _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    // Simulate search delay (replace with actual search logic)
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock search results (replace with actual data fetching)
    final mockResults = _generateMockResults(query);

    setState(() {
      _isLoading = false;
      _results = mockResults;
    });

    // Add to recent searches if not empty
    if (query.isNotEmpty && mockResults.isNotEmpty) {
      await SearchHistory.add(query);
      _loadRecentSearches();
    }
  }

  List<SearchResult> _generateMockResults(String query) {
    // Mock data for demonstration
    return [
      SearchResult(
        id: '1',
        title: 'BBC One',
        subtitle: 'Currently: News at Ten',
        thumbnail: null,
        type: SearchResultType.channel,
        isLive: true,
        metadata: 'Live UK',
        matchedQuery: query,
      ),
      SearchResult(
        id: '2',
        title: 'Movie: The Dark Knight',
        subtitle: 'Action • 2008',
        thumbnail: null,
        type: SearchResultType.movie,
        isLive: false,
        metadata: '2h 32m • PG-13',
        matchedQuery: query,
      ),
    ];
  }

  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _onSearchChanged();
    HapticFeedback.selectionClick();
  }

  void _onRecentSearchRemove(String query) async {
    await SearchHistory.remove(query);
    _loadRecentSearches();
  }

  void _onClear() {
    _searchController.clear();
    _onSearchChanged();
    _searchFocus.requestFocus();
    HapticFeedback.lightImpact();
  }

  void _onCancel() {
    Navigator.pop(context);
  }

  void _onVoiceSearch() async {
    if (!_isListening) {
      final available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _searchController.text = result.recognizedWords;
            });
            if (result.finalResult) {
              setState(() {
                _isListening = false;
              });
              _onSearchChanged();
            }
          },
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speechToText.stop();
    }
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
              isListening: _isListening,
              onClear: _onClear,
              onCancel: _onCancel,
              onVoiceSearch: _onVoiceSearch,
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
            SizedBox(height: tokens.SpacingTokens.s24),

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

            SizedBox(height: tokens.SpacingTokens.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return ResultTileSkeleton();
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.SpacingTokens.s32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass(),
              size: 64,
              color: tokens.AppTokens.textTertiary,
            ),
            SizedBox(height: tokens.SpacingTokens.s24),
            Text(
              '${Strings.searchNothingMatches} "$_query"',
              style: tokens.TypographyTokens.titlePrimary,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.SpacingTokens.s8),
            Text(
              Strings.searchNoResultsSubtitle,
              style: tokens.TypographyTokens.bodySecondary,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.SpacingTokens.s24),
            // Suggestion chips
            Wrap(
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
  final bool isListening;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onVoiceSearch;

  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.query,
    required this.isListening,
    required this.onClear,
    required this.onCancel,
    required this.onVoiceSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(tokens.SpacingTokens.s16),
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
                  color: isListening 
                      ? tokens.AppTokens.accent 
                      : tokens.AppTokens.border,
                  width: isListening ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(width: tokens.SpacingTokens.s12),
                  Icon(
                    isListening ? PhosphorIcons.microphone() : PhosphorIcons.magnifyingGlass(),
                    size: 20,
                    color: isListening 
                        ? tokens.AppTokens.accent 
                        : tokens.AppTokens.textSecondary,
                  ),
                  SizedBox(width: tokens.SpacingTokens.s12),
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
                        padding: EdgeInsets.all(tokens.SpacingTokens.s8),
                        child: Icon(
                          PhosphorIcons.x(),
                          size: 20,
                          color: tokens.AppTokens.textSecondary,
                        ),
                      ),
                    ),
                  SizedBox(width: tokens.SpacingTokens.s8),
                ],
              ),
            ),
          ),
          SizedBox(width: tokens.SpacingTokens.s12),
          // Cancel button
          Pressable(
            onTap: onCancel,
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
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface1,
        border: Border(
          bottom: BorderSide(
            color: tokens.AppTokens.border,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == selectedTab;
          return Pressable(
            onTap: () => onTabChange(index),
            child: Container(
              padding: EdgeInsets.symmetric(
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
        padding: EdgeInsets.symmetric(
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