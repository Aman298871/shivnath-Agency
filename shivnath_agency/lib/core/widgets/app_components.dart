import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';
import '../theme/app_theme.dart';
import '../theme/order_status_style.dart';

// =============================================================================
// APP CARD
// =============================================================================

/// Professional white card with subtle border, soft shadow, and optional accent strip.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool showAccentStrip;
  final double borderRadius;
  final Color? backgroundColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.onTap,
    this.accentColor,
    this.showAccentStrip = false,
    this.borderRadius = AppDesignTokens.radiusLg,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? BrandColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentColor != null && !showAccentStrip
              ? accentColor!.withValues(alpha: 0.35)
              : BrandColors.border,
          width: 1.0,
        ),
        boxShadow: AppDesignTokens.cardShadow,
      ),
      child: child,
    );

    if (showAccentStrip && accentColor != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? BrandColors.white,
            border: Border.all(color: BrandColors.border),
            boxShadow: AppDesignTokens.cardShadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4.0,
                  color: accentColor,
                ),
                Expanded(
                  child: Padding(
                    padding: padding ?? const EdgeInsets.all(16.0),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (onTap != null) {
      return Container(
        margin: margin,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      child: content,
    );
  }
}

// =============================================================================
// APP BUTTON
// =============================================================================

enum AppButtonType {
  primary,
  secondary,
  success,
  warning,
  danger,
}

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = AppDesignTokens.buttonHeight,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide borderSide = BorderSide.none;

    switch (type) {
      case AppButtonType.primary:
        bg = customColor ?? BrandColors.primaryBlue;
        fg = BrandColors.white;
        break;
      case AppButtonType.secondary:
        bg = BrandColors.white;
        fg = customColor ?? BrandColors.primaryBlue;
        borderSide = BorderSide(color: fg, width: 1.4);
        break;
      case AppButtonType.success:
        bg = BrandColors.greenDark;
        fg = BrandColors.white;
        break;
      case AppButtonType.warning:
        bg = BrandColors.yellow;
        fg = const Color(0xFF78350F); // High-contrast amber dark text
        break;
      case AppButtonType.danger:
        bg = BrandColors.redDark;
        fg = BrandColors.white;
        break;
    }

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: BrandColors.border,
      disabledForegroundColor: BrandColors.textMuted,
      elevation: 0,
      side: borderSide,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
    );

    Widget childWidget = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        style: buttonStyle,
        onPressed: isLoading ? null : onPressed,
        child: childWidget,
      ),
    );
  }
}

// =============================================================================
// APP STATUS BADGE
// =============================================================================

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;
  final double fontSize;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
    this.icon,
    this.fontSize = 11.5,
  });

  /// Factory for semantic order status badge
  factory AppStatusBadge.order(String? status, {double fontSize = 11.5, bool showIcon = true}) {
    final style = OrderStatusStyle.fromStatus(status);
    return AppStatusBadge(
      label: style.displayLabel.toUpperCase(),
      color: style.primaryColor,
      backgroundColor: style.backgroundColor,
      icon: showIcon ? style.icon : null,
      fontSize: fontSize,
    );
  }

  /// Factory for payment status badge
  factory AppStatusBadge.payment(String? status) {
    final s = (status ?? 'PENDING').toUpperCase();
    Color color;
    Color bg;
    if ((s.contains('PAID') || s.contains('COLLECTED')) && !s.contains('UNPAID') && !s.contains('PENDING')) {
      color = BrandColors.green;
      bg = BrandColors.greenSoft;
    } else if (s.contains('PARTIAL')) {
      color = BrandColors.yellow;
      bg = BrandColors.yellowSoft;
    } else {
      color = BrandColors.red;
      bg = BrandColors.redSoft;
    }
    return AppStatusBadge(
      label: s.replaceAll('_', ' '),
      color: color,
      backgroundColor: bg,
    );
  }

  /// Factory for inventory status badge
  factory AppStatusBadge.inventory(String? status, {int? stockCount, int? minThreshold}) {
    final color = BrandColors.getInventoryColor(status, stockCount: stockCount, minThreshold: minThreshold);
    Color bg;
    if (color == BrandColors.inventoryCritical) {
      bg = BrandColors.redSoft;
    } else if (color == BrandColors.inventoryLow) {
      bg = BrandColors.yellowSoft;
    } else if (color == BrandColors.inventoryAvailable) {
      bg = BrandColors.greenSoft;
    } else {
      bg = BrandColors.blueSoft;
    }

    String display = status ?? 'IN STOCK';
    if (stockCount != null) {
      if (stockCount <= 0) {
        display = 'OUT OF STOCK';
      } else if (minThreshold != null && stockCount <= minThreshold) {
        display = 'LOW STOCK ($stockCount)';
      } else {
        display = 'AVAILABLE ($stockCount)';
      }
    }

    return AppStatusBadge(
      label: display,
      color: color,
      backgroundColor: bg,
      icon: color == BrandColors.inventoryCritical ? Icons.warning_rounded : null,
    );
  }

  /// Factory for expiry alert badge
  factory AppStatusBadge.expiry(int daysUntilExpiry) {
    final color = BrandColors.getExpiryColor(daysUntilExpiry);
    final bg = BrandColors.getExpirySoftBackground(daysUntilExpiry);
    String text;
    if (daysUntilExpiry <= 0) {
      text = 'EXPIRED';
    } else if (daysUntilExpiry == 1) {
      text = 'EXPIRES TOMORROW';
    } else {
      text = 'EXPIRES IN $daysUntilExpiry DAYS';
    }
    return AppStatusBadge(
      label: text,
      color: color,
      backgroundColor: bg,
      icon: Icons.timer_outlined,
    );
  }

  /// Factory for CRM lead status badge
  factory AppStatusBadge.lead(String? status) {
    final color = BrandColors.getLeadStatusColor(status);
    final bg = BrandColors.getLeadStatusSoftBackground(status);
    final cleanLabel = (status ?? 'NEW').replaceAll('_', ' ');
    return AppStatusBadge(
      label: cleanLabel,
      color: color,
      backgroundColor: bg,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(AppDesignTokens.radiusFull),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3,
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

// =============================================================================
// BRAND COLOR LOADER
// =============================================================================

/// Animated loader that cycles gracefully through Blue -> Green -> Yellow -> Red.
class BrandColorLoader extends StatefulWidget {
  final double size;
  final double strokeWidth;

  const BrandColorLoader({
    super.key,
    this.size = 32.0,
    this.strokeWidth = 3.0,
  });

  @override
  State<BrandColorLoader> createState() => _BrandColorLoaderState();
}

class _BrandColorLoaderState extends State<BrandColorLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: BrandColors.primaryBlue,
          end: BrandColors.greenDark,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: BrandColors.greenDark,
          end: BrandColors.yellow,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: BrandColors.yellow,
          end: BrandColors.red,
        ),
      ),
      TweenSequenceItem(
        weight: 1.0,
        tween: ColorTween(
          begin: BrandColors.red,
          end: BrandColors.primaryBlue,
        ),
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(
              _colorAnimation.value ?? BrandColors.primaryBlue,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// APP EMPTY STATE
// =============================================================================

class AppEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color accentColor;

  const AppEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.water_drop_outlined,
    this.actionLabel,
    this.onAction,
    this.accentColor = BrandColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: BrandColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: BrandColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: actionLabel!,
                onPressed: onAction,
                width: 180,
                height: 44,
                customColor: accentColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
