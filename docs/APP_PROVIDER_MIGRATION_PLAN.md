# AppProvider Consumer Migration Plan

## Consumer Analysis

Found 11 files with 20 AppProvider consumer locations:

### 1. score_state_widget.dart (1 match)
- Uses: `scoreState` 
- Target: **LiveScoreProvider**
- Priority: HIGH (used in multiple places)

### 2. tv_screen.dart (6 matches)
- Uses: `search()`, `sortedLiveEvents`, `featuredLiveEvents`, `todayMatches`, `upcomingMatches`, event data
- Target: **LiveEventsProvider**, **LiveScoreProvider**, **ChannelCatalogProvider**
- Priority: MEDIUM (complex file with multiple providers)

### 3. splash_screen.dart (1 match)
- Uses: `isDark`
- Target: **ThemeProvider**
- Priority: LOW (simple, one property)

### 4. app_drawer.dart (1 match)
- Uses: `isDark`
- Target: **ThemeProvider**
- Priority: LOW (simple, one property)

### 5. shell_app_bar.dart (1 match)
- Uses: `favoriteCount`
- Target: **FavoritesProvider**
- Priority: MEDIUM (visible component)

### 6. news_article_card.dart (2 matches)
- Uses: `isPendingNewsArticle`
- Target: **UiStateProvider** (not part of new provider set)
- Action: Keep using AppProvider or direct UiStateProvider
- Priority: LOW (already delegated to UiStateProvider)

### 7. common/widgets.dart (1 match)
- Uses: `isStreamLive`
- Target: **ChannelCatalogProvider**
- Action: Already exists, keep using it directly
- Priority: NONE

### 8. other_screens.dart (4 matches)
- Uses: TabAdOverlay (unknown), `liveTabChannels`, `categoriesGenreRows`, `isStreamLive`
- Target: **ChannelCatalogProvider**
- Action: Already exists, keep using it directly
- Priority: NONE

### 9. news_screen.dart (1 match)
- Uses: `premierLeagueScoreMatches`, `news`
- Target: **LiveScoreProvider**, **NewsProvider**
- Priority: MEDIUM (uses 2 new providers)

### 10. favorites_screen.dart (1 match)
- Uses: `favoriteChannels`
- Target: **FavoritesProvider**
- Priority: HIGH (dedicated favorites screen)

### 11. category_channels_screen.dart (1 match)
- Uses: Channel data
- Target: **ChannelCatalogProvider**
- Action: Already exists, keep using it directly
- Priority: NONE

## Migration Priority Order

### Phase 3.1: Simple Single-Provider Migrations (1 hour)
1. ✅ splash_screen.dart - ThemeProvider
2. ✅ app_drawer.dart - ThemeProvider
3. ✅ shell_app_bar.dart - FavoritesProvider
4. ✅ favorites_screen.dart - FavoritesProvider
5. ✅ score_state_widget.dart - LiveScoreProvider

### Phase 3.2: Multi-Provider Migrations (2 hours)
6. ✅ news_screen.dart - LiveScoreProvider + NewsProvider
7. ✅ tv_screen.dart - LiveEventsProvider + LiveScoreProvider

### Phase 3.3: Keep as-is (0 hours)
8. news_article_card.dart - UiStateProvider (not in scope)
9. common/widgets.dart - ChannelCatalogProvider (already focused)
10. other_screens.dart - ChannelCatalogProvider (already focused)
11. category_channels_screen.dart - ChannelCatalogProvider (already focused)

## Migration Strategy

For each file:
1. Import the new provider
2. Replace `context.watch<AppProvider>()` with specific provider
3. Use `context.select()` for single property access where possible
4. Test the screen
5. Verify no breaking changes

## Notes

- ChannelCatalogProvider is already focused and doesn't need migration
- UiStateProvider is already focused and doesn't need migration
- Only the state that was in AppProvider needs migration (theme, favorites, scores, news, live events)
