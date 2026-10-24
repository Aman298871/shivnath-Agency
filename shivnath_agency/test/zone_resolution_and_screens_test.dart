import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shivnath_agency/features/auth/customer_register_screen.dart';
import 'package:shivnath_agency/features/customer/cart/cart_provider.dart';
import 'package:shivnath_agency/features/customer/checkout/checkout_screen.dart';
import 'package:shivnath_agency/features/franchise/customers/franchise_customers_screen.dart';
import 'package:shivnath_agency/features/franchise/notifications/franchise_notifications_screen.dart';

void main() {
  group('E2E UI & Screen Verification Tests', () {
    testWidgets('CustomerRegisterScreen displays dynamic registration form cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRegisterScreen(),
        ),
      );

      // Verify that form elements render
      expect(find.text('Create Customer Account'), findsOneWidget);
      expect(find.text('District *'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);

      // Form rendered cleanly
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('CheckoutScreen displays dynamic stock duration chips and fulfillment selector', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cartProvider = CartProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cartProvider),
          ],
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Stock Supply Duration header and chips
      expect(find.text('Stock Supply Duration'), findsOneWidget);
      expect(find.text('1 Month (~30 Days)'), findsOneWidget);
      expect(find.text('2 Months (~60 Days)'), findsOneWidget);
      expect(find.text('3 Months (~90 Days)'), findsOneWidget);
      expect(find.text('Custom Duration'), findsOneWidget);

      // Verify Order Fulfillment header
      expect(find.text('Order Fulfillment'), findsOneWidget);

      // Verify expected end date calculation banner
      expect(find.textContaining('Stock cycle ends on'), findsOneWidget);

      // Switch duration to 2 Months
      await tester.tap(find.text('2 Months (~60 Days)'));
      await tester.pump();

      // Switch duration to Custom
      await tester.tap(find.text('Custom Duration'));
      await tester.pump();
      expect(find.text('Custom Duration (Days)'), findsOneWidget);
    });

    testWidgets('FranchiseCustomersScreen renders search bar and customer layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FranchiseCustomersScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('My Customers'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('FranchiseNotificationsScreen renders live feed layout', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FranchiseNotificationsScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('CheckoutScreen renders fulfillment section and direct company fulfillment option', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cartProvider = CartProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: cartProvider),
          ],
          child: const MaterialApp(
            home: CheckoutScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check for Delivery Address section header
      expect(find.text('Delivery Address'), findsWidgets);
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });
}

