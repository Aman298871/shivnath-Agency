import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/role_theme.dart';
import '../../routes/app_routes.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      // Snappy splash dwell time for brand display
      await Future.delayed(const Duration(milliseconds: 1000));

      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      if (!mounted) return;

      final user = authProvider.currentUser;
      final token = authProvider.token;

      if (user == null || token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone =
            prefs.getBool(OnboardingScreen.keyCompleted) ?? false;
        if (!mounted) return;

        if (!onboardingDone) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.onboarding,
          );
        } else {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.roleSelection,
          );
        }
        return;
      }

      // Verify token validity with backend via AuthProvider
      try {
        await authProvider.refreshUser().timeout(const Duration(seconds: 4));
      } catch (_) {
        // Network timeout/offline - proceed with cached session
      }

      try {
        NotificationService().registerDeviceTokenWithBackend();
      } catch (e) {
        debugPrint('Token registration non-fatal: $e');
      }

      if (!mounted) return;

      final roleProvider = Provider.of<RoleThemeProvider>(context, listen: false);
      if (user.role == AppConstants.customerRole) {
        roleProvider.setRole('customer');
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.customerDashboard,
        );
      } else if (user.role == AppConstants.franchiseRole) {
        roleProvider.setRole('franchise');
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.franchiseDashboard,
        );
      } else if (user.role == AppConstants.adminRole ||
          user.role == AppConstants.superAdminRole ||
          user.role == AppConstants.salesExecutiveRole) {
        roleProvider.setRole('admin');
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.adminDashboard,
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleSelection,
        );
      }
    } catch (e) {
      debugPrint('Splash navigation error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.roleSelection,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash_branding.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              // High quality vector fallback if asset loading encounters any platform hiccup
              return Container(
                color: BrandColors.white,
                child: const SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 54,
                          backgroundColor: BrandColors.blueSoft,
                          child: Icon(
                            Icons.water_drop_rounded,
                            size: 58,
                            color: BrandColors.primaryBlue,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Water Wala',
                          style: TextStyle(
                            color: BrandColors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Pure Water Delivery Platform',
                          style: TextStyle(
                            color: BrandColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Minimal, small, elegant rotating brand loader centered horizontally
          // below "Water Business Management" with generous whitespace
          const Align(
            alignment: Alignment(0, 0.22),
            child: _PremiumSplashLoader(),
          ),
        ],
      ),
    );
  }
}

/// Small, minimal, corporate circular arc loader subtly transitioning through
/// Shivnath brand colors: Blue -> Green -> Yellow -> Red.
class _PremiumSplashLoader extends StatefulWidget {
  const _PremiumSplashLoader();

  @override
  State<_PremiumSplashLoader> createState() => _PremiumSplashLoaderState();
}

class _PremiumSplashLoaderState extends State<_PremiumSplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<Color> _brandColors = [
    Color(0xFF0284C7), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Yellow
    Color(0xFFEF4444), // Red
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Continuous subtle interpolation across brand colors
        final t = _controller.value * _brandColors.length;
        final index = t.floor() % _brandColors.length;
        final nextIndex = (index + 1) % _brandColors.length;
        final progress = t - t.floor();
        final currentColor = Color.lerp(
          _brandColors[index],
          _brandColors[nextIndex],
          progress,
        )!;

        return Transform.rotate(
          angle: _controller.value * 2 * 3.141592653589793,
          child: CustomPaint(
            size: const Size(26, 26),
            painter: _ArcLoaderPainter(color: currentColor),
          ),
        );
      },
    );
  }
}

class _ArcLoaderPainter extends CustomPainter {
  final Color color;

  const _ArcLoaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 2.2) / 2;

    // Thin subtle track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Active thin rotating arc (smooth continuous arc with round caps)
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.35 * 3.141592653589793,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcLoaderPainter oldDelegate) =>
      oldDelegate.color != color;
}