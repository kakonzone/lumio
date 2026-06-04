import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:floating/floating.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/model.dart';
import '../provider/app_provider.dart';
import '../services/hls_quality_service.dart';
import '../services/stream_link_ranker_service.dart';
import '../widgets/channel_avatar.dart';
import '../utils/ad_debug_log.dart';
import '../utils/debug_log.dart';
import '../core/performance_tuning.dart';
import '../core/player/quality_config.dart';
import '../services/lumio_audio_service.dart';
import '../services/lumio_window_secure.dart';
import '../services/firebase_bootstrap.dart';
import '../ads/ad_manager.dart';
import '../ads/interstitial_placement.dart';
import '../services/ad_trigger_manager.dart';
import '../ads/ad_placement_config.dart';
import '../ads/adsterra/adsterra_native.dart';
import '../ads/propeller/propeller_webview.dart';
import '../config/monetag_config.dart';
import '../services/user_preferences.dart';
import '../widgets/player_ad_slot.dart' show PlayerAdSlot, PlayerStickyAdStrip;
import '../config/ad_config.dart';
import '../widgets/player_video_ad_overlay.dart';
import 'player_screen_widgets.dart';

// #region agent log
void _debugSessionLog({
  required String location,
  required String message,
  required String hypothesisId,
  Map<String, dynamic>? data,
  String runId = 'verify',
}) {
  agentDebugLogToFile(
    sessionId: '6f9d36',
    fileName: 'debug-6f9d36.log',
    location: location,
    message: message,
    hypothesisId: hypothesisId,
    data: data,
    runId: runId,
  );
}
// #endregion

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
  /// Stays true after first successful open — keeps in-player WebViews mounted.
  bool _playbackSurfaceReady = false;
  bool _hasError = false;
  bool _isFullscreen = false;
  bool _showControls = false;
  bool _isBuffering = false;
  final ValueNotifier<bool> _bufferingVisible = ValueNotifier(false);
  final GlobalKey _stickyAdKey = GlobalKey();
  BoxFit _videoFit = BoxFit.contain;

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
    _attachListeners();
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
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _probeRelatedChannels();
      });
    });
  }

  Future<void> _loadPreferredQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final h = prefs.getInt('preferred_quality_height');
      if (h != null && mounted) {
        setState(() {
          _selectedTargetHeight = h;
          _selectedQuality = h == 0 ? 'Auto' : '${h}p';
          _pendingTargetHeight = h == 0 ? null : h;
          _userOverrideQuality = h != 0;
        });
      } else if (mounted) {
        final device = _qualityDeviceClasses();
        final initialPx = QualityConfig.initialTargetHeightPx(
          isTablet: device.$1,
          isDesktop: device.$2,
        );
        setState(() {
          _selectedTargetHeight = initialPx;
          _selectedQuality = '${initialPx}p';
          _pendingTargetHeight = initialPx;
          _userOverrideQuality = false;
        });
      }
    } catch (e) {
      agentDebugLog(
        location: 'player_screen.dart:_loadPreferredQuality',
        message: 'prefs read failed',
        hypothesisId: 'H-prefs',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _ensureRelatedChannelsReady() async {
    if (_relatedCategory.toUpperCase() == 'GITUN') {
      await context.read<AppProvider>().ensureGitunChannelsLoaded();
    }
    if (!mounted) return;
    _refreshRelatedDisplay();
  }

  void _refreshRelatedDisplay() {
    if (!mounted) return;
    final list = context.read<AppProvider>().playerRelatedChannels(
          currentTitle: _currentTitle,
          currentUrl: _currentUrl,
          relatedCategory: _relatedCategory,
          fallback: widget.relatedChannels,
        );
    if (list.length == _relatedDisplay.length &&
        list.every((c) => _relatedDisplay.any((d) => d.id == c.id))) {
      return;
    }
    setState(() => _relatedDisplay = list);
  }

  (bool, bool) _qualityDeviceClasses() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return (false, false);
    final view = views.first;
    final logicalShort =
        view.physicalSize.shortestSide / view.devicePixelRatio;
    return (logicalShort >= 600, false);
  }

  void _probeRelatedChannels() {
    if (!mounted || _probeInFlight) return;
    if (_relatedDisplay.isEmpty) return;
    _probeInFlight = true;
    final probe = _relatedDisplay.take(6).toList();
    context
        .read<AppProvider>()
        .ensureStreamHealth(probe, priority: false)
        .whenComplete(() {
      _probeInFlight = false;
    });
  }

  Future<void> _enableLeavePiP() async {
    if (_pipBlocked) return;
    try {
      await LumioWindowSecure.setSecure(false);
      final available = await _floating.isPipAvailable;
      if (!available) {
        _pipAvailable = false;
        _pipBlocked = true;
        if (mounted) setState(() {});
        return;
      }
      await _floating.enable(
        const OnLeavePiP(aspectRatio: Rational(16, 9)),
      );
      _pipAvailable = true;
      _pipConfigured = true;
      agentDebugLog(
        location: 'player_screen.dart:_enableLeavePiP',
        message: 'PiP on-leave enabled',
        hypothesisId: 'H-pip',
      );
    } catch (e) {
      _pipAvailable = false;
      _pipConfigured = false;
      _pipBlocked = true;
      agentDebugLog(
        location: 'player_screen.dart:_enableLeavePiP',
        message: 'PiP enable failed',
        hypothesisId: 'H-pip',
        data: {'err': e.toString()},
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _enterPipNow() async {
    if (_pipBlocked || !_pipAvailable || !_initialized || _hasError) return;
    try {
      await LumioWindowSecure.setSecure(false);
      final status = await _floating.enable(
        const ImmediatePiP(aspectRatio: Rational(16, 9)),
      );
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_enterPipNow',
        message: 'immediate pip',
        hypothesisId: 'H-pip',
        data: {'status': status.name},
      );
      // #endregion
    } catch (e) {
      _pipBlocked = true;
      _pipAvailable = false;
      if (mounted) setState(() {});
      _debugSessionLog(
        location: 'player_screen.dart:_enterPipNow',
        message: 'immediate pip failed',
        hypothesisId: 'H-pip',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _keepPlaybackAliveInBackground() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (_player.state.playing) return;
    try {
      await _player.play();
    } catch (_) {}
  }

  void _cancelPendingOps() {
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = null;
    _bufferingStartedAt = null;
    _probeInFlight = false;
    _switchGeneration++;
  }

  void _startAutoQualityTimer() {
    _autoQualityTimer?.cancel();
    _autoQualityTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _userOverrideQuality || _selectedTargetHeight != 0) {
        return;
      }
      if (_isBuffering && _bufferingStartedAt != null) {
        unawaited(_evaluateAutoQuality(downgrade: true));
      } else if (_stablePlaybackTicks >= 4) {
        unawaited(_evaluateAutoQuality(stepUp: true));
        _stablePlaybackTicks = 0;
      }
    });
  }

  Future<void> _refreshConnectivityHint() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _isOnWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (_isOnWifi) {
        _estimatedMbps = 8.0;
      } else if (results.contains(ConnectivityResult.mobile)) {
        _estimatedMbps = 2.0;
      } else if (results.contains(ConnectivityResult.none)) {
        _estimatedMbps = 0.3;
      }
      try {
        _batteryPercent = await _qualityBattery.batteryLevel;
      } catch (_) {}
    } catch (e) {
      agentDebugLog(
        location: 'player_screen.dart:_refreshConnectivityHint',
        message: 'connectivity check failed',
        hypothesisId: 'H-auto-quality',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _runInitialBandwidthSample() async {
    await _refreshConnectivityHint();
    var bufferingMs = 0;
    late final StreamSubscription<bool> bufSub;
    bufSub = _player.stream.buffering.listen((b) {
      if (b) bufferingMs += 200;
    });
    await Future.delayed(const Duration(seconds: 5));
    await bufSub.cancel();
    if (!mounted) return;
    if (bufferingMs > 2500) {
      _estimatedMbps = (_estimatedMbps * 0.45).clamp(0.2, 20.0);
    } else if (bufferingMs < 400) {
      _estimatedMbps = (_estimatedMbps * 1.25).clamp(0.2, 20.0);
    }
    agentDebugLog(
      location: 'player_screen.dart:_runInitialBandwidthSample',
      message: 'bandwidth sample done',
      hypothesisId: 'H-auto-quality',
      data: {'mbps': _estimatedMbps, 'bufferingMs': bufferingMs},
    );
    await _evaluateAutoQuality();
  }

  Future<void> _evaluateAutoQuality({
    bool downgrade = false,
    bool stepUp = false,
  }) async {
    if (!mounted || _userOverrideQuality || _selectedTargetHeight != 0) {
      return;
    }
    if (_hlsVariants.isEmpty) return;
    if (stepUp && !downgrade) {
      await _refreshConnectivityHint();
    }
    if (downgrade) {
      _estimatedMbps = (_estimatedMbps * 0.7).clamp(0.2, 20.0);
    }
    var variant = HlsQualityService.pickVariantForAuto(
      _hlsVariants,
      _estimatedMbps,
      downgrade: downgrade,
    );
    if (variant == null) return;
    final clampedH = QualityConfig.clampAutoHeightPx(
      targetHeightPx: variant.height,
      isMobile: QualityConfig.isMobilePlatform,
      isOnWifi: _isOnWifi,
      batteryPercent: _batteryPercent,
    );
    if (clampedH != variant.height) {
      variant = HlsQualityService.pickVariantForced(_hlsVariants, clampedH) ??
          variant;
    }
    agentDebugLog(
      location: 'player_screen.dart:_evaluateAutoQuality',
      message: 'auto tier selected',
      hypothesisId: 'H-auto-quality',
      data: {
        'mbps': _estimatedMbps,
        'height': variant.height,
        'downgrade': downgrade,
        'stepUp': stepUp,
      },
    );
    await _applyAutoVariant(variant);
  }

  Future<void> _applyAutoVariant(HlsVariant variant) async {
    if (!mounted || _applyingQuality) return;
    _applyingQuality = true;
    try {
      if (_currentUrl == _masterUrl &&
          _player.state.tracks.video.isNotEmpty) {
        final tracks = _selectableVideoTracks;
        final match = _findTrackForced(variant.height, tracks);
        if (match != null) {
          await _player.setVideoTrack(match);
          _updateQualityBadge();
          return;
        }
      }
      if (variant.url != _currentUrl) {
        await _openStreamUrl(variant.url, _activeHeaders);
        if (mounted) setState(() => _currentUrl = variant.url);
      }
      _updateQualityBadge();
    } finally {
      _applyingQuality = false;
    }
  }

  /// Open playback immediately; rank/probe links in background when needed.
  Future<void> _prepareLinksAndPlay() async {
    // #region agent log
    agentDebugLog(
      location: 'player_screen.dart:_prepareLinksAndPlay',
      message: 'prepare start',
      hypothesisId: 'H-prepare',
      data: {
        'linkCount': _links.length,
        'labels': _links.map((l) => l.label).toList()
      },
    );
    // #endregion

    if (!mounted) return;
    _warmAlternateLinks();
    await _bootstrapPlayback();

    if (_links.length > 1) {
      unawaited(_rankLinksInBackground());
    }
  }

  void _warmAlternateLinks() {
    if (_links.length <= 1) return;
    for (var i = 1; i < _links.length && i < 3; i++) {
      final link = _links[i];
      final uri = Uri.tryParse(link.url);
      if (uri == null || !uri.hasScheme) continue;
      unawaited(
        http
            .head(uri, headers: link.headers)
            .timeout(const Duration(seconds: 3))
            .catchError((_) => http.Response('', 599)),
      );
    }
  }

  Future<void> _rankLinksInBackground() async {
    await Future.delayed(const Duration(seconds: 15));
    if (!mounted || _isBuffering || !_player.state.playing) return;
    final gen = _switchGeneration;
    final ranked = await StreamLinkRankerService.rankBySpeed(_links);
    if (!mounted || gen != _switchGeneration) return;
    if (ranked.first.url == _masterUrl) return;
    agentDebugLog(
      location: 'player_screen.dart:_rankLinksInBackground',
      message: 'switching to faster link',
      hypothesisId: 'H-auto-select',
      data: {'label': ranked.first.label},
    );
    setState(() {
      _links = ranked;
      _activeLinkIndex = 0;
      _masterUrl = ranked.first.url;
      _currentUrl = ranked.first.url;
      _activeHeaders = ranked.first.headers;
    });
    await _bootstrapPlayback(skipOpen: false);
  }

  Future<void> _bootstrapPlayback({bool skipOpen = false}) async {
    _suppressFailoverFor(const Duration(seconds: 25));
    final variants = await HlsQualityService.fetchVariantsFast(
      _masterUrl,
      headers: _activeHeaders,
    );
    var openUrl = _masterUrl;
    final low = HlsQualityService.lowestVariant(variants);
    if (low != null && low.url.isNotEmpty) {
      openUrl = low.url;
    }
    _currentUrl = openUrl;
    if (!mounted) return;
    setState(() => _hlsVariants = variants);
    if (!skipOpen) {
      await _initPlayer(openUrl, _activeHeaders);
    }
    if (!mounted) return;

    if (_pendingTargetHeight != null && _pendingTargetHeight! > 0) {
      await _applyQuality(_selectedQuality, _pendingTargetHeight!);
      _pendingTargetHeight = null;
    } else if (!_userOverrideQuality && _selectedTargetHeight == 0) {
      unawaited(_runInitialBandwidthSample());
    }
  }

  Future<void> _reloadMasterVariants() async {
    final variants = await HlsQualityService.fetchVariants(
      _masterUrl,
      headers: _activeHeaders,
    );
    if (mounted) setState(() => _hlsVariants = variants);
  }

  void _attachListeners() {
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (!mounted) return;
      _isBuffering = isBuffering;
      if (_bufferingVisible.value != isBuffering) {
        _bufferingVisible.value = isBuffering;
      }
      if (isBuffering) {
        if (!_canRunFailover) {
          _resetBufferingWatchdog();
          return;
        }
        _bufferingStartedAt = DateTime.now();
        _scheduleFailoverCheck();
      } else {
        _bufferingStartedAt = null;
        _bufferingWatchdog?.cancel();
        _bufferingWatchdog = null;
        if (_failoverAttempts > 0) _failoverAttempts = 0;
      }
    });
    _errorSub = _player.stream.error.listen((e) {
      if (!mounted || e.isEmpty) return;
      agentDebugLog(
        location: 'player_screen.dart:_errorSub',
        message: 'player error',
        hypothesisId: 'H-failover',
        data: {'err': e, 'linkIndex': _activeLinkIndex},
      );
      if (!_canRunFailover) return;
      if (_failoverAttempts < _maxFailoverAttempts) {
        unawaited(_attemptFailover());
        return;
      }
      setState(() {
        _hasError = true;
        _isBuffering = false;
      });
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (playing) {
        _isPlaying = true;
        _playbackStartedAt ??= DateTime.now();
        if (_pauseAdVisible) {
          setState(() => _pauseAdVisible = false);
        }
        _resetBufferingWatchdog();
        _stablePlaybackTicks++;
        if (_initialized && !_pipConfigured) {
          unawaited(_enableLeavePiP());
        }
      } else {
        _isPlaying = false;
        _stablePlaybackTicks = 0;
        _onPlayerPaused();
      }
    });
    _positionSub = _player.stream.position.listen((_) {
      _resetBufferingWatchdog();
    });
    _widthSub = _player.stream.width.listen((_) => _updateQualityBadge());
    _heightSub = _player.stream.height.listen((h) {
      if (h != null && h > 0) {
        _sourceHeight = h;
        if (!_vfPrewarmed &&
            !_applyingQuality &&
            !_isBuffering &&
            _player.state.playing &&
            _stablePlaybackTicks >= 2 &&
            _isSingleRenditionStream) {
          unawaited(_prewarmMpvFilters());
        }
      }
      _updateQualityBadge();
    });
    _tracksSub = _player.stream.tracks.listen((_) {
      if (!mounted || _applyingQuality) return;
      _updateQualityBadge();
    });
  }

  bool get _canRunFailover {
    if (_applyingQuality) return false;
    final until = _failoverSuppressedUntil;
    if (until != null && DateTime.now().isBefore(until)) return false;
    return true;
  }

  void _suppressFailoverFor(Duration duration) {
    _failoverSuppressedUntil = DateTime.now().add(duration);
    _resetBufferingWatchdog();
    _bufferingStartedAt = null;
  }

  void _resetBufferingWatchdog() {
    _bufferingStartedAt = null;
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = null;
  }

  void _scheduleFailoverCheck() {
    if (!_canRunFailover) return;
    _bufferingWatchdog?.cancel();
    _bufferingWatchdog = Timer(_bufferingTimeout, () async {
      if (!mounted || _bufferingStartedAt == null || !_canRunFailover) return;
      if (DateTime.now().difference(_bufferingStartedAt!) < _bufferingTimeout) {
        return;
      }
      if (_failoverAttempts >= _maxFailoverAttempts) {
        _showFailoverExhaustedUi();
        return;
      }
      _failoverAttempts++;
      agentDebugLog(
        location: 'player_screen.dart:_scheduleFailoverCheck',
        message: 'buffering watchdog fired',
        hypothesisId: 'H-failover',
        data: {
          'attempt': _failoverAttempts,
          'linkIndex': _activeLinkIndex,
        },
      );
      await _attemptFailover();
    });
  }

  void _showFailoverExhaustedUi() {
    if (!mounted) return;
    agentDebugLog(
      location: 'player_screen.dart:_showFailoverExhaustedUi',
      message: 'all failover links exhausted',
      hypothesisId: 'H-failover',
      data: {'failedLinks': _failedLinks.toList()},
    );
    setState(() {
      _hasError = true;
      _isBuffering = false;
    });
  }

  Future<void> _retryCurrentLink() async {
    final url = _currentUrl ?? _masterUrl;
    if (url.isEmpty) return;
    _suppressFailoverFor(const Duration(seconds: 25));
    _failoverAttempts = 0;
    _failedLinks.clear();
    if (mounted) {
      setState(() {
        _hasError = false;
        _isBuffering = true;
      });
    }
    await _openStreamUrl(url, _activeHeaders);
  }

  Future<void> _attemptFailover() async {
    if (!mounted || !_canRunFailover) return;
    if (_lastFailoverAt != null &&
        DateTime.now().difference(_lastFailoverAt!) < _failoverCooldown) {
      return;
    }
    _lastFailoverAt = DateTime.now();

    if (_links.length <= 1) {
      if (_failoverAttempts >= _maxFailoverAttempts) {
        _showFailoverExhaustedUi();
        return;
      }
      _failoverAttempts++;
      if (await _trySchemeFlipForCurrentLink()) return;
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_attemptFailover',
        message: 'retry single link',
        hypothesisId: 'H-failover-single',
        data: {'attempt': _failoverAttempts, 'urlTail': _masterUrl.split('/').last},
      );
      // #endregion
      await _retryCurrentLink();
      return;
    }
    if (await _trySchemeFlipForCurrentLink()) return;

    _failedLinks.add(_activeLinkIndex);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switching to backup stream...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    for (var i = 1; i < _links.length; i++) {
      final next = (_activeLinkIndex + i) % _links.length;
      if (_failedLinks.contains(next)) continue;
      await _recordPlayerCrashlyticsError(
        Exception('player_failover_switch'),
        StackTrace.current,
        reason: 'failover_from_${_activeLinkIndex}_to_$next',
      );
      agentDebugLog(
        location: 'player_screen.dart:_attemptFailover',
        message: 'failover switch',
        hypothesisId: 'H-failover',
        data: {'from': _activeLinkIndex, 'to': next},
      );
      await _switchToLink(next);
      return;
    }
    _showFailoverExhaustedUi();
  }

  Future<void> _recordPlayerCrashlyticsError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
  }) async {
    if (!FirebaseBootstrap.crashlyticsWired) return;
    final host = Uri.tryParse(_currentUrl ?? _masterUrl)?.host ?? 'unknown';
    await FirebaseCrashlytics.instance.setCustomKey('channel_id', widget.title);
    await FirebaseCrashlytics.instance.setCustomKey('stream_url_host', host);
    await FirebaseCrashlytics.instance.setCustomKey(
      'player_state',
      _initialized ? 'initialized' : 'booting',
    );
    await FirebaseCrashlytics.instance.recordError(
      error,
      stackTrace,
      reason: reason,
    );
  }

  bool get _isSingleRenditionStream {
    if (_hlsVariants.length > 1) return false;
    return _selectableVideoTracks.isEmpty;
  }

  void _refreshSourceHeight() {
    final h = _player.state.height ?? 0;
    if (h > 0) {
      _sourceHeight = h;
      return;
    }
    var maxH = 0;
    for (final t in _selectableVideoTracks) {
      final th = t.h ?? 0;
      if (th > maxH) maxH = th;
    }
    if (maxH > 0) _sourceHeight = maxH;
  }

  void _updateQualityBadge() {
    if (!mounted) return;
    final w = _player.state.width ?? 0;
    final h = _player.state.height ?? 0;
    if (h > 0) _sourceHeight = h;
    String badge;
    if (_selectedTargetHeight == 0) {
      badge = h > 0 ? 'AUTO • ${_formatHeightLabel(h)}' : 'AUTO';
    } else {
      badge = h > 0 ? _formatHeightLabel(h) : '${_selectedTargetHeight}p';
    }
    if (badge != _qualityBadge) {
      setState(() => _qualityBadge = badge);
      agentDebugLog(
        location: 'player_screen.dart:_updateQualityBadge',
        message: 'quality badge updated',
        hypothesisId: 'H-quality-badge',
        data: {'badge': badge, 'w': w, 'h': h},
      );
    }
  }

  String _formatHeightLabel(int h) {
    if (h >= 1080) return '1080p';
    if (h >= 720) return '720p';
    if (h >= 540) return '540p';
    if (h >= 480) return '480p';
    if (h >= 360) return '360p';
    if (h >= 270) return '270p';
    if (h >= 180) return '180p';
    return '${h}p';
  }

  double _safeUnitProgress(double value) {
    try {
      return value.clamp(0.0, 1.0);
    } catch (e, st) {
      agentDebugLog(
        location: 'player_screen.dart:_safeUnitProgress',
        message: 'Slider/Progress error: $e',
        hypothesisId: 'H-slider',
        data: {'st': st.toString()},
      );
      return 0.0;
    }
  }

  Future<void> _configureMpvOnce() async {
    if (_mpvNativeConfigured || _player.platform is! NativePlayer) return;
    final n = _player.platform as NativePlayer;
    try {
      // Player tuning (WC hotfix):
      // - mediacodec hwdec on Android avoids MIUI/ColorOS software fallback
      // - vf scale removed on mobile; mediacodec handles native output
      // - software scaling on 720p+ HLS = thermal throttle within 10 min
      await n.setProperty('cache', 'yes');
      await n.setProperty('cache-secs', '2');
      await n.setProperty('cache-pause-initial', 'no');
      await n.setProperty('demuxer-readahead-secs', '1');
      await n.setProperty('demuxer-max-bytes', '8MiB');
      await n.setProperty('demuxer-max-back-bytes', '2MiB');
      await n.setProperty('hls-bitrate', 'min');
      if (Platform.isAndroid) {
        await n.setProperty('hwdec', 'mediacodec');
        await n.setProperty('hwdec-codecs', 'h264,hevc,vp9,av1');
        await n.setProperty('vo', 'gpu');
        await n.setProperty('gpu-context', 'android');
      } else {
        await n.setProperty('hwdec', 'auto-safe');
      }
      await n.setProperty('vd-lavc-fast', 'yes');
      await n.setProperty('vd-lavc-threads', '0');
      _mpvNativeConfigured = true;
    } catch (_) {}
  }

  int _defaultPrewarmCap() {
    _refreshSourceHeight();
    if (_sourceHeight <= 0) return 720;
    if (_sourceHeight >= 720) return 720;
    final below = _sourceHeight - 24;
    return below.clamp(180, _sourceHeight - 1);
  }

  /// Pre-warm vf on mono streams so later quality switches only swap parameters.
  Future<void> _prewarmMpvFilters() async {
    if (_player.platform is! NativePlayer ||
        _vfPrewarmed ||
        _isBuffering ||
        !_player.state.playing) {
      return;
    }
    _suppressFailoverFor(const Duration(seconds: 12));
    final warmH = _defaultPrewarmCap();
    final sw = Stopwatch()..start();
    await _applyMpvHeightCap(warmH);
    _vfPrewarmed = true;
    // #region agent log
    _debugSessionLog(
      location: 'player_screen.dart:_prewarmMpvFilters',
      message: 'vf prewarm done',
      hypothesisId: 'H-mono-prewarm',
      data: {
        'warmH': warmH,
        'sourceHeight': _sourceHeight,
        'elapsedMs': sw.elapsedMilliseconds,
      },
    );
    // #endregion
  }

  void _scheduleMpvHeightCap(int? height) {
    _suppressFailoverFor(const Duration(seconds: 10));
    _pendingVfHeight = height;
    _qualityDebounce?.cancel();
    _qualityDebounce = Timer(const Duration(milliseconds: 150), () {
      final pending = _pendingVfHeight;
      _pendingVfHeight = null;
      unawaited(_applyMpvHeightCap(pending));
    });
  }

  /// Faster stream switch — keeps surface alive, skips full UI reset.
  Future<void> _openStreamUrl(String url, Map<String, String>? headers) async {
    if (!mounted) return;
    _suppressFailoverFor(const Duration(seconds: 25));
    setState(() {
      _isBuffering = true;
      _hasError = false;
    });
    try {
      await _configureMpvOnce();
      final httpHeaders = {
        'User-Agent': 'Mozilla/5.0 LumioTV/1.0',
        ...?headers,
      };
      await _player
          .open(Media(url, httpHeaders: httpHeaders), play: true)
          .timeout(_connectTimeout);
      await _player.setVolume(_volume * 100);
      if (mounted) {
        setState(() {
          _initialized = true;
          _playbackSurfaceReady = true;
        });
        _initBufferingWatchdog();
        _updateQualityBadge();
      }
    } catch (e, st) {
      await _recordPlayerCrashlyticsError(
        e,
        st,
        reason: 'player_open_stream_failed',
      );
      if (mounted) {
        setState(() {
          _hasError = true;
          _isBuffering = false;
        });
      }
      agentDebugLog(
        location: 'player_screen.dart:_openStreamUrl',
        message: 'open failed',
        hypothesisId: 'H-quality-speed',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _persistQualityPref(int targetH) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('preferred_quality_height', targetH);
    } catch (e) {
      agentDebugLog(
        location: 'player_screen.dart:_persistQualityPref',
        message: 'prefs write failed',
        hypothesisId: 'H-prefs',
        data: {'err': e.toString()},
      );
    }
  }

  Future<void> _applyMpvHeightCap(int? height) async {
    _suppressFailoverFor(const Duration(seconds: 10));
    final player = _player;
    if (player.platform is! NativePlayer) {
      agentDebugLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'non-native platform, skip',
        hypothesisId: 'H-tier3',
      );
      return;
    }
    final cap = (height == null || height <= 0) ? null : height;
    if (cap == _lastMpvCapHeight) return;
    final native = player.platform as NativePlayer;
    final sw = Stopwatch()..start();
    try {
      if (cap == null) {
        await native.setProperty('vf', '');
        _lastMpvCapHeight = null;
        agentDebugLog(
          location: 'player_screen.dart:_applyMpvHeightCap',
          message: 'vf cleared (Auto)',
          hypothesisId: 'H-tier3',
        );
        return;
      }
      _refreshSourceHeight();
      if (_sourceHeight > 0 && cap >= _sourceHeight) {
        if (_lastMpvCapHeight != null) {
          await native.setProperty('vf', '');
          _lastMpvCapHeight = null;
        }
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyMpvHeightCap',
          message: 'vf skipped at source resolution',
          hypothesisId: 'H-mono-skip-vf',
          data: {'cap': cap, 'sourceHeight': _sourceHeight},
        );
        // #endregion
        return;
      }
      if (Platform.isAndroid) {
        // WC hotfix: no CPU vf scale on Android — use HLS/track selection only.
        _lastMpvCapHeight = cap;
        return;
      }
      final filter = 'scale=-2:min($cap\\,ih):flags=fast_bilinear';
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'vf filter apply',
        hypothesisId: 'H1-vf-comma',
        data: {'height': cap, 'filter': filter},
      );
      // #endregion
      await native.setProperty('vf', filter);
      _lastMpvCapHeight = cap;
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'vf applied',
        hypothesisId: 'H-quality-speed',
        data: {
          'cap': cap,
          'sourceHeight': _sourceHeight,
          'elapsedMs': sw.elapsedMilliseconds,
        },
      );
      // #endregion
      agentDebugLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'vf scale applied',
        hypothesisId: 'H-tier3',
        data: {'height': cap, 'filter': filter},
      );
    } catch (e, st) {
      agentDebugLog(
        location: 'player_screen.dart:_applyMpvHeightCap',
        message: 'failed',
        hypothesisId: 'H-tier3',
        data: {'err': e.toString(), 'st': st.toString()},
      );
    }
  }

  Future<void> _loadBrightness() async {
    try {
      final b = await ScreenBrightness().current;
      if (mounted) setState(() => _brightness = b);
    } catch (_) {}
  }

  Future<void> _initPlayer(String url, Map<String, String>? headers) async {
    if (!mounted) return;
    setState(() {
      if (!_playbackSurfaceReady) _initialized = false;
      _hasError = false;
      _isBuffering = true;
    });
    try {
      await _openStreamUrl(url, headers);
    } catch (e, st) {
      await _recordPlayerCrashlyticsError(
        e,
        st,
        reason: 'player_init_failed',
      );
      rethrow;
    }
    if (mounted && _initialized) {
      agentDebugLog(
        location: 'player_screen.dart:_initPlayer',
        message: 'Player ready',
        hypothesisId: 'H-player-ready',
        data: {'urlTail': url.split('/').last},
      );
    }
  }

  void _initBufferingWatchdog() {
    agentDebugLog(
      location: 'player_screen.dart:_initBufferingWatchdog',
      message: 'watchdog armed',
      hypothesisId: 'H-failover',
      data: {'linkIndex': _activeLinkIndex},
    );
  }

  // ── Controls visibility ────────────────────────────────

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _revealControls({bool restartTimer = true}) {
    if (!_showControls) setState(() => _showControls = true);
    if (restartTimer) _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  // ── Playback ───────────────────────────────────────────

  void _togglePlay() {
    final wasPlaying = _player.state.playing;
    _player.playOrPause();
    if (wasPlaying) {
      _revealControls();
    } else {
      _startHideTimer();
    }
  }

  void _toggleFill() {
    setState(() {
      _videoFit = _videoFit == BoxFit.contain ? BoxFit.cover : BoxFit.contain;
    });
    _revealControls();
  }

  void _seek(int seconds) {
    final pos = _player.state.position + Duration(seconds: seconds);
    _player.seek(pos);
    _startHideTimer();
  }

  // ── Fullscreen ─────────────────────────────────────────

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _exitFullscreen();
    }
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    if (mounted) setState(() => _isFullscreen = false);
  }

  // ── Channel switch ─────────────────────────────────────

  List<StreamLink> _resolveStreamLinks() {
    final fromWidget =
        widget.streamLinks?.where((l) => l.url.isNotEmpty).toList() ?? [];
    final visible = fromWidget
        .where((l) => !ChannelModel.isInternalStreamLabel(l.label))
        .toList();
    if (visible.isNotEmpty) return visible;
    if (widget.streamUrl.isNotEmpty) {
      return [
        StreamLink(
          url: widget.streamUrl,
          label: 'Link 1',
          headers: widget.headers ?? const {'User-Agent': mozillaUA},
        ),
      ];
    }
    return [];
  }

  String? _schemeAlternateUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme == 'https') {
      return uri.replace(scheme: 'http').toString();
    }
    if (uri.scheme == 'http') {
      return uri.replace(scheme: 'https').toString();
    }
    return null;
  }

  Future<bool> _trySchemeFlipForCurrentLink() async {
    final url = _currentUrl ?? _masterUrl;
    final alt = _schemeAlternateUrl(url);
    if (alt == null || alt == url) return false;
    if (_schemeFlipUsedForLink.contains(_activeLinkIndex)) return false;
    _schemeFlipUsedForLink.add(_activeLinkIndex);
    if (mounted) {
      setState(() {
        _masterUrl = alt;
        _currentUrl = alt;
        _hasError = false;
        _isBuffering = true;
      });
    }
    await _openStreamUrl(alt, _activeHeaders);
    return true;
  }

  Future<void> _switchToLink(int index) async {
    if (index < 0 || index >= _links.length) return;
    _cancelPendingOps();
    _suppressFailoverFor(const Duration(seconds: 25));
    _lastFailoverAt = null;
    final link = _links[index];
    _failedLinks.clear();
    _failoverAttempts = 0;
    _schemeFlipUsedForLink.clear();
    setState(() {
      _activeLinkIndex = index;
      _masterUrl = link.url;
      _currentUrl = link.url;
      _activeHeaders = link.headers;
      _initialized = false;
      _hasError = false;
      if (!_userOverrideQuality) {
        _selectedQuality = 'Auto';
        _selectedTargetHeight = 0;
        _pendingTargetHeight = null;
      }
      _hlsVariants = [];
      _lastMpvCapHeight = null;
      _vfPrewarmed = false;
      _sourceHeight = 0;
      _qualityDebounce?.cancel();
    });
    await _bootstrapPlayback();
    if (mounted) _refreshRelatedDisplay();
  }

  void _scheduleChannelSwitch(ChannelModel ch) {
    _debouncedChannel = ch;
    _channelSwitchDebounce?.cancel();
    _channelSwitchDebounce = Timer(const Duration(milliseconds: 300), () {
      final target = _debouncedChannel;
      if (target == null || !mounted) return;
      unawaited(_switchChannel(target));
    });
  }

  Future<void> _switchChannel(ChannelModel ch) async {
    _cancelPendingOps();
    try {
      await _player.stop();
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_switchChannel',
        message: 'player stopped before switch',
        hypothesisId: 'H6-stop',
      );
      // #endregion
    } catch (_) {}
    final links = context.read<AppProvider>().playbackLinksFor(ch);
    if (links.isEmpty) return;
    final first = links.first;
    if (mounted) {
      setState(() {
        _links = links;
        _activeLinkIndex = 0;
        _masterUrl = first.url;
        _currentUrl = first.url;
        _currentTitle = ch.name;
        _relatedCategory = context.read<AppProvider>().categoryForRelated(
              ch,
              browseCategory:
                  _relatedCategory.toUpperCase() == 'GITUN' ? 'GITUN' : null,
            );
        _relatedDisplay = const [];
        _initialized = false;
        _hasError = false;
        _activeHeaders = first.headers;
        if (!_userOverrideQuality) {
          _selectedQuality = 'Auto';
          _selectedTargetHeight = 0;
          _pendingTargetHeight = null;
        }
        _hlsVariants = [];
        _lastMpvCapHeight = null;
        _vfPrewarmed = false;
        _sourceHeight = 0;
        _qualityDebounce?.cancel();
      });
      _syncBackgroundNowPlaying();
    }
    _failedLinks.clear();
    _failoverAttempts = 0;
    _stablePlaybackTicks = 0;
    await _bootstrapPlayback();
    if (links.length > 1) {
      unawaited(_rankLinksInBackground());
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_probeInFlight) _probeRelatedChannels();
    });
  }

  void _prefetchVisibleChannelPlaylists(List<ChannelModel> channels) {
    final headers = _activeHeaders;
    for (final ch in channels.take(8)) {
      final url = ch.streamUrl;
      if (url.contains('.m3u8')) {
        unawaited(
          HlsQualityService.prefetchPlaylistHead(url, headers: headers),
        );
      }
    }
  }

  // ── Gesture handlers ───────────────────────────────────

  void _onDoubleTapDown(TapDownDetails d) {
    final w = MediaQuery.of(context).size.width;
    final rewind = d.localPosition.dx < w / 2;
    _seek(rewind ? -10 : 10);
    _showSeekOverlay(rewind ? '⏪ 10s' : '10s ⏩', rewind);
  }

  void _showSeekOverlay(String label, bool leftSide) {
    setState(() {
      _seekOverlayLabel = label;
      _seekOverlayOpacity = 1.0;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 370), () {
      if (!mounted) return;
      setState(() => _seekOverlayOpacity = 0.0);
    });
    Timer(const Duration(milliseconds: 570), () {
      if (mounted) setState(() => _seekOverlayLabel = null);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    final vx = d.velocity.pixelsPerSecond.dx;
    if (vx.abs() <= 800) return;
    final now = DateTime.now();
    if (_lastSwipeAt != null &&
        now.difference(_lastSwipeAt!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastSwipeAt = now;
    final channels = _relatedDisplay;
    if (channels.isEmpty) return;
    var idx = channels.indexWhere(
      (c) =>
          c.name == _currentTitle ||
          (c.streamUrl.isNotEmpty && c.matchesStreamUrl(_currentUrl ?? '')),
    );
    if (idx < 0) idx = 0;
    final nextIdx = vx > 0
        ? (idx - 1 + channels.length) % channels.length
        : (idx + 1) % channels.length;
    final next = channels[nextIdx];
    agentDebugLog(
      location: 'player_screen.dart:_onHorizontalDragEnd',
      message: 'swipe channel change',
      hypothesisId: 'H-swipe',
      data: {
        'vx': vx,
        'fromIdx': idx,
        'toIdx': nextIdx,
        'channel': next.name,
      },
    );
    setState(() => _channelSwipeOverlay = next.name);
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _channelSwipeOverlay = null);
    });
    _scheduleChannelSwitch(next);
  }

  void _onRetryPressed() {
    final now = DateTime.now();
    if (_lastRetryAt != null &&
        now.difference(_lastRetryAt!) < const Duration(seconds: 2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait...'),
          duration: Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    _lastRetryAt = now;
    _failedLinks.clear();
    _failoverAttempts = 0;
    unawaited(_prepareLinksAndPlay());
  }

  void _onDragStart(DragStartDetails d) {
    final w = MediaQuery.of(context).size.width;
    _isDragging = true;
    _dragStartY = d.localPosition.dy;
    _draggingVolume = d.localPosition.dx > w / 2;
    _dragStartVal = _draggingVolume ? _volume : _brightness;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    final playerH = MediaQuery.of(context).size.width * 9 / 16;
    final delta = (_dragStartY - d.localPosition.dy) / playerH;
    final newVal = (_dragStartVal + delta).clamp(0.0, 1.0);
    setState(() {
      if (_draggingVolume) {
        _volume = newVal;
        _player.setVolume(_volume * 100);
      } else {
        _brightness = newVal;
        try {
          ScreenBrightness().setScreenBrightness(_brightness);
        } catch (_) {}
      }
      _indicatorOpacity = 1.0;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _indicatorOpacity = 0.0);
    });
  }

  void _onDragEnd(DragEndDetails _) => _isDragging = false;

  Future<void> _bindBackgroundPlayback() async {
    try {
      final handler = await ensureLumioAudioService();
      handler.attachPlayer(_player);
      handler.setNowPlaying(
        title: _currentTitle.isNotEmpty ? _currentTitle : widget.title,
        mediaId: _currentUrl,
      );
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_bindBackgroundPlayback',
        message: 'audio_service attached',
        hypothesisId: 'H2-audio-service',
        data: {'title': _currentTitle, 'hasUrl': _currentUrl != null},
      );
      // #endregion
    } catch (e) {
      // #region agent log
      _debugSessionLog(
        location: 'player_screen.dart:_bindBackgroundPlayback',
        message: 'audio_service attach failed',
        hypothesisId: 'H2-audio-service',
        data: {'err': e.toString()},
      );
      // #endregion
    }
  }

  void _syncBackgroundNowPlaying() {
    lumioAudioHandlerOrNull?.setNowPlaying(
      title: _currentTitle,
      mediaId: _currentUrl,
    );
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

  void _onPlayerPaused() {
    if (_pauseAdShown || !AdManager.instance.adsEnabled) return;
    if (_showVideoAdOverlay || _hasError || !_initialized) return;
    final started = _playbackStartedAt;
    if (started == null) return;
    if (DateTime.now().difference(started) <
        AdPlacementConfig.playerPauseAdMinPlayback) {
      return;
    }
    setState(() {
      _pauseAdVisible = true;
      _pauseAdShown = true;
    });
    unawaited(
      AdManager.instance.analytics.logImpression(
        network: 'adsterra',
        placement: 'pause_overlay',
      ),
    );
  }

  Future<void> _runPreRollThenPlay() async {
    AdManager.instance.setStreaming(true);
    final channelKey = widget.title.trim().isNotEmpty
        ? widget.title.trim()
        : (_currentUrl ?? 'player');
    AdTriggerManager.instance.onPlayerChannelStarted(channelKey);
    if (!mounted) return;
    if (_currentUrl != null && _currentUrl!.isNotEmpty) {
      await _prepareLinksAndPlay();
    }
    if (!mounted) return;
    if (AdManager.instance.adsEnabled) {
      await AdManager.instance.showPlacementInterstitial(
        context: context,
        placement: InterstitialPlacement.preroll,
        channelKey: channelKey,
      );
    }
    if (!mounted) return;
    _startMidRollTimer();
  }

  Future<void> _presentMidRollInterstitial() async {
    if (!mounted) return;
    try {
      await _player.pause();
    } catch (_) {}
    if (!mounted) return;
    await AdManager.instance.showMidRollInterstitial(context: context);
    if (!mounted) return;
    if (_initialized && !_hasError) {
      unawaited(_player.play());
    }
  }

  void _dismissPlayerVideoAd() {
    if (!mounted) return;
    setState(() => _showVideoAdOverlay = false);
    _videoAdCompleter?.complete();
    _videoAdCompleter = null;
    if (_initialized && !_hasError) {
      unawaited(_player.play());
    }
  }

  void _startMidRollTimer() {
    _midRollTimer?.cancel();
    if (!AdManager.instance.adsEnabled) return;
    _midRollTimer = Timer.periodic(
      AdPlacementConfig.playerMidRollPeriod,
      (_) {
        if (!mounted || _showVideoAdOverlay || _hasError || !_initialized) {
          return;
        }
        unawaited(_presentMidRollInterstitial());
      },
    );
  }

  // ── Lifecycle ──────────────────────────────────────────

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

  /// Minimal surface for Android PiP window (YouTube-style floating video).
  Widget _buildPipOnlyUi() {
    if (_hasError || (_currentUrl?.isEmpty ?? true)) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    if (!_initialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: PlayerSpinner()),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Video(
        controller: _videoCtrl,
        controls: NoVideoControls,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildFullPlayerUi(BuildContext context) {
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _exitFullscreen();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        body: Column(children: [
          _buildPlayer(context),
          if (_links.length > 1 && !_isFullscreen) _buildStreamLinkStrip(context),
          if (!_isFullscreen) Expanded(child: _buildInfo(context)),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // PLAYER AREA
  // ═══════════════════════════════════════════════════════

  Widget _buildPlayer(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final double playerH;
    if (_isFullscreen) {
      playerH = size.height;
    } else {
      final ideal = size.width * 9 / 16;
      final maxH = (size.height * 0.58).clamp(280.0, double.infinity);
      playerH = ideal.clamp(280.0, maxH);
    }
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTapDown: _onDoubleTapDown,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Container(
        width: double.infinity,
        height: playerH,
        color: Colors.black,
        child: Stack(children: [
          // ── Video surface ──
          if (_hasError || (_currentUrl?.isEmpty ?? true))
            Center(
              child: PlayerErrorPanel(
                message: (_currentUrl?.isEmpty ?? true)
                    ? 'Stream link নেই'
                    : 'Stream load হয়নি',
                onRetry: _onRetryPressed,
              ),
            )
          else if (!_initialized)
            _buildLoadingSkeleton()
          else
            Video(
              controller: _videoCtrl,
              controls: NoVideoControls,
              fit: _videoFit,
            ),

          // ── Buffering spinner ──
          ValueListenableBuilder<bool>(
            valueListenable: _bufferingVisible,
            builder: (context, buffering, _) {
              if (!buffering || _hasError || !_initialized) {
                return const SizedBox.shrink();
              }
              return const Center(child: PlayerSpinner());
            },
          ),

          if (_seekOverlayLabel != null && _seekOverlayOpacity > 0)
            _buildSeekOverlay(),

          if (_channelSwipeOverlay != null) _buildChannelSwipeOverlay(),

          // ── Controls overlay ──
          if (_showControls) ...[
            _buildTopBar(context),
            _buildControls(context),
          ],

          // ── Drag indicator ──
          if (_indicatorOpacity > 0) _buildDragIndicator(),

          // ── In-player video ad (YouTube-style skip after 10s) ──
          if (_showVideoAdOverlay)
            Positioned.fill(
              child: PlayerVideoAdOverlay(
                onDismiss: _dismissPlayerVideoAd,
              ),
            ),

          if (_pauseAdVisible &&
              !_isPlaying &&
              !_showVideoAdOverlay &&
              (AdConfig.hasAdsterraWebViewZones || MonetagConfig.isConfigured))
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _pauseAdVisible = false),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: AdConfig.playerAdsUserVisible ? 0.72 : 0,
                  ),
                  child: Center(
                    child: AdsterraNativeBanner(
                      placement: 'pause_overlay',
                      height: 200,
                      userVisible: AdConfig.playerAdsUserVisible,
                    ),
                  ),
                ),
              ),
            ),

          if (AdPlacementConfig.showPlayerStickySocialBar &&
              AdManager.instance.adsEnabled &&
              _playbackSurfaceReady &&
              !_showVideoAdOverlay &&
              _isPlaying)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: RepaintBoundary(
                child: PlayerStickyAdStrip(key: _stickyAdKey),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────

  Widget _playerOverlayChip({
    required Widget child,
    Color fill = const Color(0x99000000),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          left: 4,
          right: 8,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.black.withValues(alpha: 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () =>
                  _isFullscreen ? _exitFullscreen() : Navigator.pop(context),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTitle,
                    style: GF.head(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Text(
                      widget.subtitle,
                      style: GF.body(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (_pipAvailable)
              IconButton(
                icon: Icon(Icons.picture_in_picture_alt_rounded,
                    color: Colors.white.withValues(alpha: 0.85), size: 22),
                tooltip: 'Mini player',
                onPressed: _enterPipNow,
              ),
            IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: Colors.white.withValues(alpha: 0.9), size: 22),
              tooltip: 'Quality',
              onPressed: () => _showQualityDialog(context),
            ),
            if (_qualityBadge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _playerOverlayChip(
                  child: Text(
                    _qualityBadge,
                    style: GF.body(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            _playerOverlayChip(
              fill: AppColors.accent.withValues(alpha: 0.92),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PlayerLiveDot(),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: GF.head(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final prov = context.read<AppProvider>();
    final ch = prov.channelForStream(_currentUrl ?? '') ??
        prov.findChannel(name: _currentTitle);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ch != null)
            ChannelAvatar(channel: ch, size: 56)
          else
            Icon(
              Icons.live_tv_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          const SizedBox(height: 14),
          Text(
            _currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting to stream...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          PlayerConnectingDots(),
        ],
      ),
    );
  }

  Widget _buildSeekOverlay() {
    final isRewind = _seekOverlayLabel?.startsWith('⏪') ?? false;
    return Positioned(
      left: isRewind ? 24 : null,
      right: isRewind ? null : 24,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _seekOverlayOpacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Text(
              _seekOverlayLabel ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChannelSwipeOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _channelSwipeOverlay ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Horizontal link chips below the player (always visible when 2+ links).
  Widget _buildStreamLinkStrip(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0C),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _links.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final link = _links[i];
            final active = i == _activeLinkIndex;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _switchToLink(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minWidth: 88, maxWidth: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.accent
                        : const Color(0xFF14141A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? AppColors.accent
                          : const Color(0xFF252530),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    link.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GF.body(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Bottom controls (same layout in normal + fullscreen) ──

  Widget _buildControls(BuildContext context) {
    final isPlaying = _player.state.playing;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPad),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.92),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProgressTimeRow(),
            const SizedBox(height: 10),
            Row(
              children: [
                PlayerTransportBtn(
                  icon: _videoFit == BoxFit.cover
                      ? Icons.crop_free_rounded
                      : Icons.fit_screen_rounded,
                  tooltip: _videoFit == BoxFit.cover ? 'Fit screen' : 'Fill',
                  onTap: _toggleFill,
                ),
                PlayerTransportBtn(
                  icon: Icons.replay_10_rounded,
                  onTap: () => _seek(-10),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                PlayerTransportBtn(
                  icon: Icons.forward_10_rounded,
                  onTap: () => _seek(10),
                ),
                PlayerTransportBtn(
                  icon: _isFullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  onTap: () {
                    _toggleFullscreen();
                    _revealControls();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTimeRow() {
    return StreamBuilder<Duration>(
      stream: _player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = _player.state.duration;
        final isLive = dur.inMilliseconds <= 0;
        final progress = isLive
            ? null
            : (dur.inMilliseconds > 0
                ? _safeUnitProgress(
                    pos.inMilliseconds / dur.inMilliseconds,
                  )
                : 0.0);
        final sliderValue = _safeUnitProgress(_scrubValue ?? progress ?? 0.0);

        return Column(
          children: [
            if (!isLive && dur.inMilliseconds > 0)
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.22),
                  thumbColor: AppColors.accent,
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: sliderValue,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) =>
                      setState(() => _scrubValue = _safeUnitProgress(v)),
                  onChangeEnd: (v) {
                    final safe = _safeUnitProgress(v);
                    final maxMs =
                        dur.inMilliseconds.toDouble().clamp(1.0, double.infinity);
                    final targetMs = (safe * maxMs).round().clamp(0, dur.inMilliseconds);
                    _player.seek(Duration(milliseconds: targetMs));
                    setState(() => _scrubValue = null);
                  },
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress != null ? _safeUnitProgress(progress) : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  minHeight: 3,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  _formatDuration(pos),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Text(
                  isLive ? '● LIVE' : _formatDuration(dur),
                  style: TextStyle(
                    color: isLive
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  // ── Drag indicator ─────────────────────────────────────

  Widget _buildDragIndicator() {
    final val = _draggingVolume ? _volume : _brightness;
    final icon = _draggingVolume
        ? (val == 0
            ? Icons.volume_off
            : val < 0.5
                ? Icons.volume_down
                : Icons.volume_up)
        : (val < 0.3
            ? Icons.brightness_low
            : val < 0.7
                ? Icons.brightness_medium
                : Icons.brightness_high);
    final color = _draggingVolume
        ? AppColors.accent
        : Colors.yellow.withValues(alpha: 0.9);

    return Positioned(
      top: 0,
      bottom: 0,
      left: _draggingVolume ? null : 20,
      right: _draggingVolume ? 20 : null,
      child: Center(
        child: AnimatedOpacity(
          opacity: _indicatorOpacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 4,
                  height: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: val,
                      child: Container(color: color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(val * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // INFO / RELATED PANEL (portrait only)
  // ═══════════════════════════════════════════════════════

  Widget _buildInfo(BuildContext context) {
    final prov = context.read<AppProvider>();
    final displayChannels = _relatedDisplay.isNotEmpty
        ? _relatedDisplay
        : (widget.relatedChannels ?? _defaultChannelsForCategory());
    final relatedTitle = AppProvider.relatedSectionLabel(_relatedCategory);

    return Container(
      color: const Color(0xFF0C0C0E),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification) {
            _prefetchVisibleChannelPlaylists(displayChannels);
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          children: [
        // ── Now playing card ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF16161E), Color(0xFF101014)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A36)),
          ),
          child: Row(children: [
            Builder(
              builder: (ctx) {
                final ch = prov.channelForStream(_currentUrl ?? '') ??
                    prov.findChannel(name: _currentTitle);
                if (ch != null) {
                  return ChannelAvatar(channel: ch, size: 52);
                }
                return Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      categoryEmoji(widget.category),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentTitle,
                    style: GF.head(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Text(
                      widget.subtitle,
                      style: GF.body(
                        color: AppColors.txt2Dark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PlayerLiveDot(),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: GF.head(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _initialized
                      ? 'Now playing'
                      : _hasError
                          ? 'Unavailable'
                          : 'Connecting…',
                  style: GF.body(
                    color: _initialized
                        ? AppColors.green
                        : _hasError
                            ? AppColors.red
                            : AppColors.txt3Dark,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 12),
        const PlayerAdSlot(),

        // ── Related channels header ──
        Text(
          relatedTitle,
          style: GF.head(
            color: AppColors.txt3Dark,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 12),

        // ── Related channel cards ──
        ...displayChannels.map((ch) => PlayerRelatedCard(
              channel: ch,
              isPlaying: _currentUrl == ch.streamUrl,
              onTap: () => _scheduleChannelSwitch(ch),
            )),

        const SizedBox(height: 20),
      ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // QUALITY DIALOG (parsed from #EXT-X-STREAM-INF)
  // ═══════════════════════════════════════════════════════

  List<({String label, int targetHeight, String? hint})> _parsedQualityChoices() {
    return const [
      (label: 'Auto', targetHeight: 0, hint: 'Adaptive'),
      (label: '180p', targetHeight: 180, hint: null),
      (label: '270p', targetHeight: 270, hint: null),
      (label: '360p', targetHeight: 360, hint: '704×396 · ~0.35 Mbps'),
      (label: '480p', targetHeight: 480, hint: null),
      (label: '540p', targetHeight: 540, hint: '960×540 · ~0.70 Mbps'),
      (label: '720p', targetHeight: 720, hint: null),
      (label: '1080p', targetHeight: 1080, hint: '1920×1080 · ~8.20 Mbps'),
    ];
  }

  IconData _qualityIconFor(String label) {
    if (label == 'Auto') return Icons.auto_awesome_rounded;
    final h = int.tryParse(label.replaceAll('p', '')) ?? 0;
    if (h >= 1080) return Icons.hd_rounded;
    if (h >= 720) return Icons.high_quality_rounded;
    return Icons.sd_rounded;
  }

  Widget _qualityOptionTile({
    required BuildContext ctx,
    required String label,
    required int targetHeight,
    required String? hint,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : const Color(0xFF232A38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.65)
                  : const Color(0xFF2E3648),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accent.withValues(alpha: 0.22)
                      : const Color(0xFF1A1F2B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _qualityIconFor(label),
                  size: 22,
                  color: selected ? AppColors.accent : Colors.white54,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 15,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hint != null && hint.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? AppColors.accent : Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQualityDialog(BuildContext context) {
    _revealControls(restartTimer: false);
    if (_hlsVariants.isEmpty) {
      unawaited(_reloadMasterVariants());
    }
    final choices = _parsedQualityChoices();
    var pickHeight = _selectedTargetHeight;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final size = MediaQuery.sizeOf(ctx);
          final isLandscape = size.width > size.height;
          final dialogW = (size.width - 44).clamp(280.0, 400.0);
          // Landscape: height is the short edge — cap dialog to that edge, not list+header sum.
          final dialogH = isLandscape
              ? (size.height * 0.92).clamp(200.0, 380.0)
              : (size.height * 0.72).clamp(320.0, 560.0);
          // #region agent log
          _debugSessionLog(
            location: 'player_screen.dart:_showQualityDialog',
            message: 'quality dialog layout',
            hypothesisId: 'H-quality-overflow',
            data: {
              'viewW': size.width,
              'viewH': size.height,
              'isLandscape': isLandscape,
              'dialogW': dialogW,
              'dialogH': dialogH,
              'choiceCount': choices.length,
            },
          );
          // #endregion

          return Dialog(
            backgroundColor: const Color(0xFF1A1F2B),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 28 : 22,
              vertical: isLandscape ? 12 : 28,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SizedBox(
              width: dialogW,
              height: dialogH,
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      isLandscape ? 12 : 18,
                      12,
                      isLandscape ? 8 : 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stream Quality',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose playback resolution',
                                style: TextStyle(
                                  color: Color(0xFF8A94A8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      itemCount: choices.length,
                      separatorBuilder: (_, i) => i == 0
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: Text(
                                      'MANUAL',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final c = choices[i];
                        final selected = pickHeight == c.targetHeight;
                        return _qualityOptionTile(
                          ctx: ctx,
                          label: c.label,
                          targetHeight: c.targetHeight,
                          hint: c.hint,
                          selected: selected,
                          onTap: () =>
                              setDialog(() => pickHeight = c.targetHeight),
                        );
                      },
                    ),
                  ),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      isLandscape ? 8 : 10,
                      14,
                      isLandscape ? 10 : 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () async {
                              final choice = choices.firstWhere(
                                (c) => c.targetHeight == pickHeight,
                                orElse: () => choices.first,
                              );
                              Navigator.pop(dialogCtx);
                              await _applyQuality(
                                choice.label,
                                choice.targetHeight,
                              );
                              if (mounted) _revealControls();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<VideoTrack> get _selectableVideoTracks {
    return _player.state.tracks.video.where((t) => (t.h ?? 0) > 0).toList();
  }

  int _trackHeight(VideoTrack t) => t.h ?? 0;

  bool _heightMatchesTarget(int h, int targetH) =>
      h > 0 && (h == targetH || (h - targetH).abs() <= 24);

  /// Force user cap: exact → near match → highest ≤ target → lowest available.
  VideoTrack? _findTrackForced(int targetH, List<VideoTrack> tracks) {
    if (tracks.isEmpty) return null;

    for (final t in tracks) {
      if (_heightMatchesTarget(_trackHeight(t), targetH)) return t;
    }

    VideoTrack? bestAtMost;
    var bestH = -1;
    for (final t in tracks) {
      final h = _trackHeight(t);
      if (h > 0 && h <= targetH && h > bestH) {
        bestH = h;
        bestAtMost = t;
      }
    }
    if (bestAtMost != null) return bestAtMost;

    VideoTrack? lowest;
    var minH = 99999;
    for (final t in tracks) {
      final h = _trackHeight(t);
      if (h > 0 && h < minH) {
        minH = h;
        lowest = t;
      }
    }
    return lowest;
  }

  Future<void> _applyQuality(String label, int targetH) async {
    if (!mounted || _applyingQuality) return;
    _applyingQuality = true;
    final sw = Stopwatch()..start();
    var applyPath = 'unknown';
    try {
      setState(() {
        _selectedQuality = label;
        _selectedTargetHeight = targetH;
        if (label != 'Auto') _qualityBadge = label;
      });
      unawaited(_persistQualityPref(targetH));

      // #region agent log
      agentDebugLog(
        location: 'player_screen.dart:_applyQuality',
        message: 'quality apply start',
        hypothesisId: 'H-quality',
        data: {
          'label': label,
          'targetH': targetH,
          'hlsVariantCount': _hlsVariants.length,
          'videoTrackCount': _player.state.tracks.video.length,
          'selectableTrackCount': _selectableVideoTracks.length,
          'currentUrlTail': _currentUrl?.split('/').last ?? '',
          'masterUrlTail': _masterUrl.split('/').last,
        },
      );
      // #endregion

      if (label == 'Auto') {
        applyPath = 'auto';
        _userOverrideQuality = false;
        _pendingTargetHeight = null;
        if (_currentUrl != _masterUrl) {
          await _openStreamUrl(_masterUrl, _activeHeaders);
          if (mounted) setState(() => _currentUrl = _masterUrl);
        }
        await _player.setVideoTrack(VideoTrack.auto());
        if (_lastMpvCapHeight != null) {
          await _applyMpvHeightCap(null);
        }
        _updateQualityBadge();
        unawaited(_runInitialBandwidthSample());
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'quality apply done',
          hypothesisId: 'H-quality-speed',
          data: {'path': applyPath, 'elapsedMs': sw.elapsedMilliseconds},
        );
        // #endregion
        return;
      }

      _userOverrideQuality = true;
      _pendingTargetHeight = targetH;

      final selectable = _selectableVideoTracks;
      final allVideoTracks = _player.state.tracks.video;
      final tracks = selectable.isNotEmpty ? selectable : allVideoTracks;

      final forcedVariant = _hlsVariants.isNotEmpty
          ? HlsQualityService.pickVariantForced(_hlsVariants, targetH)
          : null;
      final forcedTrack =
          tracks.isNotEmpty ? _findTrackForced(targetH, tracks) : null;

      var tier1Ok = false;
      var tier2Ok = false;

      // Fast path: switch HLS rendition inside the same player (no full reload).
      if (forcedTrack != null) {
        applyPath = 'track';
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'tier2 setVideoTrack',
          hypothesisId: 'H5-smooth-quality',
          data: {
            'targetH': targetH,
            'trackH': forcedTrack.h,
            'onMaster': _currentUrl == _masterUrl,
          },
        );
        // #endregion
        await _player.setVideoTrack(forcedTrack);
        tier2Ok = true;
        if (_lastMpvCapHeight != null) {
          await _applyMpvHeightCap(null);
        }
        agentDebugLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'tier2 media_kit track',
          hypothesisId: 'H-tier2',
          data: {'trackH': forcedTrack.h, 'trackW': forcedTrack.w},
        );
      } else if (forcedVariant != null && forcedVariant.url != _currentUrl) {
        applyPath = 'url_reopen';
        await _openStreamUrl(forcedVariant.url, _activeHeaders);
        if (mounted) {
          setState(() => _currentUrl = forcedVariant.url);
          tier1Ok = true;
        }
        agentDebugLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'tier1 HLS rendition',
          hypothesisId: 'H-tier1',
          data: {
            'urlTail': forcedVariant.url.split('/').last,
            'height': forcedVariant.height,
          },
        );
      }

      if (!tier2Ok) {
        if (tier1Ok) {
          applyPath = '$applyPath+vf';
          await _applyMpvHeightCap(targetH);
        } else {
          applyPath = 'vf_debounced';
          _scheduleMpvHeightCap(targetH);
        }
        agentDebugLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'tier3 MPV vf scheduled/applied',
          hypothesisId: 'H-tier3',
          data: {
            'targetH': targetH,
            'tier1': tier1Ok,
            'tier2': tier2Ok,
            'debounced': !tier1Ok,
            'sourceHeight': _sourceHeight,
          },
        );
      }

      _pendingTargetHeight = null;
    } finally {
      _applyingQuality = false;
      if (mounted) {
        _updateQualityBadge();
        setState(() {});
        // #region agent log
        _debugSessionLog(
          location: 'player_screen.dart:_applyQuality',
          message: 'quality apply done',
          hypothesisId: 'H-quality-speed',
          data: {
            'path': applyPath,
            'elapsedMs': sw.elapsedMilliseconds,
            'selectedQuality': _selectedQuality,
            'selectedTargetHeight': _selectedTargetHeight,
            'qualityBadge': _qualityBadge,
          },
        );
        // #endregion
      }
    }
  }

  List<ChannelModel> _defaultChannelsForCategory() {
    if (_relatedCategory == 'Sports') {
      return _defaultSportsChannels;
    }
    if (_relatedCategory == 'Bangladesh' || _relatedCategory == 'Bangla') {
      return _defaultBanglaChannels;
    }
    return _defaultSportsChannels;
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

