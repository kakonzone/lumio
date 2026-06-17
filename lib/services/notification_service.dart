// lib/services/notification_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging/safe_logger.dart';
import '../models/model.dart';
import 'firebase_bootstrap.dart';
import 'notification_image_loader.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureBackgroundFirebaseInitialized();
  await NotificationService._ensureBackgroundIsolateReady();
  await NotificationService._showFromRemoteMessage(message);
}

/// Guard FirebaseBootstrap.init() for background isolate to prevent duplicate init.
bool _backgroundIsInitialized = false;
Future<void> _ensureBackgroundFirebaseInitialized() async {
  if (_backgroundIsInitialized) return;
  await FirebaseBootstrap.initialize();
  _backgroundIsInitialized = true;
}

class _NotifId {
  _NotifId._();
  static int fromString(String id) => id.hashCode.abs() % 100000;
  static const int scoreUpdate = 2;
  static const int newsBreaking = 4;
  static const int generic = 99;
}

class _Channel {
  _Channel._();

  static const AndroidNotificationChannel matchAlerts =
      AndroidNotificationChannel(
    'match_alerts',
    'Match Alerts',
    description: 'Live match reminders and re-engagement alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

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

  /// Big-picture promos (live events, UFC-style cards).
  static const AndroidNotificationChannel promoAlerts =
      AndroidNotificationChannel(
    'lumio_promo_alerts',
    'Event & Promo Alerts',
    description: 'Rich alerts with large event images',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
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
  static bool _backgroundReady = false;
  static void Function(NotificationPayload payload)? _onTap;

  // Stream subscriptions to prevent memory leaks
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  static StreamSubscription<RemoteMessage>? _messageOpenedAppSubscription;

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
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    _messageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);
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
    await plugin.createNotificationChannel(_Channel.matchAlerts);
    await plugin.createNotificationChannel(_Channel.promoAlerts);
  }

  /// Cancel all stream subscriptions to prevent memory leaks.
  /// Call from app lifecycle teardown (e.g., WidgetsBindingObserver.dispose).
  static void dispose() {
    _foregroundMessageSubscription?.cancel();
    _messageOpenedAppSubscription?.cancel();
    _foregroundMessageSubscription = null;
    _messageOpenedAppSubscription = null;
    _log('NotificationService disposed');
  }

  /// Minimal init for FCM background isolate (no tap handler).
  static Future<void> _ensureBackgroundIsolateReady() async {
    if (_backgroundReady) return;
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _registerAndroidChannels();
    _backgroundReady = true;
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
        // POST_NOTIFICATIONS runtime prompt is API 33+ only.
        final plugin = _local.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (plugin == null) return true;
        try {
          return await plugin.requestNotificationsPermission() ?? true;
        } catch (_) {
          return true;
        }
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

  /// Rich promo / event alert (Big Picture on Android, image attachment on iOS).
  static Future<void> showPromoAlert({
    required String title,
    required String body,
    required String imageUrl,
    String entityId = '',
    String? streamUrl,
    NotificationPayloadType type = NotificationPayloadType.promo,
  }) async {
    if (!await _shouldShow()) return;
    await _showRichNotification(
      id: entityId.isNotEmpty ? _NotifId.fromString(entityId) : _NotifId.generic,
      title: title,
      body: body,
      imageUrl: imageUrl,
      channel: _Channel.promoAlerts,
      payload: NotificationPayload(
        type: type,
        entityId: entityId,
        streamUrl: streamUrl,
      ),
    );
    _log('showPromoAlert: $title');
  }

  static Future<void> showMatchLiveAlert(
    MatchModel match, {
    String? imageUrl,
  }) async {
    if (!await _shouldShow()) return;
    if (!await isLiveAlertsEnabled()) return;

    final title = '🔴 Live Now';
    final body = '${match.teamA} vs ${match.teamB} has kicked off!';
    await _showRichNotification(
      id: _NotifId.fromString(match.id),
      title: title,
      body: body,
      imageUrl: imageUrl,
      channel: _Channel.liveMatches,
      importance: Importance.high,
      priority: Priority.high,
      ticker: '${match.teamA} vs ${match.teamB}',
      fallbackStyle: BigTextStyleInformation(
        '$body Tap to watch on ${match.channel}.',
        contentTitle: title,
      ),
      payload: NotificationPayload(
        type: NotificationPayloadType.matchLive,
        entityId: match.id,
        streamUrl: match.streamUrl,
      ),
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

    final title = '📰 ${article.category}';
    final body = article.title;
    await _showRichNotification(
      id: _NotifId.newsBreaking,
      title: title,
      body: body,
      imageUrl: article.imageUrl.isNotEmpty ? article.imageUrl : null,
      channel: _Channel.breakingNews,
      importance: Importance.high,
      payload: NotificationPayload(
        type: NotificationPayloadType.breakingNews,
        entityId: article.id,
      ),
    );
    _log('showBreakingNews: ${article.id}');
  }

  /// Schedules a generic match re-engagement notification [minutes] into future.
  static Future<void> scheduleReengagementInMinutes(int minutes) async {
    if (!await _shouldShow()) return;
    if (minutes <= 0) minutes = 5;
    Future.delayed(Duration(minutes: minutes), () async {
      await _local.show(
        id: _NotifId.generic,
        title: '📺 Live match starting soon',
        body: 'Tap to jump back into Lumio and catch the action.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _Channel.matchAlerts.id,
            _Channel.matchAlerts.name,
            channelDescription: _Channel.matchAlerts.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: NotificationPayload(
          type: NotificationPayloadType.matchLive,
          entityId: '',
          streamUrl: null,
        ).toJsonString(),
      );
    });
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
    if (!await _shouldShow()) return;

    final data = message.data;
    final type = data['type'] as String?;
    final entityId = data['entityId'] as String?;
    final title =
        message.notification?.title ?? data['title'] as String? ?? 'Lumio';
    final body = message.notification?.body ?? data['body'] as String? ?? '';
    final streamUrl = data['streamUrl'] as String?;
    final imageUrl = _extractImageUrl(message);

    final notifType = _parsePayloadType(type);
    final channel = _channelForType(notifType);
    final notifId =
        entityId != null ? _NotifId.fromString(entityId) : _NotifId.generic;

    try {
      await _showRichNotification(
        id: notifId,
        title: title,
        body: body,
        imageUrl: imageUrl,
        channel: channel,
        payload: NotificationPayload(
          type: notifType,
          entityId: entityId ?? '',
          streamUrl: streamUrl,
        ),
      );
    } catch (e) {
      SafeLogger.error('notification', '[NotificationService] _showFromRemoteMessage failed', e);
    }
  }

  static String? _extractImageUrl(RemoteMessage message) {
    final fromData = _imageUrlFromMap(message.data);
    if (fromData != null) return fromData;
    final androidImg = message.notification?.android?.imageUrl;
    if (androidImg != null && androidImg.trim().isNotEmpty) {
      return androidImg.trim();
    }
    final appleImg = message.notification?.apple?.imageUrl;
    if (appleImg != null && appleImg.trim().isNotEmpty) {
      return appleImg.trim();
    }
    return null;
  }

  static String? _imageUrlFromMap(Map<String, dynamic> data) {
    for (final key in const [
      'imageUrl',
      'image',
      'image_url',
      'big_picture',
      'bigPicture',
    ]) {
      final raw = data[key];
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    return null;
  }

  static Future<void> _showRichNotification({
    required int id,
    required String title,
    required String body,
    required NotificationPayload payload,
    required AndroidNotificationChannel channel,
    String? imageUrl,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    String? ticker,
    StyleInformation? fallbackStyle,
  }) async {
    final details = await _buildNotificationDetails(
      channel: channel,
      title: title,
      body: body,
      imageUrl: imageUrl,
      importance: importance,
      priority: priority,
      ticker: ticker,
      fallbackStyle: fallbackStyle,
    );
    await _local.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload.toJsonString(),
    );
  }

  static Future<NotificationDetails> _buildNotificationDetails({
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    String? imageUrl,
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    String? ticker,
    StyleInformation? fallbackStyle,
  }) async {
    StyleInformation? androidStyle = fallbackStyle;
    List<DarwinNotificationAttachment>? iosAttachments;

    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      final path = await NotificationImageLoader.downloadToCache(url);
      if (path != null) {
        if (Platform.isAndroid) {
          androidStyle = BigPictureStyleInformation(
            FilePathAndroidBitmap(path),
            contentTitle: title,
            summaryText: body,
            hideExpandedLargeIcon: true,
          );
        }
        if (Platform.isIOS) {
          iosAttachments = [DarwinNotificationAttachment(path)];
        }
      }
    }

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: importance,
        priority: priority,
        ticker: ticker,
        styleInformation: androidStyle,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: iosAttachments,
      ),
    );
  }

  static void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    final payload = NotificationPayload.fromJsonString(raw);
    if (payload != null) _onTap?.call(payload);
  }

  @pragma('vm:entry-point')
  static void _onLocalBackgroundTap(NotificationResponse response) {
    SafeLogger.debug('notification', '[NotificationService] Background tap: ${response.payload}');
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  static String _matchTopic(String matchId) =>
      'match_${matchId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  static String _channelTopic(String channelId) =>
      'channel_${channelId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

  static AndroidNotificationChannel _channelForType(
    NotificationPayloadType type,
  ) {
    switch (type) {
      case NotificationPayloadType.matchLive:
        return _Channel.liveMatches;
      case NotificationPayloadType.scoreUpdate:
        return _Channel.scoreUpdates;
      case NotificationPayloadType.channelReminder:
        return _Channel.channelReminders;
      case NotificationPayloadType.breakingNews:
        return _Channel.breakingNews;
      case NotificationPayloadType.promo:
        return _Channel.promoAlerts;
      case NotificationPayloadType.unknown:
        return _Channel.promoAlerts;
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
      case 'promo':
        return NotificationPayloadType.promo;
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
    SafeLogger.debug('notification', '[NotificationService] $message');
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
  promo,
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