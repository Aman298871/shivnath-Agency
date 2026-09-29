import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import '../../routes/app_routes.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
  debugPrint('FCM [Background]: Message received ID: ${message.messageId}, Title: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _currentFcmToken;
  String? get currentFcmToken => _currentFcmToken;

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? navigatorKey;

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription = 'Used for Shivnath Agency business, order, and payment notifications.';

  /// Initialize Firebase Cloud Messaging, local notification channels & listeners
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    if (navKey != null) {
      navigatorKey = navKey;
    }

    try {
      // 1. Initialize Firebase App (guard against duplicate default app)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      debugPrint('FCM: Firebase app ready.');

      // 2. Setup Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('FCM: AndroidNotificationChannel created successfully.');
      }

      // 3. Initialize Local Notifications Plugin
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initDarwin = DarwinInitializationSettings();
      const InitializationSettings initSettings =
          InitializationSettings(android: initAndroid, iOS: initDarwin);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('FCM: Local notification clicked: ${response.payload}');
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              handleNotificationNavigation(data);
            } catch (e) {
              debugPrint('FCM: Error parsing notification payload: $e');
            }
          }
        },
      );

      // 4. Request Permissions (Android 13+ and iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM: Permission status: ${settings.authorizationStatus}');

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('FCM: Android POST_NOTIFICATIONS granted: $granted');
      }

      // 5. Set foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 6. Listen for incoming messages in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM [Foreground]: ${message.notification?.title} - ${message.notification?.body}');
        _showForegroundNotification(message);
      });

      // 7. Background & Killed state handling
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM [Resume]: Notification tapped with data: ${message.data}');
        handleNotificationNavigation(message.data);
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM [Initial]: App opened from terminated state: ${initialMessage.data}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleNotificationNavigation(initialMessage.data);
        });
      }

      // 8. Retrieve FCM Token
      try {
        _currentFcmToken = await _fcm.getToken();
        debugPrint('FCM: Registration Token: $_currentFcmToken');
        if (_currentFcmToken != null && _currentFcmToken!.isNotEmpty) {
          registerDeviceTokenWithBackend();
        }
      } catch (e) {
        debugPrint('FCM: Failed to obtain token: $e');
      }

      // 9. Token Refresh Listener
      _fcm.onTokenRefresh.listen((String newToken) {
        debugPrint('FCM: Token refreshed: $newToken');
        _currentFcmToken = newToken;
        registerDeviceTokenWithBackend();
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('FCM: Initialization error: $e');
    }
  }

  /// Show notification banner via FlutterLocalNotifications when in foreground
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Shivnath Agency';
    final body = message.notification?.body ?? message.data['body'] ?? 'New notification received';

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// Register FCM Token with Backend for the logged-in user
  Future<bool> registerDeviceTokenWithBackend() async {
    if (_currentFcmToken == null || _currentFcmToken!.isEmpty) {
      debugPrint('FCM: No token available to register.');
      return false;
    }

    final session = SessionService();
    final isLoggedIn = await session.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('FCM: User not logged in. Token saved locally for future registration.');
      return false;
    }

    final token = await session.getAccessToken();
    if (token == null || token.isEmpty) return false;

    try {
      final deviceType = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      final candidates = [
        '${AppConstants.apiBaseUrl}/api/auth/notifications/register-device/',
        '${AppConstants.apiBaseUrl}/api/notifications/register-device/',
      ];

      for (final endpoint in candidates) {
        final url = Uri.parse(endpoint);
        final response = await ApiClient.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'token': _currentFcmToken,
            'device_type': deviceType,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('FCM: Device token successfully registered with backend via $endpoint');
          return true;
        } else {
          debugPrint('FCM: Attempt via $endpoint gave ${response.statusCode}');
        }
      }
      return false;
    } catch (e) {
      debugPrint('FCM: Exception registering device token: $e');
      return false;
    }
  }

  /// Unregister FCM Token when user logs out
  Future<void> unregisterDeviceTokenWithBackend() async {
    if (_currentFcmToken == null || _currentFcmToken!.isEmpty) return;

    final session = SessionService();
    final token = await session.getAccessToken();
    if (token == null || token.isEmpty) return;

    final candidates = [
      '${AppConstants.apiBaseUrl}/api/auth/notifications/unregister-device/',
      '${AppConstants.apiBaseUrl}/api/notifications/unregister-device/',
    ];

    for (final endpoint in candidates) {
      try {
        final url = Uri.parse(endpoint);
        final response = await ApiClient.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'token': _currentFcmToken,
          }),
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('FCM: Device token unregistered successfully.');
          break;
        }
      } catch (_) {}
    }
  }

  /// Smart deep-linking / navigation based on push payload
  void handleNotificationNavigation(Map<String, dynamic> data) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('FCM: Navigator state is not ready.');
      return;
    }

    final screen = (data['screen'] ?? '').toString().toLowerCase();
    final notifType = (data['notification_type'] ?? '').toString().toLowerCase();

    debugPrint('FCM: Navigating for screen: $screen, type: $notifType');

    if (screen.contains('admin') || notifType.contains('order_placed')) {
      nav.pushNamed(AppRoutes.adminDashboard);
    } else if (screen.contains('franchise') || notifType.contains('stock')) {
      nav.pushNamed(AppRoutes.franchiseDashboard);
    } else if (screen.contains('customer') || notifType.contains('order_status')) {
      nav.pushNamed(AppRoutes.customerDashboard);
    } else {
      // Default to root dashboard
      nav.pushNamed(AppRoutes.splash);
    }
  }

  /// Fetch authoritative notifications for Admin & Super Admin dashboard
  Future<Map<String, dynamic>> getAdminNotifications() async {
    try {
      final session = SessionService();
      final token = await session.getAccessToken();
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/accounts/notifications/');
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to load notifications'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Mark notification as read
  Future<Map<String, dynamic>> markAdminNotificationRead(int id) async {
    try {
      final session = SessionService();
      final token = await session.getAccessToken();
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/accounts/notifications/');
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      }
      return {'success': false};
    } catch (_) {
      return {'success': false};
    }
  }
}
