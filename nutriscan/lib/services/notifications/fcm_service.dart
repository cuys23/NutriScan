import 'dart:async';
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // iOS only: whether an APNS token was obtained. When false, every topic
  // (un)subscribe call would fail the same way (`apns-token-not-set`) —
  // checked once and memoized instead of per-call, so a device without
  // push entitlement (or a user who denied the permission) doesn't pay
  // for ~20 sequential failing plugin calls + Crashlytics reports at
  // startup. main.dart fires initializeNotifications() and the topic
  // subscribe calls without awaiting each other, so this must be safe to
  // call concurrently from all of them — memoizing the in-flight Future
  // (not just the resolved bool) is what makes that safe.
  Future<bool>? _pushAvailabilityCheck;

  Future<bool> _isPushAvailable() {
    if (!Platform.isIOS) return Future.value(true);
    return _pushAvailabilityCheck ??= _messaging.getAPNSToken().then((token) async {
      if (token != null) return true;
      await Future.delayed(const Duration(seconds: 3));
      return (await _messaging.getAPNSToken()) != null;
    });
  }

  final StreamController<RemoteMessage> _messageController =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get messageStream => _messageController.stream;

  bool _initialized = false;

  Function()? _onNotificationReceived;
  Function()? _onFCMNotificationShown;
  Function()? _checkPauseStatus;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize local notifications for FCM
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Request permissions
      await requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Listen for notification taps when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Check if app was opened from a terminated state via notification
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessage(initialMessage);
      }

      _initialized = true;
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCMService.initialize failed');
    }
  }

  Future<void> requestPermissions() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM requestPermissions failed');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      if (!await _isPushAvailable()) return;

      _fcmToken = await _messaging.getToken();

      if (_fcmToken != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Send token to backend server if needed
        await _sendTokenToServer(_fcmToken!);
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM _getFCMToken failed');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      // Implement backend API call to save token
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM _sendTokenToServer failed');
    }
  }

  void _onTokenRefresh(String token) async {
    _pushAvailabilityCheck = Future.value(true);
    _fcmToken = token;

    // Save new token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);

    // Send to server
    await _sendTokenToServer(token);
  }

  void _onForegroundMessage(RemoteMessage message) async {
    // Check if this is a critical notification
    final isCritical = _isCriticalNotification(message);

    // Show local notification when app is in foreground
    await _showLocalNotification(message, isCritical: isCritical);

    // Emit message to stream
    _messageController.add(message);
  }

  bool _isCriticalNotification(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('critical') && data['critical'] == 'true') {
      return true;
    }

    if (data.containsKey('topic')) {
      final topic = data['topic'].toString();
      if (topic == 'system_maintenance' ||
          topic == 'critical_updates' ||
          topic == 'security_alerts') {
        return true;
      }
    }

    return false;
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    _handleMessage(message);
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap based on payload
    if (response.payload != null && response.payload!.isNotEmpty) {
      _handleNotificationPayload(response.payload!);
    }
  }

  void _handleMessage(RemoteMessage message) {
    // Emit to stream for UI to handle
    _messageController.add(message);

    // Handle based on message data
    final data = message.data;
    if (data.isNotEmpty) {
      _handleNotificationData(data);
    }
  }

  void _handleNotificationPayload(String payload) {
    debugPrint('FCM Notification tapped with payload: $payload');
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Implement actions based on notification data
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    bool isCritical = false,
  }) async {
    try {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null) {
        // Check pause status for non-critical notifications
        if (!isCritical) {
          final isPaused = await _checkPauseStatus?.call() ?? false;
          if (isPaused) {
            return;
          }

          final canShow = await _checkDailyLimit();
          if (!canShow) {
            return;
          }
        }

        await _localNotifications.show(
          message.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              isCritical ? 'critical_channel' : 'fcm_channel',
              isCritical ? 'Critical Notifications' : 'FCM Notifications',
              channelDescription: isCritical
                  ? 'Critical system notifications'
                  : 'Firebase Cloud Messaging notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: android?.smallIcon ?? '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              showWhen: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: message.data.toString(),
        );

        // Notify callback for UI update
        _onNotificationReceived?.call();

        // Increment FCM notification counter for non-critical
        if (!isCritical) {
          _onFCMNotificationShown?.call();
        }
      }
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM _showLocalNotification failed');
    }
  }

  Future<bool> _checkDailyLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('daily_notification_count') ?? 0;
      final lastDate = prefs.getString('last_notification_date');

      final today = DateTime.now();
      final todayString = '${today.year}-${today.month}-${today.day}';

      if (lastDate != todayString) {
        return true;
      }

      return count < 3;
    } catch (e) {
      return true;
    }
  }

  void setNotificationCallback(Function() callback) {
    _onNotificationReceived = callback;
  }

  void setFCMNotificationShownCallback(Function() callback) {
    _onFCMNotificationShown = callback;
  }

  void setPauseCheckCallback(Future<bool> Function() callback) {
    _checkPauseStatus = callback;
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!await _isPushAvailable()) return;
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM subscribeToTopic($topic) failed');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!await _isPushAvailable()) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM unsubscribeFromTopic($topic) failed');
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(e, stack, reason: 'FCM deleteToken failed');
    }
  }

  void dispose() {
    _messageController.close();
  }
}
