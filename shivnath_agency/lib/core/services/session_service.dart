import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';

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

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    final user = await getUser();

    return token != null &&
        token.isNotEmpty &&
        user != null;
  }

  Future<void> logout() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(_userKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}