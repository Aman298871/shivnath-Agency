
class AppConstants {
  static const String appName = 'Water Wala';
  static const String brandShortName = 'Water Wala';
  static const String brandMainTitle = 'WATER WALA — मुख्य ब्रांड';
  static const String brandSubtitle = 'ऐप, ऑनलाइन ऑर्डर और होम डिलीवरी';
  static const String appTagline = 'पानी चाहिए? Water Wala बुलाइए!';

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

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envName = String.fromEnvironment('APP_ENV', defaultValue: '');

  /// Centralized API base URL. Defaults to Render production, configurable via --dart-define=API_BASE_URL=...
  static String get apiBaseUrl {
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