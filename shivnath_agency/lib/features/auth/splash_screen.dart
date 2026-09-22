import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/brand_colors.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SessionService _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Smooth splash dwell time for brand display
    await Future.delayed(const Duration(milliseconds: 2200));

    final user = await _sessionService.getUser();

    if (!mounted) return;

    if (user == null) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.roleSelection,
      );
      return;
    }

    if (user.role == AppConstants.customerRole) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.customerDashboard,
      );
    } else if (user.role == AppConstants.franchiseRole) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.franchiseDashboard,
      );
    } else if (user.role == AppConstants.adminRole ||
        user.role == AppConstants.superAdminRole ||
        user.role == AppConstants.salesExecutiveRole) {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.adminDashboard,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.roleSelection,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.white,
      body: SizedBox.expand(
        child: Image.asset(
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
                        'shivnath_agency',
                        style: TextStyle(
                          color: BrandColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Water Business Management',
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
      ),
    );
  }
}