import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/features/admin/admin_main_screen.dart';
import 'package:shivnath_agency/features/admin/dashboard/admin_dashboard_screen.dart';
import 'package:shivnath_agency/features/admin/orders/admin_orders_screen.dart';
import 'package:shivnath_agency/features/admin/billing/admin_billing_screen.dart';
import 'package:shivnath_agency/features/admin/franchises/admin_franchises_screen.dart';

void main() {
  group('Admin Web & Mobile Viewport Responsive Audit Test Suite', () {
    const List<double> targetWidths = [
      320, 360, 375, 390, 412, 430, 480, 768, 1024, 1280, 1366, 1440, 1920,
    ];

    setUp(() {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };
    });

    for (final width in targetWidths) {
      testWidgets('AdminMainScreen renders without overflow at ${width.toInt()}px width', (WidgetTester tester) async {
        final height = width < 768 ? 800.0 : 900.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: AdminMainScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Check desktop vs mobile layout branch
        if (width >= 800) {
          expect(find.byType(Drawer), findsNothing);
          expect(find.text('MAIN MENU'), findsOneWidget);
        } else {
          expect(find.byType(AppBar), findsOneWidget);
        }
        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
            debugPrint('>>> OVERFLOWING WIDGET IN ADMIN MAIN: ${element.widget}');
            final ancestors = <String>[];
            element.visitAncestorElements((anc) {
              ancestors.add(anc.widget.runtimeType.toString());
              return ancestors.length < 8;
            });
            debugPrint('>>> ANCESTORS: ${ancestors.join(" -> ")}');
          }
        }

        final ex = tester.takeException();
        expect(ex, isNull, reason: 'Layout exception at ${width.toInt()}px');
      });

      testWidgets('AdminDashboardScreen renders without overflow at ${width.toInt()}px width', (WidgetTester tester) async {
        final height = width < 768 ? 800.0 : 900.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: AdminDashboardScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
            debugPrint('>>> OVERFLOWING WIDGET IN DASHBOARD: ${element.widget}');
            if (element.widget is Row) {
              final row = element.widget as Row;
              debugPrint('>>> ROW CHILDREN: ${row.children.map((c) => c.toStringShort()).toList()}');
            }
            final ancestors = <String>[];
            element.visitAncestorElements((anc) {
              ancestors.add(anc.widget.runtimeType.toString());
              return ancestors.length < 6;
            });
            debugPrint('>>> ANCESTORS: ${ancestors.join(" -> ")}');
          }
        }

        final ex = tester.takeException();
        expect(ex, isNull, reason: 'Dashboard layout exception at ${width.toInt()}px');
      });

      testWidgets('AdminOrdersScreen renders without overflow at ${width.toInt()}px width', (WidgetTester tester) async {
        final height = width < 768 ? 800.0 : 900.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: AdminOrdersScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final ex = tester.takeException();
        expect(ex, isNull, reason: 'Orders layout exception at ${width.toInt()}px');
      });

      testWidgets('AdminBillingScreen renders without overflow at ${width.toInt()}px width', (WidgetTester tester) async {
        final height = width < 768 ? 800.0 : 900.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: AdminBillingScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final ex = tester.takeException();
        expect(ex, isNull, reason: 'Billing layout exception at ${width.toInt()}px');
      });

      testWidgets('AdminFranchisesScreen renders without overflow at ${width.toInt()}px width', (WidgetTester tester) async {
        final height = width < 768 ? 800.0 : 900.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: AdminFranchisesScreen()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        final ex = tester.takeException();
        expect(ex, isNull, reason: 'Franchises layout exception at ${width.toInt()}px');
      });
    }
  });
}
