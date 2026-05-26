// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/model.dart';
import 'firebase_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService._showFromRemoteMessage(message);
}

class _NotifId {
  _NotifId._();
  static int fromString(String id) => id.hashCode.abs() % 100000;
  static const int liveAlert = 1;
  static const int scoreUpdate = 2;
  static const int channelReminder = 3;
  static const int newsBreaking = 4;
  static const int generic = 99;
}

class _Channel {
  _Channel._();

  static const AndroidNotificationChannel liveMatches =
      AndroidNotificationChannel(
    'lumio_live_matches',
    'Live Match Alerts',
    description: 'Notifies when a followed match goes live',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel scoreUpdates =
      AndroidNotificationChannel(
    'lumio_score_updates',
    'Score Updates',
    description: 'Goal and score change notifications',
    importance: Importance.defaultImportance,
    playSound: false,
    enableVibration: false,
  );

  static const AndroidNotificationChannel channelReminders =
      AndroidNotificationChannel(
    'lumio_channel_reminders',
    'Channel Reminders',
    description: 'Reminders for upcoming programmes on watched channels',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel breakingNews =
      AndroidNotificationChannel(
    'lumio_breaking_news',
    'Breaking Sports News',
    description: 'Major sports news alerts',
    importance: Importance.high,
  );
}

class _Prefs {
  _Prefs._();
  static const String subscribedMatches = 'lumio_notif_matches';
  static const String subscribedChannels = 'lumio_notif_channels';
  static const String globalEnabled = 'lumio_notif_enabled';
  static const String liveAlertsEnabled = 'lumio_notif_live';
  static const String scoreUpdatesEnabled = 'lumio_notif_scores';
  static const String newsAlertsEnabled = 'lumio_notif_news';
}

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Only valid after [FirebaseBootstrap.initialize] succeeds.
  static FirebaseMessaging? get _fcm =>
      FirebaseBootstrap.isInitialized ? FirebaseMessaging.instance : null;

  static bool _initialized = false;
  static void Function(NotificationPayload payload)? _onTap;

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  static Future<void> initialize({
    void Function(NotificationPayload payload)? onNotificationTap,
  }) async {
    if (_initialized) return;
    _onTap = onNotificationTap;

    await _initLocalNotifications();
    await _initFCM();
    await _registerAndroidChannels();

    _initialized = true;
    _log('NotificationService initialized');
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onLocalTap,
      onDidReceiveBackgroundNotificationResponse: _onLocalBackgroundTap,
    );
  }

  static Future<void> _initFCM() async {
    final fcm = _fcm;
    if (fcm == null) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationService] FCM skipped — add android/app/google-services.json',
        );
      }
      return;
    }
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
    final initial = await fcm.getInitialMessage();
    if (initial != null) _onMessageOpenedApp(initial);
  }

  static Future<void> _registerAndroidChannels() async {
    if (!Platform.isAndroid) return;
    final plugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    await plugin.createNotificationChannel(_Channel.liveMatches);
    await plugin.createNotificationChannel(_Channel.scoreUpdates);
    await plugin.createNotificationChannel(_Channel.channelReminders);
    await plugin.createNotificationChannel(_Channel.breakingNews);
  }

  // ===========================================================================
  // PERMISSIONS
  // ===========================================================================

  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final fcm = _fcm;
        if (fcm == null) return false;
        final settings = await fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        return settings.authorizationStatus == AuthorizationStatus.authorized;
      }
      if (Platform.isAndroid) {
        final plugin = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.requestNotificationsPermission() ?? false;
        return granted;
      }
      return false;
    } catch (e) {
      _log('requestPermissions failed: $e');
      return false;
    }
  }

  static Future<NotificationPermissionStatus> getPermissionStatus() async {
    try {
      if (Platform.isIOS) {
        final fcm = _fcm;
        if (fcm == null) return NotificationPermissionStatus.denied;
        final settings = await fcm.getNotificationSettings();
        switch (settings.authorizationStatus) {
          case AuthorizationStatus.authorized:
            return NotificationPermissionStatus.granted;
          case AuthorizationStatus.provisional:
            return NotificationPermissionStatus.provisional;
          case AuthorizationStatus.denied:
            return NotificationPermissionStatus.denied;
          case AuthorizationStatus.notDetermined:
            return NotificationPermissionStatus.notDetermined;
        }
      }
      if (Platform.isAndroid) {
        final plugin = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final granted = await plugin?.areNotificationsEnabled() ?? false;
        return granted
            ? NotificationPermissionStatus.granted
            : NotificationPermissionStatus.denied;
      }
      return NotificationPermissionStatus.notDetermined;
    } catch (e) {
      _log('getPermissionStatus failed: $e');
      return NotificationPermissionStatus.notDetermined;
    }
  }

  // ===========================================================================
  // FCM TOKEN
  // ===========================================================================

  static Future<String?> getToken() async {
    try {
      final fcm = _fcm;
      if (fcm == null) return null;
      return await fcm.getToken();
    } catch (e) {
      _log('getToken failed: $e');
      return null;
    }
  }

  static Stream<String> get onTokenRefresh =>
      _fcm?.onTokenRefresh ?? const Stream<String>.empty();

  // ===========================================================================
  // TOPIC SUBSCRIPTIONS
  // ===========================================================================

  static Future<void> subscribeToMatch(MatchModel match) async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;
      final topic = _matchTopic(match.id);
      await fcm.subscribeToTopic(topic);
      await _persistSubscription(_Prefs.subscribedMatches, match.id);
      _log('Subscribed to match topic: $topic');
    } catch (e) {
      _log('subscribeToMatch(${match.id}) failed: $e');
    }
  }

  static Future<void> unsubscribeFromMatch(MatchModel match) async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;
      final topic = _matchTopic(match.id);
      await fcm.unsubscribeFromTopic(topic);
      await _removeSubscription(_Prefs.subscribedMatches, match.id);
      _log('Unsubscribed from match topic: $topic');
    } catch (e) {
      _log('unsubscribeFromMatch(${match.id}) failed: $e');
    }
  }

  // FIX: Channel → ChannelModel
  static Future<void> subscribeToChannel(ChannelModel channel) async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;
      final topic = _channelTopic(channel.id);
      await fcm.subscribeToTopic(topic);
      await _persistSubscription(_Prefs.subscribedChannels, channel.id);
      _log('Subscribed to channel topic: $topic');
    } catch (e) {
      _log('subscribeToChannel(${channel.id}) failed: $e');
    }
  }

  // FIX: Channel → ChannelModel
  static Future<void> unsubscribeFromChannel(ChannelModel channel) async {
    try {
      final fcm = _fcm;
      if (fcm == null) return;
      final topic = _channelTopic(channel.id);
      await fcm.unsubscribeFromTopic(topic);
      await _removeSubscription(_Prefs.subscribedChannels, channel.id);
      _log('Unsubscribed from channel topic: $topic');
    } catch (e) {
      _log('unsubscribeFromChannel(${channel.id}) failed: $e');
    }
  }

  static Future<bool> isSubscribedToMatch(String matchId) async {
    final ids = await _loadSubscriptions(_Prefs.subscribedMatches);
    return ids.contains(matchId);
  }

  static Future<bool> isSubscribedToChannel(String channelId) async {
    final ids = await _loadSubscriptions(_Prefs.subscribedChannels);
    return ids.contains(channelId);
  }

  static Future<List<String>> getSubscribedMatchIds() =>
      _loadSubscriptions(_Prefs.subscribedMatches);

  static Future<List<String>> getSubscribedChannelIds() =>
      _loadSubscriptions(_Prefs.subscribedChannels);

  // ===========================================================================
  // USER PREFERENCES
  // ===========================================================================

  static Future<void> setGlobalEnabled(bool enabled) =>
      _setBoolPref(_Prefs.globalEnabled, enabled);
  static Future<bool> isGlobalEnabled() =>
      _getBoolPref(_Prefs.globalEnabled, defaultValue: true);

  static Future<void> setLiveAlertsEnabled(bool enabled) =>
      _setBoolPref(_Prefs.liveAlertsEnabled, enabled);
  static Future<bool> isLiveAlertsEnabled() =>
      _getBoolPref(_Prefs.liveAlertsEnabled, defaultValue: true);

  static Future<void> setScoreUpdatesEnabled(bool enabled) =>
      _setBoolPref(_Prefs.scoreUpdatesEnabled, enabled);
  static Future<bool> isScoreUpdatesEnabled() =>
      _getBoolPref(_Prefs.scoreUpdatesEnabled, defaultValue: true);

  static Future<void> setNewsAlertsEnabled(bool enabled) =>
      _setBoolPref(_Prefs.newsAlertsEnabled, enabled);
  static Future<bool> isNewsAlertsEnabled() =>
      _getBoolPref(_Prefs.newsAlertsEnabled, defaultValue: false);

  // ===========================================================================
  // LOCAL NOTIFICATION DISPLAY
  // ===========================================================================

  static Future<void> showMatchLiveAlert(MatchModel match) async {
    if (!await _shouldShow()) return;
    if (!await isLiveAlertsEnabled()) return;

    await _local.show(
      id: _NotifId.fromString(match.id),
      title: '🔴 Live Now',
      body: '${match.teamA} vs ${match.teamB} has kicked off!',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _Channel.liveMatches.id,
          _Channel.liveMatches.name,
          channelDescription: _Channel.liveMatches.description,
          importance: Importance.high,
          priority: Priority.high,
          ticker: '${match.teamA} vs ${match.teamB}',
          styleInformation: BigTextStyleInformation(
            '${match.teamA} vs ${match.teamB} is live on ${match.channel}. '
            'Tap to watch now.',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: NotificationPayload(
        type: NotificationPayloadType.matchLive,
        entityId: match.id,
        streamUrl: match.streamUrl,
      ).toJsonString(),
    );
    _log('showMatchLiveAlert: ${match.id}');
  }

  static Future<void> showScoreUpdate({
    required MatchModel match,
    required String updateText,
  }) async {
    if (!await _shouldShow()) return;
    if (!await isScoreUpdatesEnabled()) return;

    await _local.show(
      id: _NotifId.scoreUpdate,
      title: '⚽ Score Update',
      body: updateText,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _Channel.scoreUpdates.id,
          _Channel.scoreUpdates.name,
          channelDescription: _Channel.scoreUpdates.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          onlyAlertOnce: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: false,
        ),
      ),
      payload: NotificationPayload(
        type: NotificationPayloadType.scoreUpdate,
        entityId: match.id,
        streamUrl: match.streamUrl,
      ).toJsonString(),
    );
    _log('showScoreUpdate: ${match.id}');
  }

  // FIX: Channel → ChannelModel
  static Future<void> showChannelReminder({
    required ChannelModel channel,
    required String programmeName,
    required int minutesUntilStart,
  }) async {
    if (!await _shouldShow()) return;

    final timeLabel = minutesUntilStart <= 1
        ? 'starting now'
        : 'in $minutesUntilStart minutes';

    await _local.show(
      id: _NotifId.fromString(channel.id),
      title: '📺 ${channel.name}',
      body: '$programmeName $timeLabel',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _Channel.channelReminders.id,
          _Channel.channelReminders.name,
          channelDescription: _Channel.channelReminders.description,
          importance: Importance.defaultImportance,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      payload: NotificationPayload(
        type: NotificationPayloadType.channelReminder,
        entityId: channel.id,
        streamUrl: channel.streamUrl,
      ).toJsonString(),
    );
    _log('showChannelReminder: ${channel.id}');
  }

  // FIX: NewsArticle → NewsModel
  static Future<void> showBreakingNews(NewsModel article) async {
    if (!await _shouldShow()) return;
    if (!await isNewsAlertsEnabled()) return;

    await _local.show(
      id: _NotifId.newsBreaking,
      title: '📰 ${article.category}',
      body: article.title,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _Channel.breakingNews.id,
          _Channel.breakingNews.name,
          channelDescription: _Channel.breakingNews.description,
          importance: Importance.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: NotificationPayload(
        type: NotificationPayloadType.breakingNews,
        entityId: article.id,
      ).toJsonString(),
    );
    _log('showBreakingNews: ${article.id}');
  }

  static Future<void> cancelNotification(int notifId) async {
    try {
      await _local.cancel(id: notifId);
    } catch (e) {
      _log('cancelNotification($notifId) failed: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _local.cancelAll();
    } catch (e) {
      _log('cancelAll failed: $e');
    }
  }

  // ===========================================================================
  // FCM MESSAGE HANDLERS
  // ===========================================================================

  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    _log('Foreground FCM: ${message.messageId}');
    await _showFromRemoteMessage(message);
  }

  static void _onMessageOpenedApp(RemoteMessage message) {
    _log('FCM tap opened app: ${message.messageId}');
    final payload = _payloadFromData(message.data);
    if (payload != null) _onTap?.call(payload);
  }

  static Future<void> _showFromRemoteMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;
    final entityId = data['entityId'] as String?;
    final title =
        message.notification?.title ?? data['title'] as String? ?? 'Lumio';
    final body = message.notification?.body ?? data['body'] as String? ?? '';
    final streamUrl = data['streamUrl'] as String?;

    final notifType = _parsePayloadType(type);
    final channelId = _fcmChannelId(notifType);
    final notifId =
        entityId != null ? _NotifId.fromString(entityId) : _NotifId.generic;

    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.show(
        id: notifId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: NotificationPayload(
          type: notifType,
          entityId: entityId ?? '',
          streamUrl: streamUrl,
        ).toJsonString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('[NotificationService] _showFromRemoteMessage failed: $e');
      }
    }
  }

  static void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    final payload = NotificationPayload.fromJsonString(raw);
    if (payload != null) _onTap?.call(payload);
  }

  @pragma('vm:entry-point')
  static void _onLocalBackgroundTap(NotificationResponse response) {
    if (kDebugMode) {
      print('[NotificationService] Background tap: ${response.payload}');
    }
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  static String _matchTopic(String matchId) =>
      'match_${matchId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  static String _channelTopic(String channelId) =>
      'channel_${channelId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  static String _fcmChannelId(NotificationPayloadType type) {
    switch (type) {
      case NotificationPayloadType.matchLive:
        return _Channel.liveMatches.id;
      case NotificationPayloadType.scoreUpdate:
        return _Channel.scoreUpdates.id;
      case NotificationPayloadType.channelReminder:
        return _Channel.channelReminders.id;
      case NotificationPayloadType.breakingNews:
        return _Channel.breakingNews.id;
      case NotificationPayloadType.unknown:
        return _Channel.liveMatches.id;
    }
  }

  static NotificationPayloadType _parsePayloadType(String? raw) {
    switch (raw) {
      case 'matchLive':
        return NotificationPayloadType.matchLive;
      case 'scoreUpdate':
        return NotificationPayloadType.scoreUpdate;
      case 'channelReminder':
        return NotificationPayloadType.channelReminder;
      case 'breakingNews':
        return NotificationPayloadType.breakingNews;
      default:
        return NotificationPayloadType.unknown;
    }
  }

  static NotificationPayload? _payloadFromData(Map<String, dynamic> data) {
    try {
      return NotificationPayload(
        type: _parsePayloadType(data['type'] as String?),
        entityId: data['entityId'] as String? ?? '',
        streamUrl: data['streamUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _shouldShow() async {
    final globalOn = await isGlobalEnabled();
    if (!globalOn) _log('Notifications suppressed — global switch is off');
    return globalOn;
  }

  static Future<void> _persistSubscription(String prefsKey, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = await _loadSubscriptions(prefsKey);
      if (!ids.contains(id)) {
        ids.add(id);
        await prefs.setString(prefsKey, jsonEncode(ids));
      }
    } catch (e) {
      _log('_persistSubscription failed: $e');
    }
  }

  static Future<void> _removeSubscription(String prefsKey, String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = await _loadSubscriptions(prefsKey);
      ids.remove(id);
      await prefs.setString(prefsKey, jsonEncode(ids));
    } catch (e) {
      _log('_removeSubscription failed: $e');
    }
  }

  static Future<List<String>> _loadSubscriptions(String prefsKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List<dynamic>).cast<String>();
    } catch (e) {
      _log('_loadSubscriptions failed: $e');
      return [];
    }
  }

  static Future<void> _setBoolPref(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      _log('_setBoolPref($key) failed: $e');
    }
  }

  static Future<bool> _getBoolPref(String key,
      {required bool defaultValue}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } catch (e) {
      _log('_getBoolPref($key) failed: $e');
      return defaultValue;
    }
  }

  static void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[NotificationService] $message');
      return true;
    }());
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYLOAD
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationPayloadType {
  matchLive,
  scoreUpdate,
  channelReminder,
  breakingNews,
  unknown,
}

class NotificationPayload {
  final NotificationPayloadType type;
  final String entityId;
  final String? streamUrl;

  const NotificationPayload({
    required this.type,
    required this.entityId,
    this.streamUrl,
  });

  String toJsonString() => jsonEncode({
        'type': type.name,
        'entityId': entityId,
        if (streamUrl != null) 'streamUrl': streamUrl,
      });

  static NotificationPayload? fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final typeStr = map['type'] as String?;
      final type = NotificationPayloadType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => NotificationPayloadType.unknown,
      );
      return NotificationPayload(
        type: type,
        entityId: map['entityId'] as String? ?? '',
        streamUrl: map['streamUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

enum NotificationPermissionStatus {
  granted,
  denied,
  provisional,
  notDetermined,
}