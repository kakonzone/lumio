part of lumio_player;

class PlayerScreen extends StatefulWidget {
  static const String routeName = '/player'; // ← FIX #4

  final String streamUrl;
  final String title;
  final String subtitle;
  final String category;
  final List<ChannelModel>? relatedChannels;
  final Map<String, String>? headers;
  final List<StreamLink>? streamLinks;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.subtitle = '',
    this.category = '',
    this.relatedChannels,
    this.headers,
    this.streamLinks,
  });

  /// Convenience push helper — call from any screen.
  static void open(
    BuildContext context, {
    required String url,
    required String title,
    String subtitle = '',
    String category = '',
    List<ChannelModel>? related,
    Map<String, String>? headers,
    List<StreamLink>? streamLinks,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          streamUrl: url,
          title: title,
          subtitle: subtitle,
          category: category,
          relatedChannels: related,
          headers: headers,
          streamLinks: streamLinks,
        ),
      ),
    );
  }

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoCtrl;
  final Floating _floating = Floating();
  bool _pipAvailable = false;
  /// After a failed PiP setup, skip further native calls (stops log spam).
  bool _pipBlocked = false;

  bool _initialized = false;
  /// True after [Video] has been laid out — required before mpv open on Android.
  bool _videoSurfaceMounted = false;
  /// Stays true after first successful open — keeps in-player WebViews mounted.
  bool _playbackSurfaceReady = false;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _showControls = false;
  bool _isBuffering = false;
  final ValueNotifier<bool> _bufferingVisible = ValueNotifier(false);
  final GlobalKey _stickyAdKey = GlobalKey();
  static const String _fitPrefKey = 'player_fit_mode';
  PlayerFitMode _fitMode = PlayerFitMode.fit;

  double _volume = 1.0;
  double _brightness = 0.5;
  double _indicatorOpacity = 0.0;
  double _seekOverlayOpacity = 0.0;
  String? _seekOverlayLabel;
  String? _channelSwipeOverlay;
  DateTime? _lastSwipeAt;
  DateTime? _lastRetryAt;

  bool _applyingQuality = false;
  bool _userOverrideQuality = false;
  bool _pipConfigured = false;
  bool _probeInFlight = false;
  List<ChannelModel> _relatedDisplay = const [];
  double _estimatedMbps = 2.0;
  bool _isOnWifi = false;
  int _batteryPercent = 100;
  static final Battery _qualityBattery = Battery();
  int _stablePlaybackTicks = 0;
  int _switchGeneration = 0;

  String _qualityBadge = '';
  double? _scrubValue;

  Timer? _bufferingWatchdog;
  DateTime? _bufferingStartedAt;
  int _failoverAttempts = 0;
  final Set<int> _failedLinks = {};
  final Set<int> _schemeFlipUsedForLink = {};
  DateTime? _lastFailoverAt;
  DateTime? _failoverSuppressedUntil;
  static const int _maxFailoverAttempts = 3;
  static const Duration _connectTimeout = Duration(
    milliseconds: int.fromEnvironment('STREAM_CONNECT_TIMEOUT_MS', defaultValue: 6000),
  );
  static const Duration _bufferingTimeout = Duration(seconds: 12);
  static const Duration _failoverCooldown = Duration(seconds: 5);
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  StreamSubscription<bool>? _idleProbeSub;
  int _idleWorkToken = 0;

  String _selectedQuality = 'Auto';
  int _selectedTargetHeight = 0;
  int? _lastMpvCapHeight;
  int _sourceHeight = 0;
  bool _mpvNativeConfigured = false;
  bool _vfPrewarmed = false;
  Timer? _qualityDebounce;
  int? _pendingVfHeight;
  String? _currentUrl;
  late String _masterUrl;
  String _currentTitle = '';
  List<HlsVariant> _hlsVariants = [];
  Map<String, String>? _activeHeaders;
  int? _pendingTargetHeight;
  late List<StreamLink> _links;
  int _activeLinkIndex = 0;
  late String _relatedCategory;

  Timer? _hideTimer;
  Timer? _indicatorTimer;
  Timer? _autoQualityTimer;
  Timer? _midRollTimer;
  Timer? _channelSwitchDebounce;
  bool _showVideoAdOverlay = false;
  Completer<void>? _videoAdCompleter;
  ChannelModel? _debouncedChannel;
  bool _isPlaying = false;
  bool _pauseAdVisible = false;
  bool _pauseAdShown = false;
  DateTime? _playbackStartedAt;

  // ── Vertical drag (volume / brightness) ───────────────
  bool _isDragging = false;
  bool _draggingVolume = false;
  double _dragStartY = 0;
  double _dragStartVal = 0;

  // ── Subscriptions ──────────────────────────────────────
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription? _tracksSub;
  StreamSubscription<PiPStatus>? _pipStatusSub;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final bufferBytes = PerformanceTuning.playerBufferBytes;
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: bufferBytes,
      ),
    );
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:initState',
      message: 'player init bufferSize',
      hypothesisId: 'H4-buffer',
      data: {'bufferMb': PerformanceTuning.playerBufferMb},
    );
    // #endregion
    _videoCtrl = VideoController(_player);
    _links = _resolveStreamLinks();
    _activeLinkIndex = 0;
    _masterUrl = _links.first.url;
    _currentUrl = _links.first.url;
    _currentTitle = widget.title;
    _relatedCategory = widget.category;
    _relatedDisplay = widget.relatedChannels ?? const [];
    _activeHeaders = _links.first.headers;
    _loadBrightness();
    _loadPreferredQuality();
    _loadFitMode();
    _attachListeners();
    _scheduleIdleWork();
    unawaited(_bindBackgroundPlayback());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runPreRollThenPlay());
    });
    _startAutoQualityTimer();
    _pipStatusSub = _floating.pipStatusStream.listen(
      (status) {
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:pipStatusStream',
          message: 'pip status',
          hypothesisId: 'H-pip',
          data: {'status': status.name},
        );
        // #endregion
      },
      onError: (_) {},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(LumioWindowSecure.setSecure(false));
      unawaited(_enableLeavePiP());
      unawaited(_ensureRelatedChannelsReady());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final playing = _player.state.playing;
    final buffering = _player.state.buffering;
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:didChangeAppLifecycleState',
      message: 'lifecycle change',
      hypothesisId: 'H1-lifecycle',
      data: {
        'state': state.name,
        'playing': playing,
        'buffering': buffering,
        'pipAvailable': _pipAvailable,
        'handlerAttached': lumioAudioHandlerOrNull?.hasPlayer ?? false,
      },
    );
    // #endregion
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _suppressFailoverFor(const Duration(seconds: 30));
        unawaited(_keepPlaybackAliveInBackground());
        if (!_pipBlocked && _pipAvailable && _initialized && !_hasError) {
          unawaited(_enterPipNow());
        }
        break;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void deactivate() {
    // Tear down video before home banner/platform views repaint (Android <33 crash).
    AdManager.instance.setStreaming(false);
    try {
      _player.pause();
    } catch (_) {}
    super.deactivate();
  }

  @override
  void dispose() {
    AdTriggerManager.instance.onPlayerChannelStopped();
    AdManager.instance.setStreaming(false);
    _midRollTimer?.cancel();
    _videoAdCompleter?.complete();
    WidgetsBinding.instance.removeObserver(this);
    lumioAudioHandlerOrNull?.detachPlayer();
    if (_pipConfigured) {
      try {
        _floating.cancelOnLeavePiP();
      } catch (_) {}
      _pipConfigured = false;
    }
    unawaited(LumioWindowSecure.setSecure(true));
    _hideTimer?.cancel();
    _indicatorTimer?.cancel();
    _autoQualityTimer?.cancel();
    _channelSwitchDebounce?.cancel();
    _qualityDebounce?.cancel();
    _bufferingWatchdog?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _playingSub?.cancel();
    _positionSub?.cancel();
    _widthSub?.cancel();
    _heightSub?.cancel();
    _tracksSub?.cancel();
    _pipStatusSub?.cancel();
    _idleProbeSub?.cancel();
    _bufferingVisible.dispose();
    _player.dispose();
    try {
      ScreenBrightness().resetScreenBrightness();
    } catch (e, st) {
      agentDebugLog(
        location: 'player_screen.dart:dispose',
        message: 'resetScreenBrightness failed',
        hypothesisId: 'H-brightness',
        data: {'err': e.toString(), 'st': st.toString()},
      );
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PiPSwitcher(
      floating: _floating,
      childWhenDisabled: _buildFullPlayerUi(context),
      childWhenEnabled: _buildPipOnlyUi(),
    );
  }

  // ── Default fallback channels (no API data) ────────────

  static final _defaultSportsChannels = [
    ChannelModel(
      id: 'r1',
      name: 'T Sports',
      category: 'Sports',
      country: 'BD',
      streamUrl: 'https://198.195.239.50:8095/Tsports/tracks-v1a1/mono.m3u8',
      isLive: true,
      viewers: 22000,
      currentShow: 'Live Cricket',
    ),
    ChannelModel(
      id: 'r2',
      name: 'Willow HD',
      category: 'Sports',
      country: 'US',
      streamUrl: 'https://198.195.239.50:8095/WiLLow/index.m3u8',
      isLive: true,
      viewers: 18500,
      currentShow: 'Cricket Live',
    ),
    ChannelModel(
      id: 'r3',
      name: 'PTV Sports',
      category: 'Sports',
      country: 'PK',
      streamUrl: 'https://198.195.239.50:8095/PTV-kutta/video.m3u8',
      isLive: true,
      viewers: 9200,
      currentShow: 'PSL Live',
    ),
  ];

  static final _defaultBanglaChannels = [
    ChannelModel(
      id: 'r4',
      name: 'Nagorik TV',
      category: 'Bangladesh',
      country: 'BD',
      streamUrl: 'https://198.195.239.50:8095/nagorik/tracks-v1a1/mono.m3u8',
      isLive: true,
      viewers: 4100,
      currentShow: 'Bangla Program',
    ),
    ChannelModel(
      id: 'r5',
      name: 'News24 Bangladesh',
      category: 'Bangladesh',
      country: 'BD',
      streamUrl: 'https://198.195.239.50:8095/News24/tracks-v1a1/mono.m3u8',
      isLive: true,
      viewers: 6300,
      currentShow: 'News Live',
    ),
    ChannelModel(
      id: 'r7',
      name: 'BTV',
      category: 'Bangladesh',
      country: 'BD',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1709/output/index.m3u8',
      isLive: true,
      viewers: 5200,
      currentShow: 'National TV',
    ),
    ChannelModel(
      id: 'r8',
      name: 'Jamuna TV',
      category: 'Bangladesh',
      country: 'BD',
      streamUrl: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1701/output/index.m3u8',
      isLive: true,
      viewers: 5800,
      currentShow: 'News',
    ),
  ];
}
