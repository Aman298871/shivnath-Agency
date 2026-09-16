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

    // Production Render Cloud Backend
    return 'https://shivnath-agency.onrender.com';
  }
}