import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/features/customer/stock/customer_stock_screen.dart';
import 'package:shivnath_agency/features/customer/notifications/customer_notifications_screen.dart';
import 'package:shivnath_agency/features/franchise/customers/franchise_customer_stocks_screen.dart';
import 'package:shivnath_agency/features/admin/inventory/admin_stock_management_screen.dart';

void main() {
  group('Stock Management Screen Widget Tests', () {
    testWidgets('CustomerStockScreen renders app bar and initial loader cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerStockScreen(),
        ),
      );

      // Initial loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('My Water Stock'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('CustomerNotificationsScreen renders notifications layout cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationsScreen(),
        ),
      );

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('FranchiseCustomerStocksScreen renders filter chips and search bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FranchiseCustomerStocksScreen(),
        ),
      );

      expect(find.text('Customer Stock Cycles'), findsOneWidget);

      // Check filter chips rendered
      expect(find.text('All Stocks'), findsOneWidget);
      expect(find.text('⚠️ Low Stock'), findsOneWidget);
      expect(find.text('On Hold'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AdminStockManagementScreen renders metrics bar and filter chips', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AdminStockManagementScreen(),
        ),
      );

      expect(find.text('Stock Management & Monitoring'), findsOneWidget);

      // Check metrics bar & filter chips rendered
      expect(find.text('Total Stocks'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(2)); // metric card + filter chip
      expect(find.text('Low Stock (≤7d)'), findsOneWidget);
      expect(find.text('Expiring in 7d'), findsOneWidget);
      expect(find.text('On Hold'), findsNWidgets(2)); // metric card + filter chip
      expect(find.text('Expired'), findsNWidgets(2)); // metric card + filter chip
      expect(find.byType(TextField), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
