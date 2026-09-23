import 'package:flutter/material.dart';
import '../theme/brand_colors.dart';

/// Reusable Responsive utility helper for Shivnath Agency app.
class Responsive {
  Responsive._();

  static bool isVeryNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 340;

  static bool isSmallPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isPhone(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= 600 && w < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  /// Bottom padding to add to a scrollable list when a FAB is present.
  /// Ensures the last item scrolls fully above the FAB.
  static double fabBottomPadding(BuildContext context) {
    final navPadding = MediaQuery.paddingOf(context).bottom;
    return 80 + navPadding + kFloatingActionButtonMargin;
  }

  /// EdgeInsets with appropriate bottom padding for lists that have a FAB.
  static EdgeInsets fabListPadding(
    BuildContext context, {
    double horizontal = 16,
    double top = 16,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      fabBottomPadding(context),
    );
  }

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

  /// Adaptive product grid delegate that uses max cross axis extent
  /// instead of fixed column counts — works at any width without overflow.
  static SliverGridDelegate adaptiveGridDelegate({
    double maxItemExtent = 200.0,
    double childAspectRatio = 0.65,
    double crossAxisSpacing = 12,
    double mainAxisSpacing = 12,
  }) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxItemExtent,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
    );
  }
}

/// Shows a responsive dialog that constrains height to 85% of screen
/// and makes the content scrollable, preventing overflow on small screens.
Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  List<Widget>? actions,
  double maxWidthFraction = 0.95,
  double maxHeightFraction = 0.85,
  bool scrollableContent = true,
}) {
  final size = MediaQuery.sizeOf(context);
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width * ((1 - maxWidthFraction) / 2),
        vertical: size.height * ((1 - maxHeightFraction) / 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: size.width * maxWidthFraction,
          maxHeight: size.height * maxHeightFraction,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (always visible, never scrolled away)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.textPrimary,
                ),
                child: title,
              ),
            ),
            const Divider(height: 16),
            // Content (scrollable)
            Flexible(
              child: scrollableContent
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: content,
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: content,
                    ),
            ),
            // Actions (always visible)
            if (actions != null && actions.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
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

/// Action button row that dynamically wraps on narrow screens
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
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
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
        Flexible(
          child: Column(
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
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
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
