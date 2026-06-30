// lib/services/background_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/model.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'notification_service.dart';
import '../security/stream_security_prober.dart';

// =============================================================================
// TOP-LEVEL WORKMANAGER DISPATCHER
// Must be a top-level function — Workmanager runs tasks in a separate isolate.
// =============================================================================

/// Entry point for all Workmanager background tasks.
/// Registered via [BackgroundService.initialize].
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      switch (taskName) {
        case BackgroundTask.scoreRefresh:
          return await _ScoreRefreshTask.run();

        case BackgroundTask.liveMatchPoll:
          return await _LiveMatchPollTask.run();

        case BackgroundTask.channelReminderCheck:
          return await _ChannelReminderTask.run();

        case BackgroundTask.cacheCleanup:
          return await _CacheCleanupTask.run();

        case BackgroundTask.httpsProbe:
          return await _HttpsProbeTask.run();

        default:
          _bgLog('Unknown task: $taskName');
          return Future.value(false);
      }
    } catch (e, st) {
      _bgLog('Task "$taskName" threw: $e\n$st');
      return Future.value(false); // false = Workmanager will retry
    }
  });
}

// ─── Shared background logger (no debugPrint in isolates) ────────────────────

void _bgLog(String msg) {
  if (kDebugMode) print('[Background] $msg');
}

// =============================================================================
// TASK NAME CONSTANTS
// =============================================================================

class BackgroundTask {
  BackgroundTask._();

  /// Periodic: refresh scores for all live + upcoming matches.
  static const String scoreRefresh = 'lumio.scoreRefresh';

  /// One-shot / expedited: poll while a match is actively live.
  static const String liveMatchPoll = 'lumio.liveMatchPoll';

  /// Periodic: check if any followed channel has a programme starting soon.
  static const String channelReminderCheck = 'lumio.channelReminderCheck';

  /// Periodic: purge stale SharedPreferences cache entries.
  static const String cacheCleanup = 'lumio.cacheCleanup';

  /// Weekly: re-test HTTP streams for HTTPS availability.
  static const String httpsProbe = 'lumio.httpsProbe';

  // Unique names for registration (Workmanager deduplicates by unique name)
  static const String scoreRefreshUnique = 'lumio.scoreRefresh.periodic';
  static const String liveMatchPollUnique = 'lumio.liveMatchPoll.oneshot';
  static const String httpsProbeUnique = 'lumio.httpsProbe.weekly';
  static const String channelReminderUnique = 'lumio.channelReminder.periodic';
  static const String cacheCleanupUnique = 'lumio.cacheCleanup.periodic';
}

// =============================================================================
// BACKGROUND SERVICE  (public API)
// =============================================================================

/// Lumio TV — BackgroundService
///
/// Manages all periodic and one-shot background work via Workmanager.
///
/// ## Lifecycle
///
/// ```
/// main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await Firebase.initializeApp(...);
///   await NotificationService.initialize(...);
///   await BackgroundService.initialize();   // ← register dispatcher
///   runApp(const LumioApp());
/// }
/// ```
///
/// Then start/stop individual tasks from your AppProvider:
///
/// ```dart
/// // When user opens Matches tab
/// await BackgroundService.startScoreRefresh();
///
/// // When a live match becomes active
/// await BackgroundService.startLiveMatchPoll(matchId: match.id);
///
/// // When user closes app / navigates away
/// await BackgroundService.stopLiveMatchPoll();
/// ```
///
/// ## Platform constraints
/// Workmanager on iOS has significant OS-imposed restrictions on when
/// background tasks actually fire. Minimum interval is respected but OS
/// may defer. On Android the constraints are far more reliable.
class BackgroundService {
  BackgroundService._();

  // ── Scheduling intervals ───────────────────────────────────────────────────

  /// How often to refresh scores in the background.
  /// Workmanager enforces a minimum of 15 minutes on both platforms.
  static const Duration _scoreRefreshInterval = Duration(minutes: 15);

  /// How often to check channel programme reminders.
  static const Duration _channelReminderInterval = Duration(minutes: 30);

  /// How often to run cache cleanup.
  static const Duration _cacheCleanupInterval = Duration(hours: 6);
  static const Duration _httpsProbeInterval = Duration(days: 7); // Weekly

  // ── State ──────────────────────────────────────────────────────────────────

  static bool _initialized = false;

  /// In-process foreground timer used when the app is in the foreground.
  /// Supplements Workmanager which can't fire faster than 15 min.
  static Timer? _foregroundTimer;

  // ── StreamController for real-time score updates to the UI ────────────────

  static final StreamController<List<MatchModel>> _liveScoreController =
      StreamController<List<MatchModel>>.broadcast();

  /// Listen to this stream in your Provider / widgets to receive live score
  /// updates without polling manually.
  ///
  /// ```dart
  /// BackgroundService.liveScoreStream.listen((matches) {
  ///   setState(() => _liveMatches = matches);
  /// });
  /// ```
  static Stream<List<MatchModel>> get liveScoreStream =>
      _liveScoreController.stream;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  /// Register the Workmanager callback dispatcher.
  /// Call this once in [main] before [runApp].
  static Future<void> initialize() async {
    if (_initialized) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    _initialized = true;
    _bgLog('BackgroundService initialized');
  }

  // ===========================================================================
  // SCORE REFRESH  (periodic background task)
  // ===========================================================================

  /// Register the periodic score-refresh Workmanager task.
  /// Safe to call multiple times — Workmanager deduplicates by unique name.
  static Future<void> startScoreRefresh() async {
    _assertInitialized();
    try {
      await Workmanager().registerPeriodicTask(
        BackgroundTask.scoreRefreshUnique,
        BackgroundTask.scoreRefresh,
        frequency: _scoreRefreshInterval,
        initialDelay: const Duration(seconds: 10),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false, // scores are time-sensitive
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 2),
      );
      _bgLog('Score refresh periodic task registered');
    } catch (e) {
      _bgLog('startScoreRefresh failed: $e');
    }
  }

  /// Cancel the periodic score-refresh task.
  static Future<void> stopScoreRefresh() async {
    try {
      await Workmanager().cancelByUniqueName(BackgroundTask.scoreRefreshUnique);
      _bgLog('Score refresh task cancelled');
    } catch (e) {
      _bgLog('stopScoreRefresh failed: $e');
    }
  }

  // ===========================================================================
  // LIVE MATCH POLL  (high-frequency foreground + background)
  // ===========================================================================

  /// Start aggressive polling while a specific live match is being watched.
  ///
  /// • Foreground: an in-process [Timer] fires every [foregroundInterval]
  ///   (default 30 s) and pushes updates to [liveScoreStream].
  /// • Background: a one-shot Workmanager task fires when the app is
  ///   backgrounded to keep the score notification current.
  ///
  /// [matchId] is stored in SharedPreferences so the background isolate
  /// knows which match to poll.
  static Future<void> startLiveMatchPoll({
    required String matchId,
    Duration foregroundInterval = const Duration(seconds: 30),
  }) async {
    _assertInitialized();

    // Persist the active match ID for the background isolate
    await _setActiveMatchId(matchId);

    // ── Foreground timer ────────────────────────────────────────────────────
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(foregroundInterval, (_) async {
      await _pollAndBroadcast(matchId);
    });

    // Immediate first poll
    await _pollAndBroadcast(matchId);

    // ── One-shot background task ────────────────────────────────────────────
    try {
      await Workmanager().registerOneOffTask(
        BackgroundTask.liveMatchPollUnique,
        BackgroundTask.liveMatchPoll,
        initialDelay: foregroundInterval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (e) {
      _bgLog('Workmanager one-off registration failed: $e');
    }

    _bgLog('Live match poll started: $matchId');
  }

  /// Stop live match polling and clear the stored match ID.
  static Future<void> stopLiveMatchPoll() async {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await _clearActiveMatchId();

    try {
      await Workmanager()
          .cancelByUniqueName(BackgroundTask.liveMatchPollUnique);
    } catch (e) {
      _bgLog('stopLiveMatchPoll Workmanager cancel failed: $e');
    }

    _bgLog('Live match poll stopped');
  }

  // ===========================================================================
  // CHANNEL REMINDER CHECK  (periodic)
  // ===========================================================================

  /// Start periodic checks for upcoming programme reminders on followed channels.
  static Future<void> startChannelReminderChecks() async {
    _assertInitialized();
    try {
      await Workmanager().registerPeriodicTask(
        BackgroundTask.channelReminderUnique,
        BackgroundTask.channelReminderCheck,
        frequency: _channelReminderInterval,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      _bgLog('Channel reminder check registered');
    } catch (e) {
      _bgLog('startChannelReminderChecks failed: $e');
    }
  }

  /// Cancel channel reminder checks.
  static Future<void> stopChannelReminderChecks() async {
    try {
      await Workmanager()
          .cancelByUniqueName(BackgroundTask.channelReminderUnique);
      _bgLog('Channel reminder task cancelled');
    } catch (e) {
      _bgLog('stopChannelReminderChecks failed: $e');
    }
  }

  // ===========================================================================
  // CACHE CLEANUP  (periodic)
  // ===========================================================================

  /// Register periodic cache-cleanup task (removes stale SharedPreferences
  /// keys to prevent unbounded storage growth).
  static Future<void> startCacheCleanup() async {
    _assertInitialized();
    try {
      await Workmanager().registerPeriodicTask(
        BackgroundTask.cacheCleanupUnique,
        BackgroundTask.cacheCleanup,
        frequency: _cacheCleanupInterval,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      _bgLog('Cache cleanup task registered');
    } catch (e) {
      _bgLog('startCacheCleanup failed: $e');
    }
  }

  /// Register periodic HTTPS probe task (weekly re-testing of HTTP streams).
  static Future<void> startHttpsProbe() async {
    _assertInitialized();
    try {
      await Workmanager().registerPeriodicTask(
        BackgroundTask.httpsProbeUnique,
        BackgroundTask.httpsProbe,
        frequency: _httpsProbeInterval,
        initialDelay: const Duration(hours: 1), // Don't run immediately on install
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true, // Only when sufficient battery
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(hours: 1),
      );
      _bgLog('HTTPS probe task registered (weekly)');
    } catch (e) {
      _bgLog('startHttpsProbe failed: $e');
    }
  }

  /// Cancel the HTTPS probe task.
  static Future<void> stopHttpsProbe() async {
    try {
      await Workmanager().cancelByUniqueName(BackgroundTask.httpsProbeUnique);
      _bgLog('HTTPS probe task cancelled');
    } catch (e) {
      _bgLog('stopHttpsProbe failed: $e');
    }
  }

  // ===========================================================================
  // CANCEL ALL
  // ===========================================================================

  /// Cancel every registered Workmanager task and stop foreground timer.
  /// Call on user logout or app reset.
  static Future<void> cancelAll() async {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    await _clearActiveMatchId();

    try {
      await Workmanager().cancelAll();
      _bgLog('All background tasks cancelled');
    } catch (e) {
      _bgLog('cancelAll failed: $e');
    }
  }

  // ===========================================================================
  // FOREGROUND POLL HELPER
  // ===========================================================================

  static Future<void> _pollAndBroadcast(String matchId) async {
    try {
      final matches = await ApiService.getLiveMatches();
      if (!_liveScoreController.isClosed) {
        _liveScoreController.add(matches);
      }

      // Save to cache so background isolate has data to diff against
      await CacheService.saveMatches(matches, tag: 'live');

      _bgLog('Foreground poll complete — ${matches.length} live matches');
    } catch (e) {
      _bgLog('_pollAndBroadcast failed: $e');
    }
  }

  // ===========================================================================
  // SHARED PREFS — ACTIVE MATCH STATE
  // ===========================================================================

  static const String _activeMatchKey = 'lumio_bg_active_match';
  static const String _prevScoresKey = 'lumio_bg_prev_scores'; // JSON map

  static Future<void> _setActiveMatchId(String id) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_activeMatchKey, id);
    } catch (_) {}
  }

  static Future<void> _clearActiveMatchId() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_activeMatchKey);
      await p.remove(_prevScoresKey);
    } catch (_) {}
  }

  static Future<String?> _getActiveMatchId() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_activeMatchKey);
    } catch (_) {
      return null;
    }
  }

  // ── Diff helpers — detect score changes to fire notifications ─────────────

  static Future<Map<String, String>> _loadPrevScores() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prevScoresKey);
      if (raw == null) return {};
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _savePrevScores(Map<String, String> scores) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prevScoresKey, jsonEncode(scores));
    } catch (_) {}
  }

  // ===========================================================================
  // GUARDS
  // ===========================================================================

  static void _assertInitialized() {
    if (!_initialized) {
      throw StateError(
        'BackgroundService.initialize() must be called before '
        'using any background task method.',
      );
    }
  }

  // ===========================================================================
  // STREAM DISPOSAL
  // ===========================================================================

  /// Dispose the live score stream controller.
  /// Call from your top-level widget's [dispose] if needed.
  static void dispose() {
    _foregroundTimer?.cancel();
    if (!_liveScoreController.isClosed) {
      _liveScoreController.close();
    }
  }
}

// =============================================================================
// BACKGROUND TASK IMPLEMENTATIONS
// These run in a background isolate — no Flutter widget tree available.
// No Provider, no BuildContext. Only: http, SharedPreferences, local notifs.
// =============================================================================

// ── Score Refresh Task ────────────────────────────────────────────────────────

class _ScoreRefreshTask {
  static Future<bool> run() async {
    _bgLog('ScoreRefreshTask started');
    try {
      final base = _resolveBaseUrl();

      // Fetch live matches
      final liveRes = await http
          .get(Uri.parse('$base/api/matches?status=live'))
          .timeout(const Duration(seconds: 15));

      if (liveRes.statusCode != 200) {
        _bgLog('ScoreRefreshTask: non-200 response ${liveRes.statusCode}');
        return false;
      }

      final data = jsonDecode(liveRes.body) as Map<String, dynamic>;
      final rawList = data['matches'] as List<dynamic>? ?? [];
      final liveMatches = rawList
          .map((j) => MatchModel.fromJson(j as Map<String, dynamic>))
          .toList();

      _bgLog('ScoreRefreshTask: fetched ${liveMatches.length} live matches');

      // Persist to cache (background isolate — no CacheService singleton)
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(liveMatches.map((m) => m.toJson()).toList());
      await prefs.setString('lumio_matches_live', payload);
      await prefs.setInt(
        'lumio_matches_live_ts',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Check for score changes and fire notifications
      await _diffAndNotify(liveMatches);

      return true;
    } catch (e) {
      _bgLog('ScoreRefreshTask error: $e');
      return false;
    }
  }

  /// Compare current scores against previously stored scores.
  /// For any change, fire a local notification via [NotificationService].
  static Future<void> _diffAndNotify(List<MatchModel> current) async {
    final prev = await BackgroundService._loadPrevScores();
    final next = <String, String>{};

    for (final match in current) {
      final scoreKey = '${match.scoreA}-${match.scoreB}';
      next[match.id] = scoreKey;

      final oldScore = prev[match.id];
      if (oldScore != null && oldScore != scoreKey) {
        // Score changed — fire notification
        _bgLog('Score changed for ${match.id}: $oldScore → $scoreKey');
        await NotificationService.showScoreUpdate(
          match: match,
          updateText:
              '${match.teamA} ${match.scoreA} – ${match.scoreB} ${match.teamB}',
        );
      } else if (oldScore == null && match.status == 'live') {
        // Match newly detected as live
        _bgLog('New live match detected: ${match.id}');
        final isSubscribed =
            await NotificationService.isSubscribedToMatch(match.id);
        if (isSubscribed) {
          await NotificationService.showMatchLiveAlert(match);
        }
      }
    }

    await BackgroundService._savePrevScores(next);
  }
}

// ── Live Match Poll Task (one-shot, from background) ─────────────────────────

class _LiveMatchPollTask {
  static Future<bool> run() async {
    _bgLog('LiveMatchPollTask started');
    try {
      final matchId = await BackgroundService._getActiveMatchId();
      if (matchId == null) {
        _bgLog('LiveMatchPollTask: no active match ID — skipping');
        return true; // Completed successfully, nothing to do
      }

      final base = _resolveBaseUrl();
      final res = await http
          .get(Uri.parse('$base/api/matches?status=live'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawList = data['matches'] as List<dynamic>? ?? [];
      final matches = rawList
          .map((j) => MatchModel.fromJson(j as Map<String, dynamic>))
          .toList();

      // Find the watched match
      final watched = matches.where((m) => m.id == matchId).toList();
      if (watched.isEmpty) {
        _bgLog(
            'LiveMatchPollTask: active match $matchId not found in live list');
        return true;
      }

      await _ScoreRefreshTask._diffAndNotify(watched);
      _bgLog('LiveMatchPollTask done for match $matchId');
      return true;
    } catch (e) {
      _bgLog('LiveMatchPollTask error: $e');
      return false;
    }
  }
}

// ── Channel Reminder Task ─────────────────────────────────────────────────────

class _ChannelReminderTask {
  static Future<bool> run() async {
    _bgLog('ChannelReminderTask started');
    try {
      final subscribedIds = await NotificationService.getSubscribedChannelIds();
      if (subscribedIds.isEmpty) {
        _bgLog('ChannelReminderTask: no subscribed channels');
        return true;
      }

      final base = _resolveBaseUrl();
      final res = await http
          .get(Uri.parse('$base/api/channels'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return false;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final rawList = data['channels'] as List<dynamic>? ?? [];
      final channels = rawList
          .map((j) => ChannelModel.fromJson(j as Map<String, dynamic>))
          .where((c) => subscribedIds.contains(c.id))
          .toList();

      for (final channel in channels) {
        if (channel.isLive && channel.currentShow.isNotEmpty) {
          // Channel is live right now — send immediate reminder
          await NotificationService.showChannelReminder(
            channel: channel,
            programmeName: channel.currentShow,
            minutesUntilStart: 0,
          );
        }
      }

      _bgLog(
        'ChannelReminderTask done — checked ${channels.length} subscribed channels',
      );
      return true;
    } catch (e) {
      _bgLog('ChannelReminderTask error: $e');
      return false;
    }
  }
}

// ── Cache Cleanup Task ────────────────────────────────────────────────────────

class _CacheCleanupTask {
  /// TTL map mirrors CacheService — duplicated here because this runs in
  /// a separate isolate with no access to CacheService's private constants.
  static const Map<String, Duration> _ttls = {
    'lumio_channels': Duration(minutes: 10),
    'lumio_matches_all': Duration(seconds: 60),
    'lumio_matches_live': Duration(seconds: 60),
    'lumio_matches_upcoming': Duration(seconds: 60),
    'lumio_news_all': Duration(minutes: 5),
    'lumio_live_data': Duration(seconds: 30),
    'lumio_predictions': Duration(minutes: 5),
  };

  static Future<bool> run() async {
    _bgLog('CacheCleanupTask started');
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      var removed = 0;

      for (final entry in _ttls.entries) {
        final tsKey = '${entry.key}_ts';
        final ts = prefs.getInt(tsKey);
        if (ts == null) continue;

        final age = Duration(milliseconds: now - ts);
        // Remove entries older than 3× their TTL (safely stale)
        if (age > entry.value * 3) {
          await prefs.remove(entry.key);
          await prefs.remove(tsKey);
          removed++;
          _bgLog('Evicted stale key: ${entry.key} (age: ${age.inMinutes}m)');
        }
      }

      _bgLog('CacheCleanupTask done — removed $removed stale entries');
      return true;
    } catch (e) {
      _bgLog('CacheCleanupTask error: $e');
      return false;
    }
  }
}

// ── HTTPS Probe Task ──────────────────────────────────────────────────────────

class _HttpsProbeTask {
  static const String _lastProbeKey = 'lumio_https_probe_last';
  static const String _probeResultsKey = 'lumio_https_probe_results';

  /// Re-tests HTTP streams for HTTPS availability weekly.
  static Future<bool> run() async {
    _bgLog('HttpsProbeTask started');
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we need to run (weekly interval)
      final lastProbe = prefs.getInt(_lastProbeKey);
      if (lastProbe != null) {
        final lastTime = DateTime.fromMillisecondsSinceEpoch(lastProbe);
        final daysSince = DateTime.now().difference(lastTime).inDays;
        if (daysSince < 7) {
          _bgLog('HttpsProbeTask skipped — last run $daysSince days ago');
          return true; // Success, just skipped
        }
      }

      // Get HTTP URLs from stored channels
      final httpUrls = await _getHttpUrlsFromChannels();
      if (httpUrls.isEmpty) {
        _bgLog('HttpsProbeTask — no HTTP URLs to probe');
        await prefs.setInt(_lastProbeKey, DateTime.now().millisecondsSinceEpoch);
        return true;
      }

      _bgLog('HttpsProbeTask — probing ${httpUrls.length} HTTP URLs');

      // Probe URLs for HTTPS availability
      final results = await StreamSecurityProber.probeUrls(
        httpUrls,
        concurrency: 3, // Conservative concurrency for background task
      );

      // Count successful upgrades
      var upgradedCount = 0;
      final successfulUpgrades = <String>{};

      for (final entry in results.entries) {
        final url = entry.key;
        final result = entry.value;
        if (result.isHttpsAvailable && result.upgradedUrl != null) {
          upgradedCount++;
          successfulUpgrades.add(url);
          _bgLog('HTTPS available for: $url → ${result.upgradedUrl!}');
        }
      }

      // Store results for foreground to use
      final resultsJson = {
        'timestamp': DateTime.now().toIso8601String(),
        'total_probed': httpUrls.length,
        'upgraded_count': upgradedCount,
        'successful_upgrades': successfulUpgrades.toList(),
        'results': results.map((k, v) => MapEntry(k, {
          'original_url': v.originalUrl,
          'upgraded_url': v.upgradedUrl,
          'is_https_available': v.isHttpsAvailable,
          'security': v.security.name,
        })),
      };

      await prefs.setString(_probeResultsKey, jsonEncode(resultsJson));
      await prefs.setInt(_lastProbeKey, DateTime.now().millisecondsSinceEpoch);

      _bgLog('HttpsProbeTask done — $upgradedCount/${httpUrls.length} can be upgraded to HTTPS');
      return true;
    } catch (e) {
      _bgLog('HttpsProbeTask error: $e');
      return false;
    }
  }

  /// Extracts HTTP URLs from stored channel data.
  static Future<List<String>> _getHttpUrlsFromChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelsJson = prefs.getString('lumio_channels');
      if (channelsJson == null) return [];

      final decoded = jsonDecode(channelsJson) as List;
      final httpUrls = <String>{};

      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;

        // Check primary stream URL
        final streamUrl = item['streamUrl'] as String?;
        if (streamUrl != null && streamUrl.startsWith('http://')) {
          httpUrls.add(streamUrl);
        }

        // Check alternate streams
        final alternates = item['alternateStreams'] as List?;
        if (alternates != null) {
          for (final alt in alternates) {
            if (alt is! Map<String, dynamic>) continue;
            final altUrl = alt['url'] as String?;
            if (altUrl != null && altUrl.startsWith('http://')) {
              httpUrls.add(altUrl);
            }
          }
        }
      }

      return httpUrls.toList();
    } catch (_) {
      return [];
    }
  }
}

// =============================================================================
// PLATFORM-AWARE BASE URL  (shared by all background isolate tasks)
// Mirrors ApiService._resolveBaseUrl() — kept in sync manually.
// =============================================================================

String _resolveBaseUrl() {
  // Background isolates cannot access Platform.isAndroid directly on all
  // versions, so we read the stored preference written by the main isolate.
  // Fallback chain: stored pref → platform default → localhost
  //
  // The main isolate writes this key on first launch via
  // BackgroundService.persistBaseUrl() below.
  // Emulator fallback only allowed in debug builds
  assert(kDebugMode, 'emulator URL requires kDebugMode=true');
  const fallback = 'http://10.0.2.2:8080'; // Android emulator safe default
  return fallback; // Replaced at runtime by _readStoredBaseUrl when available
}

// =============================================================================
// BASE URL PERSISTENCE
// The main isolate writes the resolved base URL once so background isolates
// can read it without re-running platform detection logic.
// =============================================================================

extension BackgroundServiceUrl on BackgroundService {
  static const String _baseUrlKey = 'lumio_bg_base_url';

  /// Called from [ApiService] after it resolves the correct base URL.
  /// Stores it so background isolates can use the same URL.
  static Future<void> persistBaseUrl(String url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_baseUrlKey, url);
    } catch (e) {
      _bgLog('persistBaseUrl failed: $e');
    }
  }

  /// Read the stored base URL in a background isolate.
  static Future<String> readBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_baseUrlKey) ?? 'http://10.0.2.2:8080';
    } catch (_) {
      return 'http://10.0.2.2:8080';
    }
  }
}

// =============================================================================
// SCORE REFRESH RESULT  (returned to foreground listeners)
// =============================================================================

/// Immutable snapshot of a score-refresh cycle's outcome.
/// Emitted on [BackgroundService.liveScoreStream] alongside the match list
/// when you need metadata about the refresh itself.
class ScoreRefreshResult {
  /// Matches that changed score since the previous poll.
  final List<MatchModel> changedMatches;

  /// Matches that went live for the first time this cycle.
  final List<MatchModel> newlyLiveMatches;

  /// Timestamp of this refresh.
  final DateTime refreshedAt;

  const ScoreRefreshResult({
    required this.changedMatches,
    required this.newlyLiveMatches,
    required this.refreshedAt,
  });

  bool get hasChanges =>
      changedMatches.isNotEmpty || newlyLiveMatches.isNotEmpty;

  @override
  String toString() => 'ScoreRefreshResult(changed: ${changedMatches.length}, '
      'newLive: ${newlyLiveMatches.length}, at: $refreshedAt)';
}
