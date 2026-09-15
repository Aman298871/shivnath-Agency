import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/session_service.dart';
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
    await Future.delayed(const Duration(seconds: 2));

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
    } else if (user.role == AppConstants.adminRole) {
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0284C7),
              Color(0xFF06B6D4),
            ],
          ),
        ),
        child: const SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.water_drop_rounded,
                  size: 54,
                  color: Color(0xFF0284C7),
                ),
              ),
              SizedBox(height: 22),
              Text(
                'shivnath_agency',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Water Business Management',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}