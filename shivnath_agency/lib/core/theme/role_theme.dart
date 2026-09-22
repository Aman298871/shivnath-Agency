import 'package:flutter/material.dart';
import 'brand_colors.dart';

/// User-facing profiles supported by Shivnath Agency.
enum AppProfile {
  customer,
  wholesaleDealer,
  admin,
}

/// Dynamic role-based visual styling configuration.
class RoleThemeConfig {
  final AppProfile profile;
  final String roleKey;
  final String displayName;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color secondary;
  final Color accent;
  final Color focusBorder;
  final IconData icon;

  const RoleThemeConfig({
    required this.profile,
    required this.roleKey,
    required this.displayName,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.secondary,
    required this.accent,
    required this.focusBorder,
    required this.icon,
  });

  bool get isCustomer => profile == AppProfile.customer;
  bool get isWholesaleDealer => profile == AppProfile.wholesaleDealer;
  bool get isAdmin => profile == AppProfile.admin;
}

class RoleTheme {
  RoleTheme._();

  // ---------------------------------------------------------------------------
  // Customer Theme: Blue-dominant, fresh water focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig customer = RoleThemeConfig(
    profile: AppProfile.customer,
    roleKey: 'customer',
    displayName: 'Customer',
    primary: BrandColors.primaryBlue,
    primaryDark: BrandColors.blueDark,
    primarySoft: BrandColors.blueSoft,
    secondary: BrandColors.green,
    accent: BrandColors.waterBlue,
    focusBorder: BrandColors.primaryBlue,
    icon: Icons.person_rounded,
  );

  // ---------------------------------------------------------------------------
  // Wholesale Dealer Theme: Green-dominant, growth / commerce focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig wholesaleDealer = RoleThemeConfig(
    profile: AppProfile.wholesaleDealer,
    roleKey: 'franchise', // Preserves internal backend compatibility
    displayName: 'Wholesale Dealer',
    primary: BrandColors.greenDark,
    primaryDark: Color(0xFF047857),
    primarySoft: BrandColors.greenSoft,
    secondary: BrandColors.primaryBlue,
    accent: BrandColors.green,
    focusBorder: BrandColors.greenDark,
    icon: Icons.storefront_rounded,
  );

  // ---------------------------------------------------------------------------
  // Admin Theme: Blue + Red dominant, authoritative governance focus
  // ---------------------------------------------------------------------------
  static const RoleThemeConfig admin = RoleThemeConfig(
    profile: AppProfile.admin,
    roleKey: 'admin',
    displayName: 'Admin',
    primary: BrandColors.primaryBlue,
    primaryDark: BrandColors.blueDark,
    primarySoft: BrandColors.blueSoft,
    secondary: BrandColors.redDark,
    accent: BrandColors.red,
    focusBorder: BrandColors.primaryBlue,
    icon: Icons.admin_panel_settings_rounded,
  );

  /// Resolves the role configuration by role string key or profile enum.
  static RoleThemeConfig fromKey(String? key) {
    if (key == null) return customer;
    final lower = key.toLowerCase();
    if (lower.contains('franchise') || lower.contains('dealer')) {
      return wholesaleDealer;
    }
    if (lower.contains('admin') || lower.contains('plant') || lower.contains('super_admin') || lower.contains('sales_executive')) {
      return admin;
    }
    return customer;
  }
}
