import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';
import '../../models/user_model.dart';
import 'notification_service.dart';

class SessionService {
  static const String _userKey = 'logged_in_user';
  static const String _roleKey = 'selected_role';

  static const String _accessTokenKey =
      'access_token';

  static const String _refreshTokenKey =
      'refresh_token';

  Future<void> saveUser(UserModel user) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _userKey,
      jsonEncode(user.toJson()),
    );
  }

  Future<UserModel?> getUser() async {
    final prefs =
        await SharedPreferences.getInstance();

    final value = prefs.getString(_userKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);

      if (decoded is Map<String, dynamic>) {
        return UserModel.fromJson(decoded);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> getCurrentUser() async => getUser();

  Future<void> saveRole(String role) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _roleKey,
      role,
    );
  }

  Future<String?> getRole() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_roleKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      _accessTokenKey,
      accessToken,
    );

    await prefs.setString(
      _refreshTokenKey,
      refreshToken,
    );
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
  }

  Future<void> clearSession() => logout();

  Future<String?> getAccessToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs =
        await SharedPreferences.getInstance();

    return prefs.getString(_refreshTokenKey);
  }

  Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    try {
      final response = await ApiClient.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/auth/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['access'] != null) {
          final newAccess = data['access'].toString();
          final newRefresh = data['refresh']?.toString() ?? refreshToken;
          await saveTokens(accessToken: newAccess, refreshToken: newRefresh);
          return newAccess;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final user = await getUser();

    return token != null &&
        token.isNotEmpty &&
        user != null;
  }

  static int _sessionEpoch = 0;
  static int get currentSessionEpoch => _sessionEpoch;
  static bool isSessionActive(int epoch) => epoch == _sessionEpoch;

  Future<void> logout() async {
    _sessionEpoch++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_roleKey);
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
    } catch (_) {}

    try {
      NotificationService().resetRegistrationCache();
    } catch (_) {}

    try {
      await NotificationService()
          .unregisterDeviceTokenWithBackend()
          .timeout(const Duration(milliseconds: 1000), onTimeout: () => false);
    } catch (_) {}
  }
}