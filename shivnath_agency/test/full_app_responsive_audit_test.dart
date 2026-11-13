import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shivnath_agency/core/providers/auth_provider.dart';
import 'package:shivnath_agency/core/providers/product_provider.dart';
import 'package:shivnath_agency/core/providers/wallet_provider.dart';
import 'package:shivnath_agency/features/admin/billing/admin_billing_screen.dart';
import 'package:shivnath_agency/features/admin/billing/delivery_pricing_dialog.dart';
import 'package:shivnath_agency/features/admin/customers/admin_customer_detail_screen.dart';
import 'package:shivnath_agency/features/admin/customers/admin_customers_screen.dart';
import 'package:shivnath_agency/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:shivnath_agency/features/admin/leads/admin_leads_screen.dart';
import 'package:shivnath_agency/features/admin/orders/admin_orders_screen.dart';
import 'package:shivnath_agency/features/admin/products/packaging_rules_dialog.dart';
import 'package:shivnath_agency/features/auth/customer_register_screen.dart';
import 'package:shivnath_agency/features/auth/login_screen.dart';
import 'package:shivnath_agency/features/customer/cart/cart_provider.dart';
import 'package:shivnath_agency/features/customer/checkout/checkout_screen.dart';
import 'package:shivnath_agency/features/franchise/franchise_main_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_role': 'admin',
      'selected_role': 'admin',
      'cached_delivery_origin_v1': jsonEncode({
        'name': 'Shivnath Agency Central Dispatch',
        'depot_name': 'Shivnath Agency Central Dispatch',
        'address': 'Ekta Nagar, Raipur',
        'pincode': '492014',
        'latitude': 21.267800,
        'longitude': 81.671100,
        'free_delivery_radius_km': 4.5,
        'max_serviceable_radius_km': 175.0,
        'default_delivery_charge': 45.0,
        'is_active': true,
      }),
      'cached_distance_bands_v1': jsonEncode([
        {
          'id': 1,
          'name': 'Local Delivery (0-5 km)',
          'min_distance_km': 0.0,
          'max_distance_km': 5.0,
          'delivery_charge': 30.0,
          'is_active': true,
          'is_supported': true,
          'order': 1,
        },
      ]),
      'cached_moq_packaging_rules_v1': jsonEncode([
        {
          'id': 1,
          'name': 'Shivnath 20L Water Jar Policy',
          'product_name': 'Shivnath 20 Litre Dispenser Jar',
          'sales_unit': 'JAR',
          'min_order_quantity': 5,
          'units_per_carton': 1,
          'allow_partial_carton': true,
          'is_active': true,
        },
      ]),
    });
  });

  // The 8 explicit viewport widths required by Section 8
  const auditWidths = <double>[320, 360, 375, 390, 412, 600, 800, 1280];

  group('Full Application Responsiveness Audit Across 8 Explicit Widths', () {
    for (final width in auditWidths) {
      final size = Size(width, 850.0);

      testWidgets('AdminDashboardScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: const Scaffold(
              body: AdminDashboardScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminDashboardScreen at ${width.toInt()}px');
        expect(find.byType(AdminDashboardScreen), findsOneWidget);
      });

      testWidgets('AdminLeadsScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AdminLeadsScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminLeadsScreen at ${width.toInt()}px');
        expect(find.byType(AdminLeadsScreen), findsOneWidget);
      });

      testWidgets('AdminOrdersScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AdminOrdersScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminOrdersScreen at ${width.toInt()}px');
        expect(find.byType(AdminOrdersScreen), findsOneWidget);
      });

      testWidgets('AdminCustomersScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AdminCustomersScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminCustomersScreen at ${width.toInt()}px');
        expect(find.byType(AdminCustomersScreen), findsOneWidget);
      });

      testWidgets('AdminCustomerDetailScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AdminCustomerDetailScreen(
                customerId: 23,
                customerName: 'Sangam',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminCustomerDetailScreen at ${width.toInt()}px');
        expect(find.byType(AdminCustomerDetailScreen), findsOneWidget);
      });

      testWidgets('AdminBillingScreen (Invoices) layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AdminBillingScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in AdminBillingScreen at ${width.toInt()}px');
        expect(find.byType(AdminBillingScreen), findsOneWidget);
      });

      testWidgets('DeliveryPricingDialog layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DeliveryPricingDialog(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in DeliveryPricingDialog at ${width.toInt()}px');
        expect(find.byType(DeliveryPricingDialog), findsOneWidget);
      });

      testWidgets('PackagingRulesDialog layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: PackagingRulesDialog(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in PackagingRulesDialog at ${width.toInt()}px');
        expect(find.byType(PackagingRulesDialog), findsOneWidget);
      });

      testWidgets('CustomerRegisterScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerRegisterScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in CustomerRegisterScreen at ${width.toInt()}px');
        expect(find.byType(CustomerRegisterScreen), findsOneWidget);
      });

      testWidgets('CheckoutScreen layout audit at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => CartProvider()),
              ChangeNotifierProvider(create: (_) => WalletProvider()),
            ],
            child: const MaterialApp(
              home: CheckoutScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull, reason: 'Overflow in CheckoutScreen at ${width.toInt()}px');
        expect(find.byType(CheckoutScreen), findsOneWidget);
      });
    }
  });
}
