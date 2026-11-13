
import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  static const String appName = 'Water Wala';
  static const String brandShortName = 'Water Wala';
  static const String brandMainTitle = 'WATER WALA — मुख्य ब्रांड';
  static const String brandSubtitle = 'ऐप, ऑनलाइन ऑर्डर और होम डिलीवरी';
  static const String appTagline = 'पानी चाहिए? Water Wala बुलाइए!';
  static const String appVersion = '1.0.1+7';

  static const String customerRole = 'customer';
  static const String franchiseRole = 'franchise';
  static const String adminRole = 'admin';
  static const String superAdminRole = 'super_admin';
  static const String salesExecutiveRole = 'sales_executive';

  static const String dealerDisplayName = 'Wholesale Dealer';

  static String getRoleDisplayName(String? role) {
    switch (role?.toLowerCase()) {
      case superAdminRole:
        return 'Super Admin';
      case adminRole:
        return 'Admin';
      case salesExecutiveRole:
        return 'Sales Executive';
      case franchiseRole:
        return dealerDisplayName;
      case customerRole:
        return 'Customer';
      default:
        return role ?? '';
    }
  }

  static const String userSessionKey = 'logged_in_user';
  static const String selectedRoleKey = 'selected_role';
  static const String customBaseUrlKey = 'custom_api_base_url';

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envName = String.fromEnvironment('APP_ENV', defaultValue: '');

  static String? _customBaseUrl;

  /// Loads saved custom base URL from persistent storage on startup.
  /// Automatically purges loopback/localhost addresses (127.0.0.1, localhost, 10.0.2.2)
  /// so physical devices never get trapped connecting to offline local PC databases.
  static Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(customBaseUrlKey);
      if (saved != null && saved.trim().isNotEmpty) {
        final clean = saved.trim().replaceAll(RegExp(r'/+$'), '');
        final isLoopback = clean.contains('127.0.0.1') ||
            clean.contains('localhost') ||
            clean.contains('10.0.2.2');
        if (isLoopback) {
          await prefs.remove(customBaseUrlKey);
          _customBaseUrl = null;
        } else {
          _customBaseUrl = clean;
        }
      }
    } catch (_) {}
  }

  /// Sets custom base URL in memory
  static void setCustomBaseUrl(String? url) {
    if (url != null && url.trim().isNotEmpty) {
      _customBaseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    } else {
      _customBaseUrl = null;
    }
  }

  /// Persists custom base URL across app restarts
  static Future<void> saveCustomBaseUrl(String? url) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url != null && url.trim().isNotEmpty) {
        final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
        _customBaseUrl = clean;
        await prefs.setString(customBaseUrlKey, clean);
      } else {
        _customBaseUrl = null;
        await prefs.remove(customBaseUrlKey);
      }
    } catch (_) {
      setCustomBaseUrl(url);
    }
  }

  /// Centralized API base URL. Defaults to Render production, configurable via runtime override or --dart-define=API_BASE_URL=...
  static String get apiBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl;
    }
    return 'https://shivnath-agency.onrender.com';
  }

  /// Indicates if this build is targeting a test or development backend
  static bool get isTestMode {
    if (_envName.toUpperCase() == 'TEST') return true;
    if (_envBaseUrl.isNotEmpty && !_envBaseUrl.contains('onrender.com')) return true;
    return false;
  }

  static String get environmentName => isTestMode ? 'TEST' : 'PRODUCTION';

  /// Official Razorpay Key ID for payments & checkout
  static const String razorpayKeyId = 'rzp_live_Tnhqo3i0SyYYdf';
}