import 'package:flutter/material.dart';

import '../features/admin/admin_main_screen.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/customer_register_screen.dart';
import '../features/auth/franchise_register_screen.dart';

import '../features/customer/customer_main_screen.dart';
import '../features/franchise/franchise_main_screen.dart';

class AppRoutes {
  static const String splash = '/';

  static const String roleSelection =
      '/role-selection';

  static const String login =
      '/login';

  // Registration
  static const String customerRegister =
      '/customer-register';

  static const String franchiseRegister =
      '/franchise-register';

  // Dashboards
  static const String customerDashboard =
      '/customer/dashboard';

  static const String franchiseDashboard =
      '/franchise/dashboard';

  static const String adminDashboard =
      '/admin/dashboard';

  static Route<dynamic> generateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      // Splash
      case splash:
        return MaterialPageRoute(
          builder: (_) =>
              const SplashScreen(),
          settings: settings,
        );

      // Role Selection
      case roleSelection:
        return MaterialPageRoute(
          builder: (_) =>
              const RoleSelectionScreen(),
          settings: settings,
        );

      // Login
      case login:
        return MaterialPageRoute(
          builder: (_) =>
              const LoginScreen(),
          settings: settings,
        );

      // Customer Registration
      case customerRegister:
        return MaterialPageRoute(
          builder: (_) =>
              const CustomerRegisterScreen(),
          settings: settings,
        );

      // Franchise Registration
      case franchiseRegister:
        return MaterialPageRoute(
          builder: (_) =>
              const FranchiseRegisterScreen(),
          settings: settings,
        );

      // Customer Dashboard
      case customerDashboard:
        return MaterialPageRoute(
          builder: (_) =>
              const CustomerMainScreen(),
          settings: settings,
        );

      // Franchise Dashboard
      case franchiseDashboard:
        return MaterialPageRoute(
          builder: (_) =>
              const FranchiseMainScreen(),
          settings: settings,
        );

      // Admin Dashboard
      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) =>
              const AdminMainScreen(),
          settings: settings,
        );

      // 404
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(
            body: Center(
              child: Text(
                'Page not found',
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
}