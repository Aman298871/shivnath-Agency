import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../firebase_options.dart';
import 'api_client.dart';
import 'session_service.dart';
import '../widgets/app_toast.dart';
import '../../routes/app_routes.dart';

/// Top-level background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  debugPrint(
    'FCM [Background]: Message received ID: ${message.messageId}, Title: ${message.notification?.title}',
  );

  // Security Guard: Check stored role in SharedPreferences to prevent cross-role contamination
  try {
    final prefs = await SharedPreferences.getInstance();
    String role = (prefs.getString(AppConstants.selectedRoleKey) ?? '').toLowerCase();
    if (role.isEmpty) {
      final userRaw = prefs.getString(AppConstants.userSessionKey);
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(userRaw);
          if (decoded is Map && decoded['role'] != null) {
            role = decoded['role'].toString().toLowerCase();
          }
        } catch (_) {}
      }
    }

    final screen = (message.data['screen'] ?? '').toString().toLowerCase();
    final notifType = (message.data['notification_type'] ?? message.data['event_type'] ?? '').toString().toLowerCase();
    final targetRole = (message.data['recipient_role'] ?? message.data['role'] ?? '').toString().toLowerCase();

    final isExplicitAdmin = targetRole.contains('admin') || screen.startsWith('admin') || notifType.startsWith('admin');
    final isExplicitFranchise = targetRole.contains('franchise') || screen.startsWith('franchise') || notifType.startsWith('franchise');
    final isExplicitCustomer = targetRole.contains('customer') || screen.startsWith('customer') || notifType.startsWith('customer');

    // Strict Role Suppression: Return immediately on role mismatch or missing session
    if (isExplicitAdmin && !isExplicitFranchise && !isExplicitCustomer) {
      if (role.isEmpty || (role != 'admin' && role != 'super_admin')) {
        debugPrint('FCM [Background]: Suppressing admin notification - active session is "$role".');
        return;
      }
    } else if (isExplicitFranchise && !isExplicitAdmin && !isExplicitCustomer) {
      if (role.isEmpty || (role != 'franchise' && role != 'dealer')) {
        debugPrint('FCM [Background]: Suppressing franchise notification - active session is "$role".');
        return;
      }
    } else if (isExplicitCustomer && !isExplicitAdmin && !isExplicitFranchise) {
      if (role.isEmpty || role != 'customer') {
        debugPrint('FCM [Background]: Suppressing customer notification - active session is "$role".');
        return;
      }
    }

    // Recipient Identity Verification if specified in payload
    final targetUserId = message.data['recipient_id']?.toString() ?? message.data['user_id']?.toString();
    if (targetUserId != null && targetUserId.isNotEmpty) {
      final userRaw = prefs.getString(AppConstants.userSessionKey);
      if (userRaw != null && userRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(userRaw);
          final currentUserId = decoded['id']?.toString();
          if (currentUserId != null && currentUserId.isNotEmpty && currentUserId != targetUserId) {
            debugPrint('FCM [Background]: Suppressing notification for user $targetUserId - active user is $currentUserId.');
            return;
          }
        } catch (_) {}
      }
    }
  } catch (e) {
    debugPrint('FCM [Background]: Role check error: $e');
  }

  // If payload does not contain system notification block, display via local notifications
  if (message.notification == null && message.data.isNotEmpty) {
    try {
      final title = message.data['title']?.toString() ?? 'Water Wala';
      final body = message.data['body']?.toString() ?? 'New notification received';
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings initAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initSettings =
          InitializationSettings(android: initAndroid);
      await flutterLocalNotificationsPlugin.initialize(initSettings);

      final androidDetails = AndroidNotificationDetails(
        NotificationService.channelId,
        NotificationService.channelName,
        channelDescription: NotificationService.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        channelShowBadge: true,
        visibility: NotificationVisibility.private,
      );
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        NotificationDetails(android: androidDetails),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('FCM [Background]: Local notification error: $e');
    }
  }
}

class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static bool _backgroundHandlerRegistered = false;
  static bool _isRegisteringDeviceToken = false;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  static const String _keyFcmLastAckToken = 'fcm_last_ack_token';
  static const String _keyFcmLastAckUserId = 'fcm_last_ack_user_id';
  static const String _keyFcmPendingRegistration = 'fcm_pending_registration';
  static const String _keyFcmPendingToken = 'fcm_pending_token';
  static const String _keyFcmRetryCount = 'fcm_retry_count';

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('FCM: App resumed. Checking token sync and notification permissions...');
      _checkAndRecoverOnResume();
    }
  }

  Future<void> _checkAndRecoverOnResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPending = prefs.getBool(_keyFcmPendingRegistration) ?? false;

      final settings = await _fcm.getNotificationSettings();
      debugPrint('FCM [Resume]: Authorization status: ${settings.authorizationStatus}');

      if (isPending) {
        debugPrint('FCM [Resume]: Pending token registration detected in storage. Triggering sync...');
        await registerDeviceTokenWithBackend();
        return;
      }

      final session = SessionService();
      final user = await session.getUser();
      final lastAckUserId = prefs.getString(_keyFcmLastAckUserId);
      final lastAckToken = prefs.getString(_keyFcmLastAckToken);

      final currentToken = _currentFcmToken ?? await _fcm.getToken();
      if (user != null && currentToken != null && currentToken.isNotEmpty) {
        if (lastAckUserId != user.id.toString() || lastAckToken != currentToken) {
          debugPrint('FCM [Resume]: User or token mismatch detected. Triggering re-registration.');
          await registerDeviceTokenWithBackend(force: true);
        }
      }
    } catch (e) {
      debugPrint('FCM [Resume]: Verification failed: $e');
    }
  }

  /// Initialize Firebase Cloud Messaging, local notification channels & listeners
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_isInitialized) return;
    if (navKey != null) {
      navigatorKey = navKey;
    }
    WidgetsBinding.instance.addObserver(this);

    try {
      // 1. Initialize Firebase App (guard against duplicate default app)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      debugPrint('FCM: Firebase app ready.');

      AndroidFlutterLocalNotificationsPlugin? androidPlugin;
      if (!kIsWeb) {
        // 2. Setup Android Notification Channel
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        androidPlugin = _localNotifications
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
      }

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

      // 7. Background & Killed state handling (native only)
      if (!kIsWeb && !_backgroundHandlerRegistered) {
        try {
          FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
          _backgroundHandlerRegistered = true;
        } catch (_) {}
      }

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

      // 8. Retrieve FCM Token (with iOS APNs readiness check)
      try {
        if (!kIsWeb && Platform.isIOS) {
          String? apnsToken = await _fcm.getAPNSToken();
          if (apnsToken == null) {
            // Wait briefly for APNs registration to complete on iOS
            await Future.delayed(const Duration(milliseconds: 1500));
            apnsToken = await _fcm.getAPNSToken();
          }
          debugPrint('FCM: iOS APNs Token: $apnsToken');
        }

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
    // Security Guard: Role-check against current authenticated session
    final session = SessionService();
    final user = await session.getUser();
    String userRole = (user?.role ?? '').toLowerCase();
    if (userRole.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      userRole = (prefs.getString(AppConstants.selectedRoleKey) ?? '').toLowerCase();
    }

    final screen = (message.data['screen'] ?? '').toString().toLowerCase();
    final notifType = (message.data['notification_type'] ?? message.data['event_type'] ?? '').toString().toLowerCase();
    final targetRole = (message.data['recipient_role'] ?? message.data['role'] ?? '').toString().toLowerCase();

    final isExplicitAdmin = targetRole.contains('admin') || screen.startsWith('admin') || notifType.startsWith('admin');
    final isExplicitFranchise = targetRole.contains('franchise') || screen.startsWith('franchise') || notifType.startsWith('franchise');
    final isExplicitCustomer = targetRole.contains('customer') || screen.startsWith('customer') || notifType.startsWith('customer');

    if (isExplicitAdmin && !isExplicitFranchise && !isExplicitCustomer) {
      if (userRole.isEmpty || (userRole != 'admin' && userRole != 'super_admin')) {
        debugPrint('FCM: Received Admin alert for non-admin session ($userRole). Suppressing notification for security.');
        return;
      }
    } else if (isExplicitFranchise && !isExplicitAdmin && !isExplicitCustomer) {
      if (userRole.isEmpty || (userRole != 'franchise' && userRole != 'dealer')) {
        debugPrint('FCM: Received Franchise alert for non-franchise session ($userRole). Suppressing notification for security.');
        return;
      }
    } else if (isExplicitCustomer && !isExplicitAdmin && !isExplicitFranchise) {
      if (userRole.isEmpty || userRole != 'customer') {
        debugPrint('FCM: Received Customer alert for non-customer session ($userRole). Suppressing notification for security.');
        return;
      }
    }

    final targetUserId = message.data['recipient_id']?.toString() ?? message.data['user_id']?.toString();
    if (targetUserId != null && targetUserId.isNotEmpty && user != null) {
      if (user.id.toString() != targetUserId) {
        debugPrint('FCM: Received alert for user $targetUserId while session is ${user.id}. Suppressing notification.');
        return;
      }
    }

    final title =
        message.notification?.title ??
        message.data['title'] ??
        AppConstants.appName;
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
        priority: Priority.max,
        ticker: title,
        category: AndroidNotificationCategory.status,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
        channelShowBadge: true,
        visibility: NotificationVisibility.private,
        fullScreenIntent: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    if (!kIsWeb) {
      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    }

    // Show actionable foreground dialog/banner if context is ready
    _showForegroundInAppAlert(title, body, message.data);
  }

  void _showForegroundInAppAlert(String title, String body, Map<String, dynamic> data) {
    final ctx = navigatorKey?.currentContext;
    final messenger = rootScaffoldMessengerKey.currentState ??
        (ctx != null ? ScaffoldMessenger.maybeOf(ctx) : null);
    if (messenger == null) return;

    final rawOrderId = data['order_id'] ?? data['orderId'] ?? data['reference_id'] ?? data['id'];
    final notifType = (data['notification_type'] ?? data['event_type'] ?? '').toString().toLowerCase();
    final isOrderEvent = rawOrderId != null && (notifType.contains('order') || data.containsKey('order_code') || data.containsKey('order_id'));

    messenger.hideCurrentMaterialBanner();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 8,
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
                messenger.hideCurrentMaterialBanner();
                handleNotificationNavigation(data);
              },
              child: const Text(
                'VIEW ORDER',
                style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w800),
              ),
            ),
          TextButton(
            onPressed: () {
              messenger.hideCurrentMaterialBanner();
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
        messenger.hideCurrentMaterialBanner();
      } catch (_) {}
    });
  }

  String? _lastRegisteredUserKey;

  /// Clears token registration cache on logout / user switch
  void resetRegistrationCache() {
    _lastRegisteredUserKey = null;
  }

  /// Register FCM Token with Backend for the logged-in user with persistent self-healing state
  Future<bool> registerDeviceTokenWithBackend({bool force = false}) async {
    if (_isRegisteringDeviceToken) {
      debugPrint('FCM: Token registration already in progress. Skipping concurrent request.');
      return false;
    }
    _isRegisteringDeviceToken = true;

    try {
      final prefs = await SharedPreferences.getInstance();

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
          'FCM: User not logged in. Token marked pending in persistent storage.',
        );
        await prefs.setBool(_keyFcmPendingRegistration, true);
        await prefs.setString(_keyFcmPendingToken, _currentFcmToken!);
        return false;
      }

      final user = await session.getUser();
      var token = await session.getAccessToken();
      if (token == null || token.isEmpty) {
        await prefs.setBool(_keyFcmPendingRegistration, true);
        await prefs.setString(_keyFcmPendingToken, _currentFcmToken!);
        return false;
      }

      final currentKey = '${user?.id}_$_currentFcmToken';
      final lastAckToken = prefs.getString(_keyFcmLastAckToken);
      final lastAckUserId = prefs.getString(_keyFcmLastAckUserId);
      final isPending = prefs.getBool(_keyFcmPendingRegistration) ?? false;

      if (!force && !isPending && _lastRegisteredUserKey == currentKey && lastAckUserId == user?.id?.toString() && lastAckToken == _currentFcmToken) {
        debugPrint('FCM: Token already verified and acknowledged for current session ($currentKey). Skipping duplicate request.');
        return true;
      }

      // Mark registration as pending while in-flight
      await prefs.setBool(_keyFcmPendingRegistration, true);
      await prefs.setString(_keyFcmPendingToken, _currentFcmToken!);

      final deviceType = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'web');
      final deviceName = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim();
      final appVersion = AppConstants.appVersion;

      final payload = jsonEncode({
        'token': _currentFcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
        'app_version': appVersion,
      });

      final candidates = [
        '${AppConstants.apiBaseUrl}/api/notifications/register-device/',
        '${AppConstants.apiBaseUrl}/api/auth/notifications/register-device/',
      ];

      bool registrationSuccess = false;
      for (final endpoint in candidates) {
        try {
          final url = Uri.parse(endpoint);
          var response = await ApiClient.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: payload,
          );

          // If access token expired (401), attempt JWT refresh and retry registration exactly once
          if (response.statusCode == 401) {
            debugPrint('FCM: Token registration returned 401 Unauthorized. Attempting session token refresh...');
            final refreshedAccess = await session.refreshAccessToken();
            if (refreshedAccess != null && refreshedAccess.isNotEmpty) {
              token = refreshedAccess;
              response = await ApiClient.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
                body: payload,
              );
            }
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            registrationSuccess = true;
            _lastRegisteredUserKey = currentKey;
            debugPrint(
              'FCM: Device token successfully registered with backend via $endpoint',
            );
            break;
          } else {
            debugPrint('FCM: Attempt via $endpoint gave ${response.statusCode}');
          }
        } catch (netEx) {
          debugPrint('FCM: Endpoint $endpoint connection error: $netEx');
        }
      }

      if (registrationSuccess) {
        // Persist successful ACK state
        await prefs.setString(_keyFcmLastAckToken, _currentFcmToken!);
        await prefs.setString(_keyFcmLastAckUserId, user?.id?.toString() ?? '');
        await prefs.setBool(_keyFcmPendingRegistration, false);
        await prefs.setInt(_keyFcmRetryCount, 0);
        _retryAttempt = 0;
        _retryTimer?.cancel();
        _retryTimer = null;
        return true;
      } else {
        // Registration failed: schedule bounded exponential backoff retry with jitter
        _scheduleRetryRegistration();
        return false;
      }
    } catch (e) {
      debugPrint('FCM: Exception registering device token: $e');
      _scheduleRetryRegistration();
      return false;
    } finally {
      _isRegisteringDeviceToken = false;
    }
  }

  void _scheduleRetryRegistration() {
    _retryTimer?.cancel();
    _retryAttempt++;
    final baseDelay = min(300, (1 << min(_retryAttempt, 7)) * 3);
    final jitter = Random().nextInt(4);
    final delaySeconds = baseDelay + jitter;

    debugPrint('FCM: Registration failed. Scheduled retry in $delaySeconds seconds (attempt $_retryAttempt)...');
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      registerDeviceTokenWithBackend();
    });
  }

  /// Unregister FCM Token when user logs out
  Future<void> unregisterDeviceTokenWithBackend() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    resetRegistrationCache();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFcmLastAckToken);
      await prefs.remove(_keyFcmLastAckUserId);
      await prefs.remove(_keyFcmPendingRegistration);
      await prefs.remove(_keyFcmPendingToken);
      await prefs.remove(_keyFcmRetryCount);
    } catch (_) {}

    final fcmTokenToUnregister = _currentFcmToken ?? await _fcm.getToken();
    if (fcmTokenToUnregister != null && fcmTokenToUnregister.isNotEmpty) {
      final session = SessionService();
      final token = await session.getAccessToken();

      final candidates = [
        '${AppConstants.apiBaseUrl}/api/notifications/unregister-device/',
        '${AppConstants.apiBaseUrl}/api/auth/notifications/unregister-device/',
      ];

      final Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      for (final endpoint in candidates) {
        try {
          final url = Uri.parse(endpoint);
          final response = await ApiClient.post(
            url,
            headers: headers,
            body: jsonEncode({'token': fcmTokenToUnregister}),
          );
          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('FCM: Device token unregistered successfully via $endpoint.');
            break;
          }
        } catch (_) {}
      }
    }

    try {
      await _fcm.deleteToken();
    } catch (_) {}
    _currentFcmToken = null;
  }

  /// Smart deep-linking / navigation based on push payload with strict role authorization
  Future<void> handleNotificationNavigation(Map<String, dynamic> data) async {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('FCM: Navigator state is not ready.');
      return;
    }

    final session = SessionService();
    final user = await session.getUser();
    final userRole = (user?.role ?? '').toLowerCase();

    final screen = (data['screen'] ?? '').toString().toLowerCase();
    final notifType = (data['notification_type'] ?? '')
        .toString()
        .toLowerCase();
    final rawOrderId = data['order_id'] ?? data['orderId'] ?? data['reference_id'] ?? data['id'];

    debugPrint('FCM: Navigating for userRole: $userRole, screen: $screen, type: $notifType, order: $rawOrderId');

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
      if (userRole == 'admin' || userRole == 'super_admin') {
        nav.pushNamed(AppRoutes.adminDashboard);
      } else {
        nav.pushNamed(AppRoutes.customerDashboard);
      }
    } else if (screen.contains('franchise') || notifType.contains('stock')) {
      if (userRole == 'franchise' || userRole == 'dealer') {
        nav.pushNamed(AppRoutes.franchiseDashboard);
      } else {
        nav.pushNamed(AppRoutes.customerDashboard);
      }
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
