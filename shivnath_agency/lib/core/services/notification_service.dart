import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  debugPrint(
    'FCM [Background]: Message received ID: ${message.messageId}, Title: ${message.notification?.title}',
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentFcmToken;
  String? get currentFcmToken => _currentFcmToken;

  bool _isInitialized = false;
  GlobalKey<NavigatorState>? navigatorKey;

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription =
      'Used for Shivnath Agency business, order, and payment notifications.';

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
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('FCM: AndroidNotificationChannel created successfully.');
      }

      // 3. Initialize Local Notifications Plugin
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initDarwin =
          DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(
        android: initAndroid,
        iOS: initDarwin,
      );

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
        debugPrint(
          'FCM [Foreground]: ${message.notification?.title} - ${message.notification?.body}',
        );
        _showForegroundNotification(message);
      });

      // 7. Background & Killed state handling
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          'FCM [Resume]: Notification tapped with data: ${message.data}',
        );
        handleNotificationNavigation(message.data);
      });

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          'FCM [Initial]: App opened from terminated state: ${initialMessage.data}',
        );
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
    final title =
        message.notification?.title ??
        message.data['title'] ??
        'WaterNow';
    final body =
        message.notification?.body ??
        message.data['body'] ??
        'New notification received';

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

    // Show actionable foreground dialog/banner if context is ready
    _showForegroundInAppAlert(title, body, message.data);
  }

  void _showForegroundInAppAlert(String title, String body, Map<String, dynamic> data) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    final rawOrderId = data['order_id'] ?? data['orderId'] ?? data['reference_id'] ?? data['id'];
    final notifType = (data['notification_type'] ?? data['event_type'] ?? '').toString().toLowerCase();
    final isOrderEvent = rawOrderId != null && (notifType.contains('order') || data.containsKey('order_code') || data.containsKey('order_id'));

    ScaffoldMessenger.maybeOf(ctx)?.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: isOrderEvent ? const Color(0xFF0284C7) : const Color(0xFF10B981),
          radius: 18,
          child: Icon(
            isOrderEvent ? Icons.shopping_bag_outlined : Icons.notifications_active_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (isOrderEvent)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.maybeOf(ctx)?.hideCurrentMaterialBanner();
                handleNotificationNavigation(data);
              },
              child: const Text(
                'VIEW ORDER',
                style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800),
              ),
            ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.maybeOf(ctx)?.hideCurrentMaterialBanner();
            },
            child: const Text(
              'DISMISS',
              style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    // Auto-dismiss banner after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      try {
        if (ctx.mounted) {
          ScaffoldMessenger.maybeOf(ctx)?.hideCurrentMaterialBanner();
        }
      } catch (_) {}
    });
  }

  String? _lastRegisteredUserKey;

  /// Clears token registration cache on logout / user switch
  void resetRegistrationCache() {
    _lastRegisteredUserKey = null;
  }

  /// Register FCM Token with Backend for the logged-in user with strict deduplication
  Future<bool> registerDeviceTokenWithBackend({bool force = false}) async {
    if (_currentFcmToken == null || _currentFcmToken!.isEmpty) {
      try {
        _currentFcmToken = await _fcm.getToken();
        debugPrint('FCM: Fetched token dynamically: $_currentFcmToken');
      } catch (e) {
        debugPrint('FCM: Failed to fetch token dynamically: $e');
      }
    }

    if (_currentFcmToken == null || _currentFcmToken!.isEmpty) {
      debugPrint('FCM: No token available to register.');
      return false;
    }

    final session = SessionService();
    final isLoggedIn = await session.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint(
        'FCM: User not logged in. Token saved locally for future registration.',
      );
      return false;
    }

    final user = await session.getUser();
    final token = await session.getAccessToken();
    if (token == null || token.isEmpty) return false;

    final currentKey = '${user?.id}_$_currentFcmToken';
    if (!force && _lastRegisteredUserKey == currentKey) {
      debugPrint('FCM: Token already registered for current session ($currentKey). Skipping duplicate request.');
      return true;
    }

    try {
      final deviceType = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'web');
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
          _lastRegisteredUserKey = currentKey;
          debugPrint(
            'FCM: Device token successfully registered with backend via $endpoint',
          );
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
    resetRegistrationCache();

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
          body: jsonEncode({'token': _currentFcmToken}),
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
    final notifType = (data['notification_type'] ?? '')
        .toString()
        .toLowerCase();
    final rawOrderId = data['order_id'] ?? data['orderId'] ?? data['reference_id'] ?? data['id'];

    debugPrint('FCM: Navigating for screen: $screen, type: $notifType, order: $rawOrderId');

    // 1. Direct deep-link to Order Details if payload is an order event with ID
    if (rawOrderId != null &&
        (notifType.contains('order') ||
         screen.contains('order') ||
         notifType.contains('order_placed') ||
         notifType.contains('order_update') ||
         notifType.contains('order_status') ||
         notifType.contains('new_customer_order'))) {
      final orderCode = data['order_code']?.toString() ?? 'ORD-$rawOrderId';
      final dbId = int.tryParse(rawOrderId.toString());
      nav.pushNamed(
        AppRoutes.orderDetail,
        arguments: {
          'orderId': orderCode,
          'dbId': dbId,
        },
      );
      return;
    }

    if (screen.contains('admin') || notifType.contains('order_placed')) {
      nav.pushNamed(AppRoutes.adminDashboard);
    } else if (screen.contains('franchise') || notifType.contains('stock')) {
      nav.pushNamed(AppRoutes.franchiseDashboard);
    } else if (screen.contains('customer') ||
        notifType.contains('order_status')) {
      nav.pushNamed(AppRoutes.customerDashboard);
    } else {
      // Default to root dashboard
      nav.pushNamed(AppRoutes.splash);
    }
  }

  /// Fetch authoritative notifications for current user (strictly role-isolated backend)
  Future<Map<String, dynamic>> getAdminNotifications({int limit = 30}) async {
    return getNotifications(limit: limit);
  }

  /// Unified role-isolated notification fetch
  Future<Map<String, dynamic>> getNotifications({int limit = 30}) async {
    try {
      final session = SessionService();
      final token = await session.getAccessToken();
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/api/accounts/notifications/?limit=$limit',
      );
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to load notifications'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Lightweight indexed unread notification count
  Future<int> getUnreadNotificationCount() async {
    try {
      final session = SessionService();
      final token = await session.getAccessToken();
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/api/accounts/notifications/unread-count/',
      );
      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['unread_count'] is num) {
          return (decoded['unread_count'] as num).toInt();
        }
      }
    } catch (_) {}
    return 0;
  }

  /// Mark notification as read
  Future<Map<String, dynamic>> markAdminNotificationRead(int? id) async {
    try {
      final session = SessionService();
      final token = await session.getAccessToken();
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/api/accounts/notifications/',
      );
      final response = await ApiClient.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
        body: jsonEncode(id != null ? {'id': id} : {}),
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
