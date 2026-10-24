import 'package:flutter/material.dart';
import 'order_status_style.dart';

/// Centralized Brand Colors and Semantic Tokens for Shivnath Agency.
///
/// Brand Identity:
/// - Blue: Primary brand identity, Customer theme, active tabs, main metrics.
/// - Green: Wholesale Dealer identity, success, approved, available stock.
/// - Yellow: Pending, attention, warnings, upcoming follow-up.
/// - Red: Critical alerts, errors, expiry, cancelled, dangerous actions.
/// - White: App background, clean card surfaces, light UI.
class BrandColors {
  BrandColors._();

  // ---------------------------------------------------------------------------
  // Core Brand Colors
  // ---------------------------------------------------------------------------
  static const Color primaryBlue = Color(0xFF0284C7); // Sky Blue 600
  static const Color waterBlue = Color(0xFF0EA5E9);   // Sky Blue 500
  static const Color blueDark = Color(0xFF0369A1);    // Sky Blue 700
  static const Color blueSoft = Color(0xFFE0F2FE);    // Sky Blue 100
  static const Color blueLight = Color(0xFFF0F9FF);   // Sky Blue 50

  static const Color green = Color(0xFF10B981);       // Emerald 500
  static const Color greenDark = Color(0xFF059669);   // Emerald 600
  static const Color greenSoft = Color(0xFFECFDF5);   // Emerald 50
  static const Color greenLight = Color(0xFFF0FDF4);  // Green 50

  static const Color yellow = Color(0xFFF59E0B);      // Amber 500
  static const Color yellowDark = Color(0xFFD97706);  // Amber 600
  static const Color yellowSoft = Color(0xFFFFFBEB);  // Amber 50

  static const Color red = Color(0xFFEF4444);         // Red 500
  static const Color redDark = Color(0xFFDC2626);     // Red 600
  static const Color redSoft = Color(0xFFFEF2F2);     // Red 50

  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);  // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100

  // Neutral / Typography
  static const Color textPrimary = Color(0xFF0F172A);  // Slate 900
  static const Color textSecondary = Color(0xFF64748B);// Slate 500
  static const Color textMuted = Color(0xFF94A3B8);    // Slate 400
  static const Color border = Color(0xFFE2E8F0);       // Slate 200
  static const Color borderDark = Color(0xFFCBD5E1);   // Slate 300

  // ---------------------------------------------------------------------------
  // Semantic Tokens
  // ---------------------------------------------------------------------------
  static const Color success = green;
  static const Color successDark = greenDark;
  static const Color successSoft = greenSoft;

  static const Color warning = yellow;
  static const Color warningDark = yellowDark;
  static const Color warningSoft = yellowSoft;

  static const Color error = red;
  static const Color errorDark = redDark;
  static const Color errorSoft = redSoft;

  static const Color danger = red;
  static const Color dangerDark = redDark;
  static const Color dangerLight = redSoft;
  static const Color dangerSoft = redSoft;

  static const Color info = primaryBlue;
  static const Color infoSoft = blueSoft;

  // ---------------------------------------------------------------------------
  // Inventory Colors (Section 15)
  // ---------------------------------------------------------------------------
  static const Color inventoryAvailable = green;
  static const Color inventoryNormal = primaryBlue;
  static const Color inventoryLow = yellow;
  static const Color inventoryCritical = red;

  static Color getInventoryColor(String? status, {int? stockCount, int? minThreshold}) {
    if (status != null) {
      final s = status.toLowerCase();
      if (s.contains('crit') || s.contains('expir') || s.contains('out')) return inventoryCritical;
      if (s.contains('low')) return inventoryLow;
      if (s.contains('avail') || s.contains('good') || s.contains('in stock')) return inventoryAvailable;
    }
    if (stockCount != null && minThreshold != null) {
      if (stockCount <= 0) return inventoryCritical;
      if (stockCount <= minThreshold) return inventoryLow;
      return inventoryAvailable;
    }
    return inventoryNormal;
  }

  // ---------------------------------------------------------------------------
  // Expiry Alert System Colors (Section 16)
  // ---------------------------------------------------------------------------
  static Color getExpiryColor(int daysUntilExpiry) {
    if (daysUntilExpiry <= 0) return redDark;       // 0 or expired: critical
    if (daysUntilExpiry <= 3) return red;           // 3 days: red warning
    if (daysUntilExpiry <= 7) return const Color(0xFFEA580C); // 7 days: orange warning
    if (daysUntilExpiry <= 15) return yellowDark;   // 15 days: yellow
    return yellow;                                  // 30 days: soft warning
  }

  static Color getExpirySoftBackground(int daysUntilExpiry) {
    if (daysUntilExpiry <= 3) return redSoft;
    if (daysUntilExpiry <= 7) return const Color(0xFFFFF7ED);
    return yellowSoft;
  }

  // ---------------------------------------------------------------------------
  // Order Status Colors (Section 17) - Delegated to OrderStatusStyle
  // ---------------------------------------------------------------------------
  static Color getOrderStatusColor(String? status) {
    return OrderStatusStyle.getColor(status);
  }

  static Color getOrderStatusSoftBackground(String? status) {
    return OrderStatusStyle.getSoftBackground(status);
  }

  // ---------------------------------------------------------------------------
  // CRM Lead Colors (Section 18)
  // ---------------------------------------------------------------------------
  static Color getLeadStatusColor(String? status) {
    final s = status?.toUpperCase() ?? '';
    switch (s) {
      case 'NEW':
      case 'CONTACTED':
      case 'SITE_VISIT_SCHEDULED':
        return primaryBlue;

      case 'INTERESTED':
      case 'SITE_VISIT_COMPLETED':
      case 'FRANCHISE_CONFIRMED':
      case 'CONVERTED':
        return green;

      case 'HOT_LEAD':
        return red;

      case 'FOLLOW_UP_REQUIRED':
      case 'AGREEMENT_PENDING':
        return yellowDark;

      case 'NOT_INTERESTED':
        return textSecondary;

      case 'LOST':
        return redDark;

      default:
        return primaryBlue;
    }
  }

  static Color getLeadStatusSoftBackground(String? status) {
    final s = status?.toUpperCase() ?? '';
    switch (s) {
      case 'NEW':
      case 'CONTACTED':
      case 'SITE_VISIT_SCHEDULED':
        return blueSoft;

      case 'INTERESTED':
      case 'SITE_VISIT_COMPLETED':
      case 'FRANCHISE_CONFIRMED':
      case 'CONVERTED':
        return greenSoft;

      case 'HOT_LEAD':
      case 'LOST':
        return redSoft;

      case 'FOLLOW_UP_REQUIRED':
      case 'AGREEMENT_PENDING':
        return yellowSoft;

      case 'NOT_INTERESTED':
        return surfaceVariant;

      default:
        return blueSoft;
    }
  }
}
