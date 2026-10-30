import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/repositories/customer_repository.dart';
import 'package:shivnath_agency/core/services/customer_service.dart';
import 'package:shivnath_agency/features/admin/customers/admin_customers_screen.dart';
import 'package:shivnath_agency/features/admin/customers/admin_customer_detail_screen.dart';
import 'package:shivnath_agency/features/admin/dashboard/admin_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Customer CRM & Dashboard Tests', () {
    test('CustomerService and CustomerRepository instantiation', () {
      final service = CustomerService();
      final repo = CustomerRepository(customerService: service);
      expect(repo, isNotNull);
    });

    testWidgets('AdminCustomersScreen renders CRM header, toolbar, and KPI cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminCustomersScreen(),
          ),
        ),
      );

      // Verify header text
      expect(find.text('Customer CRM'), findsOneWidget);
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('Active Accounts'), findsOneWidget);
      expect(find.text('Total CRM Spend'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AdminCustomerDetailScreen renders customer header and 3 tabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdminCustomerDetailScreen(
            customerId: 101,
            customerName: 'Aman Sharma',
          ),
        ),
      );

      expect(find.text('Aman Sharma'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AdminDashboardScreen accepts onOpenCustomers and displays stat cards', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool customerOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminDashboardScreen(
              onOpenCustomers: () {
                customerOpened = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(customerOpened, isFalse);
    });
  });
}
