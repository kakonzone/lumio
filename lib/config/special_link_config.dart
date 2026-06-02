/// External playlist sources for Home → Browse → Special Link (GITUN).
class SpecialLinkConfig {
  SpecialLinkConfig._();

  static const hubTitle = 'Special Link';
  static const gitunTitle = 'GITUN';

  /// **Your** GitHub playlist — home, sports, live, categories (only source for main app).
  /// Update channels by editing this file on GitHub; app refreshes within [gitunCacheTtl] or pull-to-refresh.
  static const appCatalogPlaylistUrl =
      'https://github.com/kakonzone/allchannelking.m3u8/blob/main/allchannelking.m3u8';

  /// Home featured cards (World Cup 2026, etc.) — edit on GitHub; app picks up on refresh.
  static const featuredLiveEventsUrl =
      'https://github.com/kakonzone/allchannelking.m3u8/blob/main/featured_live_events.json';

  /// How often to re-fetch [featuredLiveEventsUrl] (pull-to-refresh bypasses).
  static const featuredLiveEventsCacheTtl = Duration(minutes: 15);

  /// Auto-load sports `.m3u` / `.m3u8` from these repos into GITUN (sports filter applied).
  static const gitunAutoDiscoverRepos = <GitunAutoRepo>[
    GitunAutoRepo(owner: 'yIsus-mEx', repo: 'Sports.M3U8', branch: 'main'),
  ];

  /// Third-party GitHub playlists for GITUN — **sports channels only** ([sportsOnly] default true).
  /// Do **not** add [appCatalogPlaylistUrl] or kakonzone/allchannelking here.
  static const gitunPlaylistSources = <GitunPlaylistSource>[
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/TVTVHD.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/SharkStreams.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/Roxie.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/SlapStreams.NHL.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/StreamEast.NBA.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/StreamEast.MLB.m3u8',
      sportsOnly: true,
    ),
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/yIsus-mEx/Sports.M3U8/blob/main/MLBWebcast.m3u8',
      sportsOnly: true,
    ),
  ];

  @Deprecated('Use gitunPlaylistSources')
  static List<String> get gitunPlaylistUrls =>
      gitunPlaylistSources.map((s) => s.pageUrl).toList();

  /// Refresh from GitHub at most this often; pull-to-refresh bypasses cache.
  static const gitunCacheTtl = Duration(hours: 1);

  static bool isAppCatalogUrl(String pageUrl) {
    final a = pageUrl.trim().toLowerCase();
    final b = appCatalogPlaylistUrl.trim().toLowerCase();
    return a == b || a.contains('kakonzone/allchannelking');
  }
}

/// Public GitHub repo — root-level M3U files merged into GITUN (sports filter).
class GitunAutoRepo {
  const GitunAutoRepo({
    required this.owner,
    required this.repo,
    this.branch = 'main',
  });

  final String owner;
  final String repo;
  final String branch;
}

/// One GITUN third-party M3U source — defaults to [sportsOnly] (sports channels only).
class GitunPlaylistSource {
  const GitunPlaylistSource({
    required this.pageUrl,
    this.includeAllChannels = false,
    this.sportsOnly = true,
  });

  final String pageUrl;

  /// Owner app catalog only — never true for GITUN third-party sources.
  final bool includeAllChannels;

  /// When true (default for GITUN), only sports-like channels are kept.
  final bool sportsOnly;
}
