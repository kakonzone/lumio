# Edge Case State Audit

This document provides a checklist for ensuring all screens have proper edge case states according to the Vibe Lock guidelines.

## Required Edge Case States

Every screen must have designed states for:

1. **Loading State:**
   - Skeleton loader with shimmer OR contextual loading message
   - Animation respects reduce motion
   - Never shows spinner without context

2. **Empty State:**
   - Using EmptyState widget with illustration
   - Specific message for context
   - Action button when applicable
   - Background: pure black

3. **Error State:**
   - Error message (specific, not generic)
   - Clear description
   - Retry button with accent color
   - Haptic feedback on tap
   - Optional help link

4. **Offline State:**
   - "No internet connection"
   - Reconnect button
   - Subtle illustration
   - Cache if applicable
   - Check connection periodically

5. **Success/Populated State:**
   - Content displayed clearly
   - No awkward gaps
   - Proper pagination
   - Loading indicator for more content
   - Empty state if applicable

6. **Long Content:**
   - Text truncation with ellipsis
   - Title maxLines: 2
   - Body maxLines: 3
   - View more expansion for long text
   - Horizontal scroll for long lists

7. **Short Content:**
   - No extra whitespace
   - Cards collapse appropriately
   - Lists show "No items" if empty
   - No awkward empty spaces

## Screen Audit Checklist

### Main Navigation Screens

#### Home Screen (tv_screen.dart)
- [ ] Loading: Skeleton loader or contextual message
- [ ] Empty: EmptyState with specific home message
- [ ] Error: Connection failed + retry
- [ ] Offline: Network + reconnect
- [ ] Long content: Category titles truncation
- [ ] Short content: No empty category cards

#### Search Screen (search_screen.dart)
- [ ] Loading: Skeleton or "Searching..."
- [ ] Empty: EmptyState with search-specific message
- [ ] Error: Search failed + retry
- [ ] Offline: Offline + retry search
- [ ] Long content: Result titles maxLines: 2
- [ ] Short content: "No results" message

#### Favorites Screen (favorites_screen.dart)
- [ ] Loading: Skeleton or "Loading your library..."
- [ ] Empty: EmptyState with favorites-specific message
- [ ] Error: Loading failed + retry
- [ ] Offline: Offline + retry load
- [ ] Long content: Channel titles truncation
- [ ] Short content: "You haven't favorited anything" message

#### Settings Screen (settings_screen.dart)
- [ ] Loading: None (static content)
- [ ] Empty: N/A (static content)
- [ ] Error: Settings save failed + retry
- [ ] Offline: "Settings saved locally" message
- [ ] Long content: Section descriptions maxLines: 2
- [ ] Short content: N/A

#### Live TV Screen (live_tv_screen.dart)
- [ ] Loading: Skeleton or "Tuning in..."
- [ ] Empty: EmptyState with "No channels available"
- [ ] Error: Channel load failed + retry
- [ ] Offline: Offline + reconnect
- [ ] Long content: EPG program titles truncation
- [ ] Short content: "No channels in this category"

#### News Screen (news_screen.dart)
- [ ] Loading: Skeleton or "Loading news..."
- [ ] Empty: EmptyState with "No news available"
- [ ] Error: News fetch failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Article titles maxLines: 2
- [ ] Short content: "No news articles" message

#### Player Screen (player_screen.dart)
- [ ] Loading: "Buffering..." or "Connecting..."
- [ ] Empty: "Stream ended" message
- [ ] Error: Stream dropped + retry button
- [ ] Offline: "Offline" + reconnect
- [ ] Long content: Channel name truncation
- [ ] Short content: "No stream available"

### Onboarding Screens

#### Welcome Screen (onboarding/welcome_screen.dart)
- [ ] Loading: None (static content)
- [ ] Empty: N/A (static content)
- [ ] Error: N/A (no network calls)
- [ ] Offline: N/A (no network calls)
- [ ] Long content: Title truncation
- [ ] Short content: N/A

#### Source Screen (onboarding/source_screen.dart)
- [ ] Loading: Skeleton or "Finding sources..."
- [ ] Empty: EmptyState with "No sources found"
- [ ] Error: Source fetch failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Source names truncation
- [ ] Short content: "No sources available"

#### Source Detail Screen (onboarding/source_detail_screen.dart)
- [ ] Loading: Skeleton or "Loading source..."
- [ ] Empty: EmptyState with "No channels in source"
- [ ] Error: Channel load failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Channel names truncation
- [ ] Short content: "Add this source first"

#### Preferences Screen (onboarding/preferences_screen.dart)
- [ ] Loading: None (static content)
- [ ] Empty: N/A (static content)
- [ ] Error: Save failed + retry
- [ ] Offline: "Saved locally" message
- [ ] Long content: Option descriptions truncation
- [ ] Short content: N/A

### Content Detail Screens

#### Category Channels Screen (category_channels_screen.dart)
- [ ] Loading: Skeleton or "Loading channels..."
- [ ] Empty: EmptyState with "No channels in category"
- [ ] Error: Channels failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Channel titles maxLines: 2
- [ ] Short content: "No channels available"

#### News Article Reader Screen (news_article_reader_screen.dart)
- [ ] Loading: "Loading article..."
- [ ] Empty: "Article not found"
- [ ] Error: Load failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Body text expansion
- [ ] Short content: "Article unavailable"

### Utility Screens

#### Splash Screen (splash_screen.dart)
- [ ] Loading: "Getting things ready..."
- [ ] Empty: N/A (transitional screen)
- [ ] Error: App load failed + retry
- [ ] Offline: "Check your connection"
- [ ] Long content: Logo/title truncation
- [ ] Short content: N/A

#### App Open Promo Screen (app_open_promo_screen.dart)
- [ ] Loading: None (static content)
- [ ] Empty: N/A (static content)
- [ ] Error: N/A (no network calls)
- [ ] Offline: N/A (no network calls)
- [ ] Long content: Promo text truncation
- [ ] Short content: N/A

#### Ads Privacy Screen (ads_privacy_screen.dart)
- [ ] Loading: None (static content)
- [ ] Empty: N/A (static content)
- [ ] Error: Settings save failed + retry
- [ ] Offline: "Saved locally" message
- [ ] Long content: Policy text expansion
- [ ] Short content: N/A

#### Blocked Apps Screen (blocked_apps_screen.dart)
- [ ] Loading: Skeleton or "Loading..."
- [ ] Empty: EmptyState with "No blocked apps"
- [ ] Error: Load failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: App names truncation
- [ ] Short content: "No apps blocked"

#### Dev Diagnostics Screen (dev_diagnostics_screen.dart)
- [ ] Loading: "Gathering diagnostics..."
- [ ] Empty: EmptyState with "No diagnostics data"
- [ ] Error: Diagnostic failed + retry
- [ ] Offline: Offline + retry
- [ ] Long content: Log truncation + scroll
- [ ] Short content: "No data available"

## State Implementation Patterns

### Loading State Pattern

```dart
// Skeleton Loader
if (_isLoading) {
  return SkeletonLoader(
    child: YourContentPlaceholder(),
  );
}

// OR Contextual Loading Message
if (_isLoading) {
  return Center(
    child: CyclingLoadingMessage(
      context: LoadingContext.data,
      style: tokens.TypographyTokens.bodyMedium,
    ),
  );
}
```

### Empty State Pattern

```dart
if (_isEmpty) {
  return EmptyState(
    icon: PhosphorIcons.magnifyingGlass(),
    title: AppStrings.searchEmptyTitle,
    subtitle: AppStrings.searchEmptySubtitle,
    action: ActionButton(
      label: "Clear search",
      onPressed: _clearSearch,
    ),
  );
}
```

### Error State Pattern

```dart
if (_hasError) {
  return ErrorState(
    icon: PhosphorIcons.warning(),
    title: "Stream dropped",
    subtitle: "The connection was interrupted",
    action: ActionButton(
      label: "Retry",
      onPressed: _retry,
      accent: true,
    ),
  );
}
```

### Offline State Pattern

```dart
if (!_isOnline) {
  return OfflineState(
    icon: PhosphorIcons.wifiSlash(),
    title: AppStrings.offlineTitle,
    subtitle: AppStrings.offlineSubtitle,
    action: ActionButton(
      label: "Reconnect",
      onPressed: _checkConnection,
      accent: true,
    ),
  );
}
```

### Long Content Pattern

```dart
Text(
  title,
  style: tokens.TypographyTokens.titleLarge,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
)

// OR expandable
Text(
  body,
  style: tokens.TypographyTokens.bodyMedium,
  maxLines: _isExpanded ? null : 3,
  overflow: TextOverflow.ellipsis,
)

GestureDetector(
  onTap: () => setState(() => _isExpanded = !_isExpanded),
  child: Text(
    _isExpanded ? "Show less" : "Show more",
    style: tokens.TypographyTokens.labelSmall,
  ),
)
```

## Status Summary

### Screens Requiring Edge Case Implementation

**High Priority (Core Navigation):**
- tv_screen.dart - Partially implemented
- search_screen.dart - Partially implemented
- favorites_screen.dart - Partially implemented
- settings_screen.dart - Static (no edge cases needed)
- live_tv_screen.dart - Partially implemented
- news_screen.dart - Partially implemented
- player_screen.dart - Partially implemented

**Medium Priority (Onboarding):**
- welcome_screen.dart - Static (no edge cases needed)
- source_screen.dart - Needs implementation
- source_detail_screen.dart - Needs implementation
- preferences_screen.dart - Static (no edge cases needed)

**Low Priority (Utility):**
- splash_screen.dart - Transitional (minimal edge cases)
- ads_privacy_screen.dart - Static (no edge cases needed)
- blocked_apps_screen.dart - Needs implementation
- dev_diagnostics_screen.dart - Needs implementation

## Next Steps

1. Implement edge cases for high priority screens first
2. Add skeleton loaders for all data loading screens
3. Ensure EmptyState widget is used consistently
4. Add ErrorState widget if not exists
5. Add OfflineState widget if not exists
6. Implement text truncation rules across all screens
7. Test each screen in each state manually
8. Ensure animations respect reduce motion setting

## Implementation Notes

- All loading states should use LoadingMessages utility for contextual messages
- All empty states should use EmptyState widget
- All error states should include retry functionality
- All offline states should include reconnect functionality
- Text truncation should follow vibe lock rules (titles: 2, body: 3)
- Long content should be expandable when meaningful
- Short content should show specific "No X" messages
- Background color should always be pure black for states
