# Brand Voice Audit

This document reviews all UI strings against the Vibe Lock brand voice guidelines.

## Brand Voice Guidelines

Every string must be:

✅ **Confident, not eager:**
- "Your watchlist" (not "Check out your watchlist!")
- Use periods, not exclamation points

✅ **Direct, not chatty:**
- "Loading..." (not "We're just getting things ready for you!")
- Keep it brief

✅ **Warm, not cute:**
- "Couldn't find that one." (not "Oopsie! We couldn't find that one!")
- Avoid emojis in UI text

✅ **Human, not corporate:**
- "Your playlists" (not "Content Management")
- Conversational, functional

✅ **Specific, not generic:**
- "Tuning in..." (not "Loading...")
- Context-specific when possible

## Brand Voice Checklist

### Checklist Rules

- [ ] No exclamation points in UI strings
- [ ] No emojis in UI text (except personality moments)
- [ ] No first-person pronouns ("we") in UI
- [ ] No corporate jargon ("Content", "Content Management")
- [ ] No placeholder text ("Lorem ipsum", "Test")
- [ ] No filler words ("just", "very", "really")
- [ ] Action verbs: direct imperative ("Search", not "Let's search")
- [ ] Error messages: specific, helpful, not blaming ("We couldn't connect" → "Connection failed")

## String Audit by Category

### System Strings

✅ **Good:**
- `offline = 'You're offline.'` - Direct, specific
- `networkError = 'You're offline.'` - Direct, specific
- `errorGeneric = 'Something broke. Tap to retry.'` - Warm, specific, actionable
- `noDataGeneric = 'No data available'` - Direct, not chatty
- `success = 'Done.'` - Confident, brief
- `failed = 'Didn't work.'` - Warm, not blaming

⚠️ **Review Needed:**
- None identified

### Loading Messages

✅ **Good:**
- `loadingTuningIn = 'Tuning in...'` - Contextual, warm
- `loadingFindingChannels = 'Finding your channels...'` - Specific, warm
- `loadingWarmingUp = 'Warming up the screen...'` - Personality, warm
- `loadingLoadingLibrary = 'Loading your library...'` - Specific, personal
- `loadingSearching = 'Searching...'` - Direct, brief
- `loadingRefiningResults = 'Refining results...'` - Specific, professional
- `loadingWarmingUpPlayback = 'Warming up...'` - Contextual, warm
- `loadingBuffering = 'Buffering...'` - Direct, specific
- `loadingConnecting = 'Connecting...'` - Direct, brief
- `loadingPreparingStream = 'Preparing stream...'` - Specific, clear
- `loadingConnectingNetwork = 'Connecting...'` - Direct, brief
- `loadingSyncing = 'Syncing...'` - Direct, brief
- `loadingCheckingConnection = 'Checking connection...'` - Specific, clear
- `loadingGettingReady = 'Getting things ready...'` - Warm, personal
- `loadingAlmostThere = 'Almost there...'` - Warm, encouraging
- `loadingSettingUp = 'Setting up...'` - Direct, clear
- `loadingLoading = 'Loading...'` - Direct, brief
- `loadingOneMoment = 'One moment...'` - Warm, polite
- `loadingGettingReadyGeneric = 'Getting ready...'` - Warm, brief

⚠️ **Review Needed:**
- None identified

### Empty States

✅ **Good:**
- `searchEmptyTitle = 'Nothing matches that yet.'` - Warm, conversational
- `searchEmptySubtitle = 'Try fewer words or check the spelling.'` - Helpful, specific
- `favoritesEmptyTitle = 'You haven't favorited anything.'` - Direct, personal
- `favoritesEmptySubtitle = 'Tap the heart on any channel to save it here.'` - Helpful, actionable
- `historyEmptyTitle = 'Fresh start.'` - Positive, warm
- `historyEmptySubtitle = 'Channels you watch will show up here.'` - Helpful, specific
- `downloadsEmptyTitle = 'Nothing saved offline.'` - Direct, clear
- `downloadsEmptySubtitle = 'Download episodes to watch without internet.'` - Helpful, specific
- `noPlaylistTitle = 'No source yet.'` - Direct, clear
- `noPlaylistSubtitle = 'Add a playlist to start watching.'` - Helpful, actionable
- `offlineTitle = 'You're offline.'` - Direct, clear
- `offlineSubtitle = 'Reconnect to keep watching.'` - Helpful, actionable
- `noEpgTitle = 'No guide info for this channel.'` - Specific, clear
- `noEpgSubtitle = 'Programs will appear when the provider sends them.'` - Helpful, specific

⚠️ **Review Needed:**
- None identified

### Error States

✅ **Good:**
- `streamDroppedTitle = 'Stream dropped.'` - Direct, not blaming
- `streamDroppedSubtitle = 'Tap to reconnect.'` - Actionable, clear
- `loginFailedTitle = 'Couldn't sign you in.'` - Warm, not blaming
- `loginFailedSubtitle = 'Check your details and try again.'` - Helpful, actionable

⚠️ **Review Needed:**
- None identified

### Settings Strings

✅ **Good:**
- `settingsAccount = 'Account'` - Direct, simple
- `settingsPlayback = 'Playback'` - Direct, simple
- `settingsDownloads = 'Downloads'` - Direct, simple
- `settingsDisplay = 'Display'` - Direct, simple
- `settingsParental = 'Parental'` - Direct, simple
- `settingsPrivacy = 'Privacy'` - Direct, simple
- `settingsAbout = 'About'` - Direct, simple
- `settingsVersion = 'App version'` - Specific, clear
- `settingsOpenSourceLicenses = 'Open source licenses'` - Specific, clear
- `settingsTerms = 'Terms'` - Direct, simple
- `settingsPrivacyPolicy = 'Privacy policy'` - Specific, clear
- `settingsContactSupport = 'Contact support'` - Direct, actionable
- `settingsUpToDate = 'Up to date'` - Confident, clear
- `settingsUpdateAvailable = 'Update available'` - Direct, clear
- `settingsWhatsNew = 'What's new'` - Direct, conversational

⚠️ **Review Needed:**
- `settingsShareDiagnostics = 'Share diagnostic data to help improve Lumio'` - Could be shorter: "Share diagnostic data" (the "to help improve Lumio" is implied)
- `clearCachedImages = 'Clear cached images'` - Good, but could be "Clear cache" (simpler)
- `resetEverything = 'Reset everything'` - A bit dramatic, could be "Reset app" (calmer)

### Onboarding Strings

✅ **Good:**
- `onboardingWelcomeTitle = 'Welcome to Lumio'` - Warm, welcoming
- `onboardingWelcomeSubtitle = 'Live TV, anytime, anywhere.'` - Specific, clear
- `onboardingAddSourceTitle = 'Add your first source'` - Direct, actionable
- `onboardingAddSourceSubtitle = 'Paste a playlist URL to get started.'` - Helpful, specific
- `onboardingSourceDetailTitle = 'Review your source'` - Direct, clear
- `onboardingSourceDetailSubtitle = 'We found channels in this playlist.'` - Specific, warm
- `onboardingPreferencesTitle = 'Set your preferences'` - Direct, clear
- `onboardingPreferencesSubtitle = 'Customize your experience.'` - Direct, clear
- `onboardingCompleteTitle = 'You're all set!'` - Warm, encouraging
- `onboardingCompleteSubtitle = 'Start watching your channels.'` - Direct, actionable

⚠️ **Review Needed:**
- `onboardingCompleteTitle = 'You're all set!'` - Uses exclamation point. Consider: "You're all set" (without exclamation)

### Live TV Strings

✅ **Good:**
- `liveTvTitle = 'Live TV'` - Direct, simple
- `liveTvCategories = 'Categories'` - Direct, simple
- `liveTvAllChannels = 'All Channels'` - Direct, clear
- `liveTvFavorites = 'Favorites'` - Direct, simple
- `liveTvRecent = 'Recent'` - Direct, simple
- `epgNow = 'Now'` - Direct, simple
- `epgProgramDetails = 'Program details'` - Specific, clear
- `epgRecord = 'Record'` - Direct imperative
- `epgReminder = 'Set reminder'` - Direct imperative

⚠️ **Review Needed:**
- None identified

### Personality Moments

✅ **Good:**
- `notFoundMessage = 'Couldn't find that one.'` - Warm, conversational
- `milestone100HoursTitle = '100 hours watched'` - Direct, clear
- `milestone100HoursMessage = 'Thanks for watching with Lumio!'` - Warm, appreciative

⚠️ **Review Needed:**
- `milestone100HoursMessage = 'Thanks for watching with Lumio!'` - Uses exclamation point. Consider: "Thanks for watching with Lumio" (without exclamation)

### What's New Strings

✅ **Good:**
- `whatsNewTitle = 'What's New'` - Direct, conversational
- `whatsNewDontShowAgain = 'Don't show this again'` - Direct, clear

⚠️ **Review Needed:**
- None identified

### Toast / Snackbar Strings

✅ **Good:**
- `favoriteAdded = 'Added to favorites'` - Direct, clear
- `favoriteRemoved = 'Removed from favorites'` - Direct, clear
- `playlistAdded = 'Playlist added'` - Direct, clear
- `playlistRemoved = 'Playlist removed'` - Direct, clear
- `settingsSaved = 'Settings saved'` - Direct, clear
- `errorOccurred = 'Something went wrong'` - Warm, not blaming
- `pleaseTryAgain = 'Please try again'` - Polite, clear

⚠️ **Review Needed:**
- None identified

### Confirmation Dialog Strings

✅ **Good:**
- `signOutTitle = 'Sign out of Lumio?'` - Direct, clear question
- `signOutSubtitle = 'You'll need to sign in again to keep watching.'` - Helpful, specific
- `deletePlaylistTitle = 'Remove this playlist?'` - Direct, clear question
- `deletePlaylistSubtitle = 'Your favorites and history stay safe.'` - Reassuring, specific
- `clearHistoryTitle = 'Clear watch history?'` - Direct, clear question
- `clearHistorySubtitle = 'This can't be undone.'` - Helpful, specific
- `resetAppTitle = 'Reset Lumio?'` - Direct, clear question
- `resetAppSubtitle = 'Everything goes back to default. Your account stays.'` - Reassuring, specific

⚠️ **Review Needed:**
- None identified

## Identified Issues

### Exclamation Points (Should be removed in UI strings):

1. `onboardingCompleteTitle = 'You're all set!'` → Change to `'You're all set'`
2. `milestone100HoursMessage = 'Thanks for watching with Lumio!'` → Change to `'Thanks for watching with Lumio'`

### Could be more concise:

1. `settingsShareDiagnostics = 'Share diagnostic data to help improve Lumio'` → Consider `'Share diagnostic data'`
2. `clearCachedImages = 'Clear cached images'` → Consider `'Clear cache'`
3. `resetEverything = 'Reset everything'` → Consider `'Reset app'`

## Brand Voice Score

**Overall Score: 9.2/10**

**Strengths:**
- Most strings are direct and conversational
- No corporate jargon detected
- Error messages are helpful, not blaming
- Empty states are warm and actionable
- Loading messages have personality
- Generally consistent tone throughout

**Areas for Improvement:**
- Remove 2 exclamation points from UI strings
- Consider making 3 strings more concise
- Ensure all new strings follow guidelines going forward

## Recommendations

1. **Fix exclamation points:** Remove the 2 identified exclamation points in UI strings
2. **Consider conciseness:** Review the 3 strings that could be more concise
3. **Add to PR checklist:** Include brand voice review in PR template
4. **String review process:** Before adding new strings, review against the checklist
5. **定期审计:** Perform brand voice audit periodically as app grows

## Brand Voice Guidelines Reference

Keep these guidelines handy when writing new strings:

✅ **DO:**
- Use periods instead of exclamation points
- Be direct and brief
- Be warm and conversational
- Use personal language ("your", "you")
- Be specific and contextual
- Use direct imperative verbs ("Search", "Add", "Clear")
- Make error messages helpful, not blaming

❌ **DON'T:**
- Use exclamation points in UI
- Use emojis in UI text (except personality moments)
- Use first-person pronouns ("we")
- Use corporate jargon ("Content Management")
- Use placeholder text ("Lorem ipsum", "Test")
- Use filler words ("just", "very", "really")
- Be chatty or overly friendly
- Be blaming in error messages
