import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String appName = 'shivnath_agency';

  static const String customerRole = 'customer';
  static const String franchiseRole = 'franchise';
  static const String adminRole = 'admin';

  static const String userSessionKey = 'logged_in_user';
  static const String selectedRoleKey = 'selected_role';

  /// Centralized API base URL with smart local environment detection.
  static String get apiBaseUrl {
    const definedBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (definedBaseUrl.isNotEmpty) {
      return definedBaseUrl;
    }

    const definedUrl = String.fromEnvironment('API_URL');
    if (definedUrl.isNotEmpty) {
      return definedUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    // In development over USB with 'adb reverse tcp:8000 tcp:8000',
    // Android connects to the local development machine via 127.0.0.1:8000.
    return 'http://127.0.0.1:8000';
  }
}