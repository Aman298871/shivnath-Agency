import 'package:flutter/material.dart';

import '../features/admin/admin_main_screen.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/role_selection_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/auth/customer_register_screen.dart';
import '../features/auth/franchise_register_screen.dart';

import '../features/customer/customer_main_screen.dart';
import '../features/franchise/franchise_main_screen.dart';
import '../features/customer/orders/order_detail_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';

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

  static const String orderDetail =
      '/orders/detail';

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

      // Onboarding
      case onboarding:
        return MaterialPageRoute(
          builder: (_) =>
              const OnboardingScreen(),
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

      // Order Detail
      case orderDetail:
        final args = settings.arguments;
        String oId = '';
        Map<String, dynamic>? initialOrd;
        int? dId;
        if (args is Map) {
          oId = args['orderId']?.toString() ?? args['id']?.toString() ?? '';
          initialOrd = args['initialOrder'] is Map ? Map<String, dynamic>.from(args['initialOrder'] as Map) : null;
          dId = args['dbId'] is int ? args['dbId'] as int : int.tryParse(args['id']?.toString() ?? '');
        } else if (args is String) {
          oId = args;
        } else if (args is int) {
          oId = 'ORD-$args';
          dId = args;
        }
        return MaterialPageRoute(
          builder: (_) => OrderDetailScreen(
            orderId: oId,
            initialOrder: initialOrd,
            dbId: dId,
          ),
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