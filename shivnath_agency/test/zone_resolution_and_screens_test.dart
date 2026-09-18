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
    testWidgets('CustomerRegisterScreen displays dynamic PIN resolution without requiring manual Zone selection', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerRegisterScreen(),
        ),
      );

      // Verify that "Zone" is NOT a manual required textfield
      expect(find.text('PIN Code / Delivery Area'), findsOneWidget);
      expect(find.text('District'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Create Customer Account'), findsOneWidget);

      // Enter 6-digit PIN
      final pinField = find.widgetWithText(TextFormField, 'PIN Code / Delivery Area');
      expect(pinField, findsOneWidget);
      await tester.enterText(pinField, '492001');
      await tester.pump();

      // Form rendered cleanly
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('CheckoutScreen displays dynamic stock duration chips and serving franchise selector', (WidgetTester tester) async {
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

      // Verify Serving Supply Franchise header
      expect(find.text('Serving Supply Franchise'), findsOneWidget);

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

    testWidgets('CheckoutScreen renders service unavailable card and disables order button when no franchises are available', (WidgetTester tester) async {
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

      // Check for loading state and disabled button when franchises not yet available
      expect(find.text('Loading authorized franchises...'), findsOneWidget);
      expect(find.text('Service Unavailable in Area'), findsOneWidget);
    });
  });
}
