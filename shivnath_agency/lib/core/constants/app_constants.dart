
class AppConstants {
  static const String appName = 'shivnath_agency';

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

  /// Centralized API base URL pointing directly to Render cloud backend.
  static String get apiBaseUrl => 'https://shivnath-agency.onrender.com';
}