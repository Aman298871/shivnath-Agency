import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/widgets/customer_outstanding_breakdown_modal.dart';

void main() {
  group('Customer Outstanding Breakdown Modal & Payment Help Tests', () {
    testWidgets('Renders itemized breakdown with separate Franchise and Admin collectors', (WidgetTester tester) async {
      final mockData = {
        'success': true,
        'customer': {
          'id': 77,
          'username': 'cust_77',
          'name': 'Ramesh Kumar',
          'phone': '9893000077',
        },
        'summary': {
          'total_outstanding': 300.0,
          'franchise_outstanding': 100.0,
          'admin_outstanding': 200.0,
          'unverified_outstanding': 0.0,
          'count': 2,
        },
        'contacts': {
          'franchise': {
            'name': 'Devendra Nagar Water Supply',
            'phone': '+91 98264 21818',
            'is_configured': true,
            'outstanding_amount': 100.0,
          },
          'admin': {
            'name': 'Shivnath Agency Support (Water Wala)',
            'phone': '+91 98062 47194',
            'is_configured': true,
            'outstanding_amount': 200.0,
          },
        },
        'items': [
          {
            'entry_id': 'ORD-101',
            'order_id': 101,
            'order_code': 'ORD-101',
            'invoice_id': 501,
            'invoice_number': 'SHV/2026/RET-0101',
            'order_date': '26 Oct 2026',
            'products': [
              {'product_name': 'Shivnath 20L Premium Jar', 'quantity': 2, 'unit_price': 50.0, 'total_price': 100.0}
            ],
            'original_order_total': 100.0,
            'amount_paid': 0.0,
            'remaining_due': 100.0,
            'payment_status': 'pending',
            'status': 'delivered',
            'reason': 'Delivered cash-on-delivery order pending physical collection',
            'collector_type': 'FRANCHISE',
            'collector_name': 'Devendra Nagar Water Supply',
            'collector_phone': '+91 98264 21818',
            'collector_role_label': 'Payable to Franchise: Devendra Nagar Water Supply',
            'can_view_order': true,
            'is_verified': true,
          },
          {
            'entry_id': 'ORD-102',
            'order_id': 102,
            'order_code': 'ORD-102',
            'invoice_id': 502,
            'invoice_number': 'SHV/2026/INV-0102',
            'order_date': '25 Oct 2026',
            'products': [
              {'product_name': '200ml Event Box', 'quantity': 1, 'unit_price': 200.0, 'total_price': 200.0}
            ],
            'original_order_total': 200.0,
            'amount_paid': 0.0,
            'remaining_due': 200.0,
            'payment_status': 'pending',
            'status': 'delivered',
            'reason': 'Direct company delivery pending payment',
            'collector_type': 'ADMIN',
            'collector_name': 'Shivnath Central Plant / Support',
            'collector_phone': '+91 98062 47194',
            'collector_role_label': 'Payable to Admin (Shivnath Central Support)',
            'can_view_order': true,
            'is_verified': true,
          },
        ],
      };

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerOutstandingBreakdownModal(
              initialData: mockData,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Totals
      expect(find.text('Outstanding Balance & Breakdown'), findsOneWidget);
      expect(find.text('₹300.00'), findsOneWidget);

      // Verify Routing Subtotals
      expect(find.text('Payable to Franchise'), findsOneWidget);
      expect(find.text('Payable to Admin Support'), findsOneWidget);
      expect(find.text('₹100.00'), findsWidgets);
      expect(find.text('₹200.00'), findsWidgets);

      // Verify Item Cards
      expect(find.text('#ORD-101'), findsOneWidget);
      expect(find.text('#ORD-102'), findsOneWidget);
      expect(find.text('Invoice: SHV/2026/RET-0101'), findsOneWidget);
      expect(find.text('Invoice: SHV/2026/INV-0102'), findsOneWidget);
      expect(find.text('Shivnath 20L Premium Jar × 2'), findsOneWidget);
      expect(find.text('200ml Event Box × 1'), findsOneWidget);

      // Verify Official Contacts & Call Buttons
      expect(find.text('Payment Help & Official Support'), findsOneWidget);
      expect(find.text('Devendra Nagar Water Supply'), findsWidgets);
      expect(find.text('+91 98264 21818'), findsWidgets);
      expect(find.text('Shivnath Agency Support (Water Wala)'), findsOneWidget);
      expect(find.text('+91 98062 47194'), findsWidgets);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders zero outstanding state properly', (WidgetTester tester) async {
      final mockZeroData = {
        'success': true,
        'summary': {
          'total_outstanding': 0.0,
          'franchise_outstanding': 0.0,
          'admin_outstanding': 0.0,
          'unverified_outstanding': 0.0,
          'count': 0,
        },
        'contacts': {
          'franchise': {
            'name': 'Assigned Franchise',
            'phone': 'Contact number not configured',
            'is_configured': false,
          },
          'admin': {
            'name': 'Shivnath Agency Support (Water Wala)',
            'phone': '+91 98062 47194',
            'is_configured': true,
          },
        },
        'items': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerOutstandingBreakdownModal(
              initialData: mockZeroData,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Zero Outstanding Balance'), findsOneWidget);
      expect(find.textContaining('All your water deliveries and bills are completely paid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders unverified balance warning without fabricating fake orders', (WidgetTester tester) async {
      final mockUnverifiedData = {
        'success': true,
        'summary': {
          'total_outstanding': 47.0,
          'franchise_outstanding': 0.0,
          'admin_outstanding': 0.0,
          'unverified_outstanding': 47.0,
          'count': 0,
        },
        'contacts': {
          'franchise': {
            'name': 'Assigned Franchise',
            'phone': 'Contact number not configured',
            'is_configured': false,
          },
          'admin': {
            'name': 'Shivnath Agency Support (Water Wala)',
            'phone': '+91 98062 47194',
            'is_configured': true,
          },
        },
        'items': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomerOutstandingBreakdownModal(
              initialData: mockUnverifiedData,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Balance Under Verification: ₹47.00'), findsOneWidget);
      expect(find.textContaining('is under accounting audit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
