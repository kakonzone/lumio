/// External playlist sources for Home → Browse → Special Link (GITUN).
class SpecialLinkConfig {
  SpecialLinkConfig._();

  static const hubTitle = 'Special Link';
  static const gitunTitle = 'GITUN';

  /// Main channel catalog is **Appwrite** ([AppwriteService]) — not GitHub.
  /// Home featured cards (World Cup 2026) — **Appwrite** `app_config` / `featured_live_events`.

  /// GITUN GitHub sources live in Appwrite `special_links` (see `data/special_links.json`).
  /// Deploy syncs them; the app reads URLs from Appwrite then fetches M3U.

  @Deprecated('Sources are in Appwrite special_links — edit data/special_links.json')
  static const gitunAutoDiscoverRepos = <GitunAutoRepo>[
    GitunAutoRepo(owner: 'yIsus-mEx', repo: 'Sports.M3U8', branch: 'main'),
  ];

  @Deprecated('Sources are in Appwrite special_links — edit data/special_links.json')
  static const gitunPlaylistSources = <GitunPlaylistSource>[
    GitunPlaylistSource(
      pageUrl:
          'https://github.com/FunctionError/PiratesTv/blob/main/combined_playlist.m3u',
      sportsOnly: true,
    ),
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

  /// True for legacy owner GitHub playlist URLs (exclude from GITUN if ever re-added).
  static bool isAppCatalogUrl(String pageUrl) {
    final a = pageUrl.trim().toLowerCase();
    return a.contains('kakon122/my-media-notes') ||
        a.contains('kakonzone/allchannelking');
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
