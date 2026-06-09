// lib/l10n/strings.dart
/// Centralized user-facing strings for Lumio app.
/// 
/// All user-facing text should reference these constants.
/// No hardcoded strings in UI code except for dynamic content.
class Strings {
  Strings._();

  // ==================== SYSTEM STRINGS ====================
  
  /// Network states
  static const String offline = 'You\'re offline.';
  static const String networkError = 'You\'re offline.';
  
  /// Error states
  static const String errorGeneric = 'Something broke. Tap to retry.';
  static const String noDataGeneric = 'No data available';
  
  /// Generic responses
  static const String success = 'Done.';
  static const String failed = 'Didn\'t work.';

  // ==================== BUTTON STRINGS ====================
  
  /// Generic confirmation
  static const String gotIt = 'Got it';
  static const String done = 'Done';
  static const String continueText = 'Continue';
  
  /// Cancellation
  static const String notNow = 'Not now';
  static const String back = 'Back';
  
  /// Actions (context-specific)
  static const String saveChanges = 'Save changes';
  static const String signIn = 'Sign in';
  static const String signUp = 'Create account';
  static const String signOut = 'Sign out';
  static const String addSource = 'Add source';
  static const String remove = 'Remove';
  static const String forget = 'Forget';
  static const String clear = 'Clear';
  static const String delete = 'Delete';
  static const String tryAgain = 'Try again';
  
  /// Destructive actions
  static const String removePlaylist = 'Remove this playlist?';
  static const String clearHistory = 'Clear watch history?';
  static const String resetApp = 'Reset Lumio?';

  // ==================== PLAYER STRINGS ====================
  
  /// Quality selection
  static const String quality = 'Quality';
  static const String qualityAutoRecommended = 'Auto (recommended)';
  
  /// Audio
  static const String audio = 'Audio';
  static const String audioTrack = 'Audio track';
  
  /// Subtitles
  static const String subtitles = 'Subtitles';
  static const String subtitlesNone = 'None';
  
  /// Controls
  static const String cast = 'Send to TV';
  static const String pictureInPicture = 'Pop out';
  static const String liveIndicator = 'LIVE';

  // ==================== SETTINGS STRINGS ====================
  
  /// Section headers
  static const String settingsAccount = 'Account';
  static const String settingsPlayback = 'Playback';
  static const String settingsDownloads = 'Downloads';
  static const String settingsDisplay = 'Display';
  static const String settingsParental = 'Parental';
  static const String settingsPrivacy = 'Privacy & Data';
  static const String settingsAbout = 'About';
  
  /// Account section
  static const String settingsProfile = 'Profile';
  static const String settingsSubscription = 'Subscription';
  static const String settingsDevices = 'Devices';
  static const String settingsManage = 'Manage';
  
  /// Playback section
  static const String settingsDefaultQuality = 'Default quality';
  static const String settingsAudioLanguage = 'Audio language';
  static const String settingsSubtitleLanguage = 'Subtitle language';
  static const String settingsSubtitleAppearance = 'Subtitle appearance';
  static const String settingsAutoplayNext = 'Autoplay next';
  static const String settingsReduceMotion = 'Reduce motion';
  static const String settingsAuto = 'Auto';
  
  /// Downloads section
  static const String settingsDownloadQuality = 'Download quality';
  static const String settingsDownloadWifi = 'Download over Wi-Fi only';
  static const String settingsStorageUsed = 'Storage used';
  static const String settingsClearStorage = 'Clear storage';
  
  /// Display section
  static const String settingsTheme = 'Theme';
  static const String settingsThemeDark = 'Dark';
  static const String settingsThemeOled = 'OLED';
  static const String settingsThemeSystem = 'System';
  static const String settingsAppIcon = 'App icon';
  static const String settingsPlayerBackground = 'Player background tint';
  
  /// Parental section
  static const String settingsProfileLock = 'Profile lock';
  static const String settingsContentRating = 'Content rating cap';
  static const String settingsHideAdult = 'Hide adult categories';
  
  /// Privacy & Data section
  static const String settingsPersonalizedRecs = 'Personalized recommendations';
  static const String settingsClearWatchHistory = 'Clear watch history';
  static const String settingsClearSearchHistory = 'Clear search history';
  static const String settingsDiagnosticData = 'Diagnostic data';
  static const String settingsShareDiagnostics = 'Share diagnostic data to help improve Lumio';
  
  /// About section
  static const String settingsVersion = 'App version';
  static const String settingsOpenSourceLicenses = 'Open source licenses';
  static const String settingsTerms = 'Terms';
  static const String settingsPrivacyPolicy = 'Privacy policy';
  static const String settingsContactSupport = 'Contact support';
  static const String settingsUpToDate = 'Up to date';
  static const String settingsUpdateAvailable = 'Update available';
  static const String settingsWhatsNew = 'What\'s new';
  
  /// What's New feature
  static const String whatsNewTitle = 'What\'s New';
  static const String whatsNewDontShowAgain = 'Don\'t show this again';
  
  /// Legacy strings (for backward compatibility)
  /// Cache and storage
  static const String clearCachedImages = 'Clear cached images';
  static const String resetEverything = 'Reset everything';
  
  /// Notifications
  static const String whatWeNotifyYouAbout = 'What we notify you about';
  
  /// Permissions
  static const String whatLumioCanAccess = 'What Lumio can access';
  
  /// About
  static const String aboutLumio = 'About Lumio';

  // ==================== ONBOARDING STRINGS ====================
  
  /// Welcome screen
  static const String onboardingWelcomeTitle = 'Welcome to Lumio';
  static const String onboardingWelcomeBody = 'Your IPTV, finally with taste.';
  static const String onboardingContinue = 'Continue';
  static const String onboardingSkip = 'Skip';
  static const String onboardingFinish = 'Finish setup';
  
  /// Add source screen
  static const String onboardingAddSourceTitle = 'Add your first playlist';
  static const String onboardingAddSourceLater = 'I\'ll do this later';
  static const String onboardingSourceM3U = 'M3U URL';
  static const String onboardingSourceM3UDesc = 'Paste a playlist link from your provider';
  static const String onboardingSourceXtream = 'Xtream Codes';
  static const String onboardingSourceXtreamDesc = 'Enter server details from your IPTV provider';
  static const String onboardingSourceUpload = 'Upload file';
  static const String onboardingSourceUploadDesc = 'Import an M3U file from your device';
  
  /// Source detail screen
  static const String onboardingSourceM3UTitle = 'Add M3U Playlist';
  static const String onboardingSourceXtreamTitle = 'Add Xtream Codes Server';
  static const String onboardingSourceUrlPlaceholder = 'https://example.com/playlist.m3u';
  static const String onboardingSourceUrlLabel = 'Playlist URL';
  static const String onboardingSourceUsernameLabel = 'Username';
  static const String onboardingSourcePasswordLabel = 'Password';
  static const String onboardingSourceServerUrlLabel = 'Server URL';
  static const String onboardingSourceSubmit = 'Add playlist';
  static const String onboardingSourceValidating = 'Validating...';
  static const String onboardingSourceSuccess = 'Playlist added!';
  static const String onboardingSourceError = 'Something went wrong';
  static const String onboardingSourceRetry = 'Try again';
  
  /// Preferences screen
  static const String onboardingPreferencesTitle = 'Quick preferences';
  static const String onboardingLanguageLabel = 'Preferred language';
  static const String onboardingInterestsLabel = 'Content interests';
  static const String onboardingAdultContentLabel = 'Adult content';
  static const String onboardingAdultContentDesc = 'Show adult content in results';
  
  /// Content interest chips
  static const String interestSports = 'Sports';
  static const String interestMovies = 'Movies';
  static const String interestNews = 'News';
  static const String interestKids = 'Kids';
  static const String interestMusic = 'Music';
  static const String interestDocumentaries = 'Documentaries';
  static const String interestEntertainment = 'Entertainment';
  
  /// Language chips
  static const String languageEnglish = 'English';
  static const String languageSpanish = 'Spanish';
  static const String languageFrench = 'French';
  static const String languageGerman = 'German';
  static const String languagePortuguese = 'Portuguese';
  static const String languageArabic = 'Arabic';
  static const String languageHindi = 'Hindi';
  static const String languageBengali = 'Bangla';
  
  /// Legacy strings (for backward compatibility)
  /// Getting started
  static const String letsSetUpThis = 'Let\'s set this up';
  
  /// Authentication
  static const String createAccount = 'Create account';
  static const String login = 'Sign in';
  
  /// Skipping
  static const String notNowOnboarding = 'Not now';
  
  /// Navigation
  static const String nextOnboarding = 'Continue';

  // ==================== EPG / LIVE TV STRINGS ====================
  
  /// EPG tabs
  static const String epgTabCategories = 'Categories';
  static const String epgTabChannels = 'Channels';
  static const String epgTabGuide = 'Guide';
  
  /// Filter chips
  static const String epgFilterAll = 'All';
  static const String epgFilterLive = 'Live';
  static const String epgFilterFavorites = 'Favorites';
  static const String epgFilterRecentlyWatched = 'Recently watched';
  
  /// Category labels
  static const String categoryAll = 'All Channels';
  static const String categorySports = 'Sports';
  static const String categoryMovies = 'Movies';
  static const String categoryNews = 'News';
  static const String categoryEntertainment = 'Entertainment';
  static const String categoryKids = 'Kids';
  static const String categoryMusic = 'Music';
  static const String categoryDocumentaries = 'Documentaries';
  static const String categoryReligious = 'Religious';
  
  /// Channel list
  static const String channelSearchPlaceholder = 'Search channels...';
  static const String channelCurrentProgram = 'Current program';
  static const String channelNoProgram = 'No program info';
  
  /// EPG timeline
  static const String epgNow = 'Now';
  static const String epgProgramDetails = 'Program details';
  static const String epgRecord = 'Record';
  static const String epgReminder = 'Set reminder';
  
  // ==================== LOADING MESSAGE STRINGS ====================
  
  /// Data loading messages
  static const String loadingTuningIn = 'Tuning in...';
  static const String loadingFindingChannels = 'Finding your channels...';
  static const String loadingWarmingUp = 'Warming up the screen...';
  static const String loadingLoadingLibrary = 'Loading your library...';
  
  /// Search loading messages
  static const String loadingSearching = 'Searching...';
  static const String loadingRefiningResults = 'Refining results...';
  static const String loadingLookingUp = 'Looking it up...';
  
  /// Playback loading messages
  static const String loadingWarmingUpPlayback = 'Warming up...';
  static const String loadingBuffering = 'Buffering...';
  static const String loadingConnecting = 'Connecting...';
  static const String loadingPreparingStream = 'Preparing stream...';
  
  /// Network loading messages
  static const String loadingConnectingNetwork = 'Connecting...';
  static const String loadingSyncing = 'Syncing...';
  static const String loadingCheckingConnection = 'Checking connection...';
  
  /// Onboarding loading messages
  static const String loadingGettingReady = 'Getting things ready...';
  static const String loadingAlmostThere = 'Almost there...';
  static const String loadingSettingUp = 'Setting up...';
  
  /// Generic loading messages
  static const String loadingLoading = 'Loading...';
  static const String loadingOneMoment = 'One moment...';
  static const String loadingGettingReadyGeneric = 'Getting ready...';
  
  /// Personality moments
  static const String notFoundMessage = 'Couldn\'t find that one.';
  static const String milestone100HoursTitle = '100 hours watched';
  static const String milestone100HoursMessage = 'Thanks for watching with Lumio';
  
  // ==================== EMPTY STATE STRINGS ====================
  
  /// Search empty
  static const String searchEmptyTitle = 'Nothing matches that yet.';
  static const String searchEmptySubtitle = 'Try fewer words or check the spelling.';
  
  /// Favorites empty
  static const String favoritesEmptyTitle = 'You haven\'t favorited anything.';
  static const String favoritesEmptySubtitle = 'Tap the heart on any channel to save it here.';
  
  /// History empty
  static const String historyEmptyTitle = 'Fresh start.';
  static const String historyEmptySubtitle = 'Channels you watch will show up here.';
  
  /// Downloads empty
  static const String downloadsEmptyTitle = 'Nothing saved offline.';
  static const String downloadsEmptySubtitle = 'Download episodes to watch without internet.';
  
  /// No playlist
  static const String noPlaylistTitle = 'No source yet.';
  static const String noPlaylistSubtitle = 'Add a playlist to start watching.';
  
  /// Offline
  static const String offlineTitle = 'You\'re offline.';
  static const String offlineSubtitle = 'Reconnect to keep watching.';
  
  /// No EPG data
  static const String noEpgTitle = 'No guide info for this channel.';
  static const String noEpgSubtitle = 'Programs will appear when the provider sends them.';

  // ==================== ERROR STATE STRINGS ====================
  
  /// Stream failures
  static const String streamDroppedTitle = 'Stream dropped.';
  static const String streamDroppedSubtitle = 'Tap to reconnect.';
  
  /// Login failures
  static const String loginFailedTitle = 'Couldn\'t sign you in.';
  static const String loginFailedSubtitle = 'Check your details and try again.';
  
  /// Playlist parse failures
  static const String playlistParseFailedTitle = 'We couldn\'t read that playlist.';
  static const String playlistParseFailedSubtitle = 'Make sure the link points to a valid M3U file.';
  
  /// Update failures
  static const String updateFailedTitle = 'Update didn\'t finish.';
  static const String updateFailedSubtitle = 'We\'ll try again later.';
  
  /// Permission denied
  static const String permissionDeniedTitle = 'Lumio needs [permission] for this.';
  static const String permissionDeniedSubtitle = 'Open settings to allow it.';

  // ==================== CONFIRMATION DIALOG STRINGS ====================
  
  /// Sign out
  static const String signOutTitle = 'Sign out of Lumio?';
  static const String signOutSubtitle = 'You\'ll need to sign in again to keep watching.';
  
  /// Delete playlist
  static const String deletePlaylistTitle = 'Remove this playlist?';
  static const String deletePlaylistSubtitle = 'Your favorites and history stay safe.';
  
  /// Clear history
  static const String clearHistoryTitle = 'Clear watch history?';
  static const String clearHistorySubtitle = 'This can\'t be undone.';
  
  /// Reset app
  static const String resetAppTitle = 'Reset Lumio?';
  static const String resetAppSubtitle = 'Everything goes back to default. Your account stays.';

  // ==================== TOAST / SNACKBAR STRINGS ====================
  
  /// Favorites
  static const String addedToFavorites = 'Saved to favorites';
  static const String removedFromFavorites = 'Removed';
  
  /// Copy actions
  static const String linkCopied = 'Copied';
  
  /// Downloads
  static const String downloadStarted = 'Downloading';
  static const String downloadComplete = 'Ready to watch offline';
  
  /// Settings
  static const String settingsSaved = 'Saved';

  // ==================== LOADING SKELETON SUBTITLES ====================
  
  /// Home screen
  static const String homeLoading = ''; // No subtitle, just skeleton
  
  /// Player buffering
  static const String playerBuffering = 'Catching up...';
  
  /// Search
  static const String searchLoading = 'Looking...';
  static const String searchPlaceholder = 'Search channels, movies, series...';
  static const String searchCancel = 'Cancel';
  static const String searchClear = 'Clear';
  static const String searchVoice = 'Voice search';
  static const String searchRecent = 'Recent searches';
  static const String searchTrending = 'Trending';
  static const String searchBrowseByCategory = 'Browse by category';
  static const String searchNoResultsTitle = 'Nothing matches that yet.';
  static const String searchNoResultsSubtitle = 'Try fewer words or different spelling.';
  static const String searchNothingMatches = 'Nothing matches';
  
  /// Search tabs
  static const String searchTabAll = 'All';
  static const String searchTabChannels = 'Channels';
  static const String searchTabMovies = 'Movies';
  static const String searchTabSeries = 'Series';
  static const String searchTabEpg = 'Guide';
  
  /// EPG loading
  static const String epgLoading = 'Fetching guide...';
  
  /// Playlist import
  static const String playlistImportLoading = 'Reading your playlist...';

  // ==================== PERMISSION RATIONALE STRINGS ====================
  
  /// Storage permission
  static const String storagePermissionTitle = 'Lumio needs storage access';
  static const String storagePermissionSubtitle = 'to save downloads for offline watching.';
  
  /// Notifications permission
  static const String notificationsPermissionTitle = 'We\'ll only notify you';
  static const String notificationsPermissionSubtitle = 'about reminders you set and stream updates.';
  
  /// Camera permission (for QR import)
  static const String cameraPermissionTitle = 'Scan a QR code';
  static const String cameraPermissionSubtitle = 'to import your playlist instantly.';

  // ==================== FORM VALIDATION MESSAGES ====================
  
  /// Empty required fields
  static const String fieldRequired = 'We need this to continue';
  
  /// Invalid URL
  static const String invalidUrl = 'That doesn\'t look like a valid link';
  
  /// Invalid email
  static const String invalidEmail = 'Check the email format';
  
  /// Password too short
  static const String passwordTooShort = 'At least 8 characters';
  
  /// Passwords don't match
  static const String passwordsDontMatch = 'These don\'t match';
  
  /// Username taken
  static const String usernameTaken = 'Someone already has this name';

  // ==================== CATEGORY/SPECIFIC STRINGS ====================
  
  /// Sports
  static const String noChannelsInSport = 'No live channels in {sport} right now';
  
  /// Categories
  static const String noLiveChannelsInCategory = 'No live channels in {category} right now';
  
  /// TV/Movies
  static const String noLiveChannels = 'No live channels right now';
  
  /// News
  static const String readFullStory = 'Read full story';
  
  /// Diagnostics
  static const String adDiagnostics = 'Ad diagnostics';
  static const String testRewardedAd = 'Test rewarded ad';
  
  /// Updates
  static const String updateAvailable = 'Update available';
  static const String later = 'Later';
  static const String downloadApk = 'Download APK';
  
  /// Exit
  static const String exitLumio = 'Exit Lumio?';
  static const String exit = 'Exit';
  
  /// Ads & Privacy
  static const String adsAndPrivacy = 'Ads & privacy';
  static const String watchAdForAdFreeTime = 'Watch ad for ad-free time';
  static const String limitedAdsOnly = 'Limited ads only';
  static const String accept = 'Accept';
  
  /// Match alerts
  static const String matchAlerts = 'Match alerts';
  static const String allow = 'Allow';
  
  /// Sharing
  static const String inviteLinkCopied = 'Invite link copied — share on Facebook, WhatsApp, or Telegram';
  
  /// Player failover
  static const String switchingToBackupStream = 'Switching to backup stream...';
  
  /// Channel player
  static const String channelNoStreamLink = 'This channel has no stream link';
  static const String tapAgainToWatch = 'Tap again to watch';
  
  /// Favorites
  static const String alreadyInFavorites = '{channelName} already in favorites';
  static const String addedToFavoritesChannel = '{channelName} added to favorites';
  static const String removedFromFavoritesChannel = '{channelName} removed';
  
  /// Blocked apps
  static const String uninstall = 'Uninstall';
  static const String block = 'Block';
  
  /// 404 / Not found
  static const String pageNotFound = 'Page not found';

  // ==================== DYNAMIC STRING HELPERS ====================
  
  /// Helper for sport-specific no channels message
  static String noChannelsInSportMessage(String sportName) {
    return noChannelsInSport.replaceAll('{sport}', sportName);
  }
  
  /// Helper for category-specific no channels message
  static String noChannelsInCategoryMessage(String categoryName) {
    return noLiveChannelsInCategory.replaceAll('{category}', categoryName);
  }
  
  /// Helper for channel name in favorites messages
  static String channelAlreadyInFavorites(String channelName) {
    return alreadyInFavorites.replaceAll('{channelName}', channelName);
  }
  
  /// Helper for channel name in added to favorites
  static String channelAddedToFavorites(String channelName) {
    return addedToFavoritesChannel.replaceAll('{channelName}', channelName);
  }
  
  /// Helper for channel name in removed from favorites
  static String channelRemovedFromFavorites(String channelName) {
    return removedFromFavoritesChannel.replaceAll('{channelName}', channelName);
  }
  
  /// Helper for permission-specific message
  static String permissionNeededFor(String permissionName) {
    return permissionDeniedTitle.replaceAll('[permission]', permissionName);
  }
}
