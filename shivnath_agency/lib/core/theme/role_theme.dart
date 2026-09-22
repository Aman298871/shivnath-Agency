import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'brand_colors.dart';
import 'app_theme.dart';

/// User-facing profiles supported by Shivnath Agency.
enum AppProfile {
  customer,
  franchise,
  admin;

  // Backward compatibility alias
  static const AppProfile wholesaleDealer = AppProfile.franchise;
}

/// Dynamic role-based visual styling configuration.
class RoleThemeConfig {
  final AppProfile profile;
  final String roleKey;
  final String displayName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color textColor;
  final Color accentColor;
  final Color selectedColor;
  final Color buttonColor;
  final Color iconColor;
  final Color borderColor;
  final Color primaryDark;
  final Color primarySoft;
  final Color focusBorder;
  final IconData icon;

  const RoleThemeConfig({
    required this.profile,
    required this.roleKey,
    required this.displayName,
    required this.primaryColor,
    required this.secondaryColor,
    this.backgroundColor = BrandColors.white,
    this.surfaceColor = BrandColors.white,
    this.textColor = BrandColors.textPrimary,
    required this.accentColor,
    required this.selectedColor,
    required this.buttonColor,
    required this.iconColor,
    this.borderColor = BrandColors.border,
    required this.primaryDark,
    required this.primarySoft,
    required this.focusBorder,
    required this.icon,
  });

  // Convenience aliases for backward compatibility
  Color get primary => primaryColor;
  Color get secondary => secondaryColor;
  Color get accent => accentColor;

  bool get isCustomer => profile == AppProfile.customer;
  bool get isFranchise => profile == AppProfile.franchise;
  bool get isWholesaleDealer => profile == AppProfile.franchise;
  bool get isAdmin => profile == AppProfile.admin;
}

/// Centralized RoleTheme definitions for Customer (Blue), Franchise (Green), Admin (Red)
class RoleTheme {
  RoleTheme._();

  // ---------------------------------------------------------------------------
  // Customer Theme: Blue-dominant, fresh water focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig customer = RoleThemeConfig(
    profile: AppProfile.customer,
    roleKey: 'customer',
    displayName: 'Customer',
    primaryColor: BrandColors.primaryBlue,
    secondaryColor: BrandColors.blueSoft,
    backgroundColor: BrandColors.white,
    surfaceColor: BrandColors.white,
    textColor: BrandColors.textPrimary,
    accentColor: BrandColors.waterBlue,
    selectedColor: BrandColors.primaryBlue,
    buttonColor: BrandColors.primaryBlue,
    iconColor: BrandColors.primaryBlue,
    borderColor: BrandColors.border,
    primaryDark: BrandColors.blueDark,
    primarySoft: BrandColors.blueSoft,
    focusBorder: BrandColors.primaryBlue,
    icon: Icons.person_rounded,
  );

  static const RoleThemeConfig customerTheme = customer;

  // ---------------------------------------------------------------------------
  // Franchise Theme: Green-dominant, growth / commerce focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig franchise = RoleThemeConfig(
    profile: AppProfile.franchise,
    roleKey: 'franchise',
    displayName: 'Franchise',
    primaryColor: BrandColors.greenDark,
    secondaryColor: BrandColors.greenSoft,
    backgroundColor: BrandColors.white,
    surfaceColor: BrandColors.white,
    textColor: BrandColors.textPrimary,
    accentColor: BrandColors.green,
    selectedColor: BrandColors.greenDark,
    buttonColor: BrandColors.greenDark,
    iconColor: BrandColors.greenDark,
    borderColor: BrandColors.border,
    primaryDark: Color(0xFF047857),
    primarySoft: BrandColors.greenSoft,
    focusBorder: BrandColors.greenDark,
    icon: Icons.storefront_rounded,
  );

  static const RoleThemeConfig franchiseTheme = franchise;
  static const RoleThemeConfig wholesaleDealer = franchise;

  // ---------------------------------------------------------------------------
  // Admin Theme: Red-dominant, authoritative governance & management focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig admin = RoleThemeConfig(
    profile: AppProfile.admin,
    roleKey: 'admin',
    displayName: 'Admin',
    primaryColor: BrandColors.redDark,
    secondaryColor: BrandColors.redSoft,
    backgroundColor: BrandColors.white,
    surfaceColor: BrandColors.white,
    textColor: BrandColors.textPrimary,
    accentColor: BrandColors.red,
    selectedColor: BrandColors.redDark,
    buttonColor: BrandColors.redDark,
    iconColor: BrandColors.redDark,
    borderColor: BrandColors.border,
    primaryDark: Color(0xFFB91C1C),
    primarySoft: BrandColors.redSoft,
    focusBorder: BrandColors.redDark,
    icon: Icons.admin_panel_settings_rounded,
  );

  static const RoleThemeConfig adminTheme = admin;

  // ---------------------------------------------------------------------------
  // Shared Brand Accent: Yellow for alerts, badges, warnings, highlights
  // ---------------------------------------------------------------------------
  static const Color yellowAccent = BrandColors.yellow;
  static const Color yellowDark = BrandColors.yellowDark;
  static const Color yellowSoft = BrandColors.yellowSoft;

  /// Resolves the role configuration by role string key or profile enum.
  static RoleThemeConfig fromKey(String? key) {
    if (key == null) return customer;
    final lower = key.toLowerCase();
    if (lower.contains('franchise') || lower.contains('dealer')) {
      return franchise;
    }
    if (lower.contains('admin') ||
        lower.contains('plant') ||
        lower.contains('super_admin') ||
        lower.contains('sales_executive')) {
      return admin;
    }
    return customer;
  }

  /// Convenience lookup from BuildContext using RoleThemeProvider
  static RoleThemeConfig of(BuildContext context) {
    try {
      final provider = Provider.of<RoleThemeProvider>(context, listen: true);
      return provider.currentConfig;
    } catch (_) {
      return customer;
    }
  }
}

/// Centralized state provider that manages active role theme across the entire application.
class RoleThemeProvider extends ChangeNotifier {
  RoleThemeConfig _currentConfig = RoleTheme.customer;

  RoleThemeConfig get currentConfig => _currentConfig;

  ThemeData get currentThemeData => AppTheme.getThemeForRoleConfig(_currentConfig);

  void setRole(String? roleKey) {
    final newConfig = RoleTheme.fromKey(roleKey);
    if (_currentConfig != newConfig) {
      _currentConfig = newConfig;
      notifyListeners();
    }
  }

  void setConfig(RoleThemeConfig config) {
    if (_currentConfig != config) {
      _currentConfig = config;
      notifyListeners();
    }
  }
}
