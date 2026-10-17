import 'package:flutter/material.dart';

/// Centralized, accessible status-to-colour mapping and styling system
/// for Shivnath Agency orders.
///
/// Maps all real backend statuses defined in `orders/models.py` to accessible,
/// high-contrast semantic colors, backgrounds, borders, and icons.
class OrderStatusStyle {
  final String rawStatus;
  final String displayLabel;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final IconData icon;
  final bool requiresAdminAction;

  const OrderStatusStyle({
    required this.rawStatus,
    required this.displayLabel,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.icon,
    this.requiresAdminAction = false,
  });

  /// Factory resolving any status string (raw backend code or normalized display name)
  /// to its authoritative visual design token.
  factory OrderStatusStyle.fromStatus(String? status) {
    final raw = (status ?? '').trim();
    final lower = raw.toLowerCase().replaceAll(' ', '_');

    // 1. Pending / Awaiting Action (Amber / Orange)
    if (lower == 'order_placement' ||
        lower == 'new' ||
        lower == 'created' ||
        lower == 'pending' ||
        lower == 'pending_approval' ||
        lower == 'awaiting_payment' ||
        lower == 'order_placed' ||
        (lower.contains('pend') && !lower.contains('stock'))) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Pending Approval'),
        primaryColor: const Color(0xFFD97706), // Amber 600
        backgroundColor: const Color(0xFFFFFBEB), // Amber 50
        borderColor: const Color(0xFFFDE68A), // Amber 200
        icon: Icons.hourglass_top_rounded,
        requiresAdminAction: true,
      );
    }

    // 2. Approved / Confirmed (Blue)
    if (lower == 'plant_approval' ||
        lower == 'approved' ||
        lower == 'admin_approved' ||
        lower == 'confirmed' ||
        (lower.contains('approv') && !lower.contains('pend'))) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Plant Approval'),
        primaryColor: const Color(0xFF2563EB), // Blue 600
        backgroundColor: const Color(0xFFEFF6FF), // Blue 50
        borderColor: const Color(0xFFBFDBFE), // Blue 200
        icon: Icons.verified_rounded,
        requiresAdminAction: false,
      );
    }

    // 3. Preparing / Processing / Invoice (Purple)
    if (lower == 'preparing' ||
        lower == 'bottling' ||
        lower == 'packaging' ||
        lower == 'processing' ||
        lower == 'invoice_generated' ||
        lower.contains('prepar')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Preparing'),
        primaryColor: const Color(0xFF7C3AED), // Purple 600
        backgroundColor: const Color(0xFFF5F3FF), // Purple 50
        borderColor: const Color(0xFFDDD6FE), // Purple 200
        icon: Icons.precision_manufacturing_rounded,
        requiresAdminAction: false,
      );
    }

    // 4. Dispatched / Out for Delivery / In Transit (Teal)
    if (lower == 'dispatch' ||
        lower == 'dispatched' ||
        lower == 'in_transit' ||
        lower == 'transit' ||
        lower == 'shipped' ||
        lower == 'out_for_delivery' ||
        lower.contains('dispatch')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Dispatched'),
        primaryColor: const Color(0xFF0D9488), // Teal 600
        backgroundColor: const Color(0xFFF0FDFA), // Teal 50
        borderColor: const Color(0xFF99F6E4), // Teal 200
        icon: Icons.local_shipping_rounded,
        requiresAdminAction: false,
      );
    }

    // 5. Delivered / Completed (Green)
    if (lower == 'delivered' ||
        lower == 'completed' ||
        lower.contains('deliver')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Delivered'),
        primaryColor: const Color(0xFF16A34A), // Green 600
        backgroundColor: const Color(0xFFF0FDF4), // Green 50
        borderColor: const Color(0xFFBBF7D0), // Green 200
        icon: Icons.task_alt_rounded,
        requiresAdminAction: false,
      );
    }

    // 6. Cancelled / Rejected (Red)
    if (lower == 'cancelled' ||
        lower == 'rejected' ||
        lower.contains('cancel') ||
        lower.contains('reject')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Cancelled'),
        primaryColor: const Color(0xFFDC2626), // Red 600
        backgroundColor: const Color(0xFFFEF2F2), // Red 50
        borderColor: const Color(0xFFFECACA), // Red 200
        icon: Icons.cancel_outlined,
        requiresAdminAction: false,
      );
    }

    // 7. Failed Payment or Action Requiring Attention (Rose / Red Warning)
    if (lower == 'failed' ||
        lower == 'payment_failed' ||
        lower.contains('fail')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: _cleanLabel(raw, fallback: 'Payment Failed'),
        primaryColor: const Color(0xFFE11D48), // Rose 600
        backgroundColor: const Color(0xFFFFE4E6), // Rose 50
        borderColor: const Color(0xFFFECDD3), // Rose 200
        icon: Icons.error_outline_rounded,
        requiresAdminAction: true,
      );
    }

    // 8. Payment Collection (Amber Action)
    if (lower == 'payment_collection' || lower.contains('collection')) {
      return OrderStatusStyle(
        rawStatus: raw,
        displayLabel: 'Payment Collection',
        primaryColor: const Color(0xFFD97706),
        backgroundColor: const Color(0xFFFFFBEB),
        borderColor: const Color(0xFFFDE68A),
        icon: Icons.payments_outlined,
        requiresAdminAction: true,
      );
    }

    // 9. Unknown or Other (Neutral Slate Grey)
    return OrderStatusStyle(
      rawStatus: raw,
      displayLabel: _cleanLabel(raw, fallback: 'Unknown Status'),
      primaryColor: const Color(0xFF475569), // Slate 600
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      borderColor: const Color(0xFFCBD5E1), // Slate 300
      icon: Icons.help_outline_rounded,
      requiresAdminAction: false,
    );
  }

  static String _cleanLabel(String raw, {required String fallback}) {
    if (raw.trim().isEmpty) return fallback;
    final lower = raw.trim().toLowerCase();
    if (lower.contains('plant') && lower.contains('approv')) {
      return 'Plant Approved';
    }
    if (lower.contains('admin') && lower.contains('approv')) {
      return 'Admin Approved';
    }
    if (lower.contains('order') && lower.contains('place')) {
      return 'Order Placed';
    }
    final cleaned = raw.replaceAll('_', ' ').replaceAll('/', ' / ').trim();
    // Capitalize each word nicely
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w == '/' ? '/' : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  /// Convenience helpers for quick lookup
  static Color getColor(String? status) => OrderStatusStyle.fromStatus(status).primaryColor;
  static Color getSoftBackground(String? status) => OrderStatusStyle.fromStatus(status).backgroundColor;
  static Color getBorderColor(String? status) => OrderStatusStyle.fromStatus(status).borderColor;
  static IconData getIcon(String? status) => OrderStatusStyle.fromStatus(status).icon;

  /// Render an accessible visual badge component with clear icon and label
  Widget buildBadge({
    double fontSize = 11.5,
    EdgeInsetsGeometry? padding,
    bool showIcon = true,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: fontSize + 2.5, color: primaryColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              displayLabel.toUpperCase(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w800,
                fontSize: fontSize,
                letterSpacing: 0.4,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
