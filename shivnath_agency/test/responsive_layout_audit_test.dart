import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shivnath_agency/features/auth/customer_register_screen.dart';
import 'package:shivnath_agency/features/auth/login_screen.dart';
import 'package:shivnath_agency/features/customer/cart/cart_provider.dart';
import 'package:shivnath_agency/features/customer/cart/customer_cart_screen.dart';
import 'package:shivnath_agency/features/customer/checkout/checkout_screen.dart';
import 'package:shivnath_agency/features/customer/home/customer_home_screen.dart';
import 'package:shivnath_agency/features/customer/wallet/customer_wallet_screen.dart';

void main() {
  group('Comprehensive Screen Size Responsiveness and Pixel Overflow Audit', () {
    setUp(() {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };
    });

    final testSizes = <String, Size>{
      'Ultra Compact Phone (320x568)': const Size(320, 568),
      'Standard Android Phone (360x780)': const Size(360, 780),
      'Modern High-Res Phone (412x915)': const Size(412, 915),
      'Small Tablet / Foldable (600x960)': const Size(600, 960),
      'Large Tablet (800x1280)': const Size(800, 1280),
      'Desktop / Landscape (1280x800)': const Size(1280, 800),
    };

    for (final entry in testSizes.entries) {
      final sizeName = entry.key;
      final size = entry.value;

      testWidgets('CheckoutScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
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

        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
            debugPrint('>>> OVERFLOWING WIDGET: ${element.widget}');
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

        // Assert no layout or overflow exception occurred
        final ex = tester.takeException();
        if (ex != null) {
          if (ex is FlutterError) {
            debugPrint('=== CHECKOUT SCREEN OVERFLOW DIAGNOSTICS on $sizeName: ===');
            debugPrint(ex.toStringDeep());
          } else {
            debugPrint('=== CHECKOUT SCREEN ERROR on $sizeName: $ex ===');
          }
        }
        expect(ex, isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(CheckoutScreen), findsOneWidget);
      });

      testWidgets('CustomerCartScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
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
              home: CustomerCartScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(CustomerCartScreen), findsOneWidget);
      });

      testWidgets('CustomerHomeScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
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
              home: CustomerHomeScreen(),
            ),
          ),
        );
        await tester.pump();
        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
            debugPrint('>>> HOME OVERFLOWING WIDGET: ${element.widget}');
            if (element.widget is Row) {
              final row = element.widget as Row;
              debugPrint('>>> HOME ROW CHILDREN: ${row.children.map((c) => c.toStringShort()).toList()}');
            }
            final ancestors = <String>[];
            element.visitAncestorElements((anc) {
              ancestors.add(anc.widget.runtimeType.toString());
              return ancestors.length < 6;
            });
            debugPrint('>>> HOME ANCESTORS: ${ancestors.join(" -> ")}');
          }
        }

        final ex = tester.takeException();
        if (ex != null) {
          if (ex is FlutterError) {
            debugPrint('=== OVERFLOW IN CustomerHomeScreen on $sizeName: ===');
            debugPrint(ex.toStringDeep());
          } else {
            debugPrint('=== OVERFLOW IN CustomerHomeScreen on $sizeName: $ex ===');
          }
        }
        expect(ex, isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(CustomerHomeScreen), findsOneWidget);
      });

      testWidgets('LoginScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: LoginScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        for (final element in find.byType(Row).evaluate()) {
          final renderBox = element.renderObject as RenderBox?;
          if (renderBox != null && renderBox.hasSize && renderBox.size.width > size.width) {
            debugPrint('>>> LOGIN OVERFLOW ROW FOUND IN: ${element.widget.runtimeType}');
            if (element.widget is Row) {
              final row = element.widget as Row;
              debugPrint('>>> LOGIN ROW CHILDREN: ${row.children.map((c) => c.toStringShort()).toList()}');
            }
            final ancestors = <String>[];
            element.visitAncestorElements((anc) {
              ancestors.add(anc.widget.runtimeType.toString());
              return ancestors.length < 6;
            });
            debugPrint('>>> LOGIN ANCESTORS: ${ancestors.join(" -> ")}');
          }
        }
        final ex = tester.takeException();
        if (ex != null) {
          if (ex is FlutterError) {
            debugPrint('=== OVERFLOW IN LoginScreen on $sizeName: ===');
            debugPrint(ex.toStringDeep());
          } else {
            debugPrint('=== OVERFLOW IN LoginScreen on $sizeName: $ex ===');
          }
        }
        expect(ex, isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(LoginScreen), findsOneWidget);
      });

      testWidgets('CustomerRegisterScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
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
        await tester.pump(const Duration(milliseconds: 300));

        final ex = tester.takeException();
        if (ex != null) {
          if (ex is FlutterError) {
            debugPrint('=== OVERFLOW IN CustomerRegisterScreen on $sizeName: ===');
            debugPrint(ex.toStringDeep());
          } else {
            debugPrint('=== OVERFLOW IN CustomerRegisterScreen on $sizeName: $ex ===');
          }
        }
        expect(ex, isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(CustomerRegisterScreen), findsOneWidget);
      });

      testWidgets('CustomerWalletScreen renders without pixel overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerWalletScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
            debugPrint('>>> WALLET OVERFLOWING WIDGET: ${element.widget}');
            if (element.widget is Row) {
              final row = element.widget as Row;
              debugPrint('>>> WALLET ROW CHILDREN: ${row.children.map((c) => c.toStringShort()).toList()}');
            }
            final ancestors = <String>[];
            element.visitAncestorElements((anc) {
              ancestors.add(anc.widget.runtimeType.toString());
              return ancestors.length < 6;
            });
            debugPrint('>>> WALLET ANCESTORS: ${ancestors.join(" -> ")}');
          }
        }
        final ex = tester.takeException();
        if (ex != null) {
          if (ex is FlutterError) {
            debugPrint('=== OVERFLOW IN CustomerWalletScreen on $sizeName: ===');
            debugPrint(ex.toStringDeep());
          } else {
            debugPrint('=== OVERFLOW IN CustomerWalletScreen on $sizeName: $ex ===');
          }
        }
        expect(ex, isNull, reason: 'Layout overflow detected on $sizeName');
        expect(find.byType(CustomerWalletScreen), findsOneWidget);
      });
    }
  });
}
