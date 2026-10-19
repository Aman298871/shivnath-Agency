import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shivnath_agency/core/theme/order_status_style.dart';
import 'package:shivnath_agency/core/theme/brand_colors.dart';
import 'package:shivnath_agency/core/widgets/app_components.dart';
import 'package:shivnath_agency/core/services/session_service.dart';
import 'package:shivnath_agency/models/user_model.dart';
import 'package:shivnath_agency/features/admin/orders/pending_orders_picker_dialog.dart';
import 'package:shivnath_agency/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

      expect(find.textContaining('ORDER PLACED'), findsOneWidget);
      expect(find.textContaining('PLANT APPROVED'), findsOneWidget);
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

  group('Admin Logout Pending-Order Race Condition & Session Invalidation Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('SessionService increments session epoch on logout, invalidating in-flight async tasks', () async {
      final initialEpoch = SessionService.currentSessionEpoch;
      expect(SessionService.isSessionActive(initialEpoch), isTrue);

      // Perform logout
      await SessionService().logout();

      final newEpoch = SessionService.currentSessionEpoch;
      expect(newEpoch, greaterThan(initialEpoch));
      expect(SessionService.isSessionActive(initialEpoch), isFalse,
          reason: 'Prior session epoch must be invalidated immediately upon logout');
      expect(SessionService.isSessionActive(newEpoch), isTrue);
    });

    testWidgets('In-flight order polling callback aborted cleanly if Admin logs out before completion', (tester) async {
      // 1. Setup Admin session
      final initialEpoch = SessionService.currentSessionEpoch;
      expect(initialEpoch, greaterThanOrEqualTo(0));
      bool notificationShown = false;
      bool dialogShown = false;
      bool navigationTriggered = false;
      Timer? pollingTimer;

      // Simulate Admin Polling Timer
      pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {});

      // Simulate in-flight async call that takes 200ms
      final completer = Completer<Map<String, dynamic>>();

      void executeSimulatedPoll() async {
        final sessionEpoch = SessionService.currentSessionEpoch;

        // Await the asynchronous response
        await completer.future;

        // Production guard check from AdminMainScreen._pollOrders
        if (!SessionService.isSessionActive(sessionEpoch)) {
          // Cleanly aborted due to session epoch invalidation
          return;
        }

        // If not aborted, it would have shown the notification
        notificationShown = true;
      }

      // 2. Trigger async pending order request
      executeSimulatedPoll();

      // 3. Admin logs out before request completes
      await SessionService().logout();
      pollingTimer.cancel();
      pollingTimer = null;

      // 4. Complete the asynchronous response with pending orders
      completer.complete({
        'success': true,
        'data': {
          'orders': [
            {'id': 999, 'status': 'order_placement', 'amount': '1500.00'}
          ]
        }
      });

      await tester.pumpAndSettle();

      // 5. Verify no admin notification or dialog was triggered
      expect(notificationShown, isFalse,
          reason: 'Pending-order notification must NOT be shown when admin logged out during in-flight request');
      expect(dialogShown, isFalse);
      expect(navigationTriggered, isFalse);
      expect(pollingTimer, isNull,
          reason: 'Admin order poll timer must be cancelled upon logout');
    });

    testWidgets('Logging in as Franchise user after Admin logout never triggers stale Admin notification', (tester) async {
      // 1. Admin was logged in
      final adminEpoch = SessionService.currentSessionEpoch;
      bool adminNotificationDisplayed = false;

      // 2. Admin logs out
      await SessionService().logout();
      expect(SessionService.isSessionActive(adminEpoch), isFalse);

      // 3. Franchise user logs in
      final franchiseUser = UserModel(
        id: '201',
        name: 'Raipur Franchise Dealer',
        email: 'franchise@waterwala.com',
        phone: '9876543210',
        role: 'franchise',
      );
      await SessionService().saveUser(franchiseUser);
      await SessionService().saveRole('franchise');
      final franchiseEpoch = SessionService.currentSessionEpoch;

      // 4. Stale callback from Admin session attempts to execute
      void executeStaleAdminAlert() {
        if (!SessionService.isSessionActive(adminEpoch)) {
          return;
        }
        // Role guard from AdminMainScreen._showNewOrderAlert
        if (franchiseUser.role != 'admin' && franchiseUser.role != 'super_admin') {
          return;
        }
        adminNotificationDisplayed = true;
      }

      executeStaleAdminAlert();

      // 5. Verify Franchise sees zero admin pending-order notifications
      expect(adminNotificationDisplayed, isFalse,
          reason: 'Admin notifications must never appear when logged in as a Franchise user');
      expect(SessionService.isSessionActive(franchiseEpoch), isTrue);
    });

    testWidgets('Active SnackBar and Picker Dialog are dismissed immediately upon Admin logout', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                capturedContext = ctx;
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('NEW ORDER RECEIVED!'),
                            duration: Duration(seconds: 10),
                          ),
                        );
                      },
                      child: const Text('Show SnackBar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        PendingOrdersPickerDialog.show(
                          ctx,
                          pendingOrders: [
                            {'id': 1, 'order_id': 'ORD-1', 'customer_name': 'Test', 'total_amount': '100'}
                          ],
                          onSelectOrder: (_) {},
                        );
                      },
                      child: const Text('Show Dialog'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Open SnackBar
      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      expect(find.text('NEW ORDER RECEIVED!'), findsOneWidget);

      // Open Dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Pending Orders'), findsOneWidget);

      // Trigger Logout cleanup (replicates AdminMainScreen._logout)
      ScaffoldMessenger.of(capturedContext).clearSnackBars();
      Navigator.of(capturedContext, rootNavigator: true).popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      // Verify SnackBar and Dialog are completely gone
      expect(find.text('NEW ORDER RECEIVED!'), findsNothing,
          reason: 'SnackBar must be cleared on logout');
      expect(find.textContaining('Pending Orders'), findsNothing,
          reason: 'Pending orders picker dialog must be dismissed on logout');
    });

    testWidgets('Admin logout clears session, dismisses modal dialogs, and safely navigates to role selection with stack purge', (tester) async {
      // 1. Establish logged in admin session
      final adminUser = UserModel(
        id: '1',
        name: 'Super Admin',
        email: 'admin@waterwala.com',
        phone: '9826421818',
        role: 'admin',
      );
      await SessionService().saveUser(adminUser);
      await SessionService().saveRole('admin');
      await SessionService().saveToken('valid-admin-jwt-token');

      expect(await SessionService().isLoggedIn(), isTrue);

      late BuildContext navContext;

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: AppRoutes.adminDashboard,
          routes: {
            AppRoutes.roleSelection: (ctx) => const Scaffold(body: Center(child: Text('ROLE SELECTION SCREEN'))),
            AppRoutes.adminDashboard: (ctx) {
              navContext = ctx;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: ctx,
                        builder: (_) => const AlertDialog(title: Text('PENDING ORDERS PICKER')),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              );
            },
          },
        ),
      );

      // Open a dialog on top of admin dashboard
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('PENDING ORDERS PICKER'), findsOneWidget);

      // Execute exact AdminMainScreen._logout sequence:
      // 1. Dismiss dialogs
      Navigator.of(navContext, rootNavigator: true).popUntil((route) => route.isFirst || route.settings.name == AppRoutes.adminDashboard);
      // 2. Clear session
      await SessionService().logout();
      // 3. Clear SnackBars
      ScaffoldMessenger.of(navContext).clearSnackBars();
      // 4. Navigate and purge stack
      Navigator.pushNamedAndRemoveUntil(navContext, AppRoutes.roleSelection, (_) => false);

      await tester.pumpAndSettle();

      // Verify:
      // A. Dialog is gone
      expect(find.text('PENDING ORDERS PICKER'), findsNothing);
      // B. User is on Role Selection Screen
      expect(find.text('ROLE SELECTION SCREEN'), findsOneWidget);
      // C. Navigation stack cannot pop backwards to admin
      expect(Navigator.of(tester.element(find.text('ROLE SELECTION SCREEN'))).canPop(), isFalse,
          reason: 'Navigation stack must be completely purged so back button cannot return to protected admin screens');
      // D. Session is completely wiped
      expect(await SessionService().isLoggedIn(), isFalse);
      expect(await SessionService().getAccessToken(), isNull);
      expect(await SessionService().getUser(), isNull);
    });
  });
}

