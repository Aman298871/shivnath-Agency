import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';

/// Reusable Responsive utility helper for Shivnath Agency app.
class Responsive {
  Responsive._();

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 360;

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  /// Dynamic column count based on available width and minimum card width.
  /// Never cramps cards to force a fixed column count.
  static int gridColumns(
    double availableWidth, {
    double minCardWidth = 160.0,
    int minColumns = 1,
    int maxColumns = 4,
  }) {
    if (availableWidth <= 0) return minColumns;
    final cols = (availableWidth / minCardWidth).floor();
    return cols.clamp(minColumns, maxColumns);
  }
}

/// Adaptive Layout Builder choosing between mobile, tablet, and desktop views.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1024 && desktop != null) {
          return desktop!;
        }
        if (constraints.maxWidth >= 600 && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

/// Action button row that dynamically stacks vertically on narrow screens
/// or when buttons overflow, preventing RenderFlex overflow.
class ResponsiveActionRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final MainAxisAlignment alignment;

  const ResponsiveActionRow({
    super.key,
    required this.children,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If width is tight, wrap buttons cleanly
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        );
      },
    );
  }
}

/// Standardized AppBar logo widget.
/// Renders: [💧 water droplet logo] Shivnath Agency
/// Left-aligned droplet, proper aspect ratio, responsive text.
class AppBarLogo extends StatelessWidget {
  final double size;
  final String? subtitle;

  const AppBarLogo({
    super.key,
    this.size = 32.0,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Water droplet logo mark
        Image.asset(
          'assets/images/logo.png',
          height: size,
          width: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.water_drop_rounded,
            color: BrandColors.primaryBlue,
            size: size * 0.9,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shivnath Agency',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: BrandColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Safe Area Scaffold helper that ensures proper insets without double padding.
class SafeAreaScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final Widget? drawer;
  final bool resizeToAvoidBottomInset;
  final bool top;
  final bool bottom;

  const SafeAreaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.drawer,
    this.resizeToAvoidBottomInset = true,
    this.top = true,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      backgroundColor: backgroundColor ?? BrandColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar != null
          ? SafeArea(
              top: false,
              bottom: true,
              child: bottomNavigationBar!,
            )
          : null,
      body: SafeArea(
        top: appBar == null ? top : false, // Avoid double padding if AppBar exists
        bottom: bottomNavigationBar == null ? bottom : false, // Avoid double padding if bottomNavigationBar exists
        child: body,
      ),
    );
  }
}
