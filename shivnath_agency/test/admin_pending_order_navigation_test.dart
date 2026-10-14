import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/theme/order_status_style.dart';
import 'package:shivnath_agency/core/theme/brand_colors.dart';
import 'package:shivnath_agency/core/widgets/app_components.dart';
import 'package:shivnath_agency/features/admin/orders/pending_orders_picker_dialog.dart';

void main() {
  group('Admin Pending Order Navigation & Status Colours Regression Suite', () {
    test('OrderStatusStyle maps all backend lifecycle statuses to distinct accessible tokens', () {
      final statuses = <String, Map<String, dynamic>>{
        'order_placement': {
          'expectedColor': const Color(0xFFD97706),
          'expectedAction': true,
        },
        'plant_approval': {
          'expectedColor': const Color(0xFF2563EB),
          'expectedAction': false,
        },
        'preparing': {
          'expectedColor': const Color(0xFF7C3AED),
          'expectedAction': false,
        },
        'dispatch': {
          'expectedColor': const Color(0xFF0D9488),
          'expectedAction': false,
        },
        'delivered': {
          'expectedColor': const Color(0xFF16A34A),
          'expectedAction': false,
        },
        'cancelled': {
          'expectedColor': const Color(0xFFDC2626),
          'expectedAction': false,
        },
        'failed': {
          'expectedColor': const Color(0xFFE11D48),
          'expectedAction': true,
        },
        'payment_collection': {
          'expectedColor': const Color(0xFFD97706),
          'expectedAction': true,
        },
        'non_existent_status': {
          'expectedColor': const Color(0xFF475569),
          'expectedAction': false,
        },
      };

      for (final entry in statuses.entries) {
        final style = OrderStatusStyle.fromStatus(entry.key);
        expect(style.primaryColor, equals(entry.value['expectedColor']),
            reason: 'Status "${entry.key}" should have distinct primary color');
        expect(style.requiresAdminAction, equals(entry.value['expectedAction']),
            reason: 'Status "${entry.key}" admin action flag mismatch');
        expect(style.displayLabel.isNotEmpty, isTrue);
        expect(style.backgroundColor != style.primaryColor, isTrue,
            reason: 'Background and primary color must have high contrast');
      }
    });

    test('BrandColors delegates status styling to OrderStatusStyle correctly', () {
      expect(BrandColors.getOrderStatusColor('plant_approval'),
          equals(OrderStatusStyle.getColor('plant_approval')));
      expect(BrandColors.getOrderStatusColor('delivered'),
          equals(OrderStatusStyle.getColor('delivered')));
      expect(BrandColors.getOrderStatusColor('cancelled'),
          equals(OrderStatusStyle.getColor('cancelled')));
      expect(BrandColors.getOrderStatusSoftBackground('dispatch'),
          equals(OrderStatusStyle.getSoftBackground('dispatch')));
    });

    testWidgets('AppStatusBadge.order renders correct label and style without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppStatusBadge.order('order_placement'),
                AppStatusBadge.order('plant_approval'),
                AppStatusBadge.order('delivered'),
                AppStatusBadge.order('cancelled'),
              ],
            ),
          ),
        ),
      );

      expect(find.textContaining('ORDER PLACEMENT'), findsOneWidget);
      expect(find.textContaining('PLANT APPROVAL'), findsOneWidget);
      expect(find.textContaining('DELIVERED'), findsOneWidget);
      expect(find.textContaining('CANCELLED'), findsOneWidget);
    });

    testWidgets('PendingOrdersPickerDialog renders individual orders and never defaults to index 0', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final mockPendingOrders = [
        {
          'id': 101,
          'order_id': 'ORD-101',
          'customer_name': 'Ram Kumar',
          'total_amount': '750.00',
          'status': 'order_placement',
          'payment_method': 'Cash On Delivery',
          'item_count': 2,
        },
        {
          'id': 202,
          'order_id': 'ORD-202',
          'customer_name': 'Shyam Sundar',
          'total_amount': '1500.00',
          'status': 'plant_approval',
          'payment_method': 'Online',
          'item_count': 5,
        },
        {
          'id': 303,
          'order_id': 'ORD-303',
          'customer_name': 'Mohan Lal',
          'total_amount': '3200.00',
          'status': 'order_placement',
          'payment_method': 'UPI',
          'item_count': 10,
        },
      ];

      Map<String, dynamic>? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  PendingOrdersPickerDialog.show(
                    ctx,
                    pendingOrders: mockPendingOrders,
                    onSelectOrder: (order) {
                      selectedResult = order;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify all 3 orders are displayed with their distinct order codes and customer names
      expect(find.textContaining('ORD-101'), findsOneWidget);
      expect(find.textContaining('Ram Kumar'), findsOneWidget);
      expect(find.textContaining('ORD-202'), findsOneWidget);
      expect(find.textContaining('Shyam Sundar'), findsOneWidget);
      expect(find.textContaining('ORD-303'), findsOneWidget);
      expect(find.textContaining('Mohan Lal'), findsOneWidget);

      // Crucial test: Tap the SECOND order (ORD-202, index 1)
      await tester.tap(find.textContaining('ORD-202'));
      await tester.pumpAndSettle();

      // Verify that the callback received EXACTLY order 202, and NEVER index 0 (ORD-101)
      expect(selectedResult, isNotNull);
      expect(selectedResult!['id'], equals(202));
      expect(selectedResult!['order_id'], equals('ORD-202'));
      expect(selectedResult!['customer_name'], equals('Shyam Sundar'));
      expect(selectedResult!['id'], isNot(equals(101)));
    });

    testWidgets('PendingOrdersPickerDialog search filtering isolates specific order accurately', (tester) async {
      final mockPendingOrders = [
        {
          'id': 101,
          'order_id': 'ORD-101',
          'customer_name': 'Amit Verma',
          'total_amount': '500.00',
          'status': 'order_placement',
        },
        {
          'id': 202,
          'order_id': 'ORD-202',
          'customer_name': 'Pooja Sharma',
          'total_amount': '800.00',
          'status': 'order_placement',
        },
      ];

      Map<String, dynamic>? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  PendingOrdersPickerDialog.show(
                    ctx,
                    pendingOrders: mockPendingOrders,
                    onSelectOrder: (order) {
                      selectedResult = order;
                    },
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Type "Pooja" into the search field
      await tester.enterText(find.byType(TextField), 'Pooja');
      await tester.pumpAndSettle();

      // Verify Amit is filtered out and Pooja is visible
      expect(find.textContaining('Amit Verma'), findsNothing);
      expect(find.textContaining('Pooja Sharma'), findsOneWidget);

      // Tap Pooja's order
      await tester.tap(find.textContaining('ORD-202'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!['id'], equals(202));
      expect(selectedResult!['customer_name'], equals('Pooja Sharma'));
    });
  });
}
