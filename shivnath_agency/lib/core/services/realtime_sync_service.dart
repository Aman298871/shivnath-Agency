import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'auth_service.dart';
import 'session_service.dart';
import '../../models/user_model.dart';

/// RealTimeSyncService provides two-way live event synchronization
/// between the Flutter client, the Django backend, and the Web Admin Portal.
///
/// It queries `/api/events/latest/` with automatic reconciliation,
/// broadcasts events to screens, and instantly enforces permission revocation
/// or account deactivation.
class RealTimeSyncService {
  static final RealTimeSyncService _instance = RealTimeSyncService._internal();
  factory RealTimeSyncService() => _instance;
  RealTimeSyncService._internal();

  Timer? _pollingTimer;
  bool _isPolling = false;
  String? _lastEventId;
  DateTime? _lastPollTime;

  DateTime? get lastPollTime => _lastPollTime;

  final StreamController<Map<String, dynamic>> _eventStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventStreamController.stream;

  final List<VoidCallback> _onAccountDeactivatedListeners = [];
  final List<void Function(UserModel)> _onProfileUpdatedListeners = [];

  void addDeactivatedListener(VoidCallback listener) {
    _onAccountDeactivatedListeners.add(listener);
  }

  void removeDeactivatedListener(VoidCallback listener) {
    _onAccountDeactivatedListeners.remove(listener);
  }

  void addProfileUpdatedListener(void Function(UserModel) listener) {
    _onProfileUpdatedListeners.add(listener);
  }

  void removeProfileUpdatedListener(void Function(UserModel) listener) {
    _onProfileUpdatedListeners.remove(listener);
  }

  /// Start polling for real-time events across mobile and web admin
  void startSync({Duration interval = const Duration(seconds: 10)}) {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      return;
    }
    _pollEvents(); // Immediate initial poll
    _pollingTimer = Timer.periodic(interval, (_) => _pollEvents());
  }

  /// Stop polling (e.g. on logout or app lifecycle background)
  void stopSync() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _lastEventId = null;
  }

  /// Authoritative reconciliation poll
  Future<void> reconcileNow() async {
    await _pollEvents();
  }

  Future<void> _pollEvents() async {
    if (_isPolling) return;
    _isPolling = true;

    try {
      final token = await SessionService().getAccessToken();
      if (token == null || token.isEmpty) {
        _isPolling = false;
        return;
      }

      final queryParams = <String, String>{
        'limit': '50',
      };
      if (_lastEventId != null && _lastEventId!.isNotEmpty) {
        queryParams['since_id'] = _lastEventId!;
      }

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/events/latest/')
          .replace(queryParameters: queryParams);

      final response = await ApiClient.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token expired or user deactivated on backend
        final decoded = _safeDecode(response.body);
        final msg = decoded['message'] ?? decoded['error'] ?? '';
        if (msg.toString().toLowerCase().contains('inactive') ||
            msg.toString().toLowerCase().contains('deactivated')) {
          _handleAccountDeactivation();
        }
        _isPolling = false;
        return;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _safeDecode(response.body);
        if (data['success'] == true) {
          final List events = data['events'] as List? ?? [];
          final String? latestId = data['latest_id']?.toString() ?? data['latest_event_id']?.toString();
          if (latestId != null && latestId.isNotEmpty) {
            _lastEventId = latestId;
          }

          final currentUser = await SessionService().getUser();
          final currentUserId = currentUser != null ? int.tryParse(currentUser.id) : null;

          for (final rawEvent in events) {
            if (rawEvent is Map<String, dynamic>) {
              _eventStreamController.add(rawEvent);

              final eventType = rawEvent['type'] ?? rawEvent['event_type'] ?? '';
              final payload = rawEvent['payload'] is Map<String, dynamic>
                  ? rawEvent['payload'] as Map<String, dynamic>
                  : <String, dynamic>{};

              // 1. Immediate Account Deactivation Check
              if (eventType == 'employee.disabled' || eventType == 'user.deactivated') {
                final targetUserId = payload['user_id'];
                if (currentUserId != null && targetUserId == currentUserId) {
                  _handleAccountDeactivation();
                }
              }

              // 2. Immediate Permission Update Re-fetch
              if (eventType == 'employee.updated') {
                final targetUserId = payload['user_id'];
                if (currentUserId != null && targetUserId == currentUserId) {
                  await _refreshCurrentUserProfile();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('RealTimeSyncService error (non-fatal, will retry): $e');
    } finally {
      _lastPollTime = DateTime.now();
      _isPolling = false;
    }
  }

  Future<void> _refreshCurrentUserProfile() async {
    try {
      final res = await AuthService().getCurrentUser();
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final updatedUser = UserModel.fromJson(res['data']);
        await SessionService().saveUser(updatedUser);
        for (final listener in _onProfileUpdatedListeners) {
          listener(updatedUser);
        }
      }
    } catch (_) {}
  }

  void _handleAccountDeactivation() {
    SessionService().clearSession();
    for (final listener in _onAccountDeactivatedListeners) {
      listener();
    }
  }

  Map<String, dynamic> _safeDecode(String body) {
    try {
      final d = jsonDecode(body);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
