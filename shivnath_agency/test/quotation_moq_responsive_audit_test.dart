import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shivnath_agency/core/providers/auth_provider.dart';
import 'package:shivnath_agency/core/providers/product_provider.dart';
import 'package:shivnath_agency/features/admin/chat/admin_quotations_screen.dart';
import 'package:shivnath_agency/features/franchise/quotations/franchise_quotations_screen.dart';
import 'package:shivnath_agency/features/franchise/products/franchise_moq_dialog.dart';
import 'package:shivnath_agency/features/franchise/dashboard/franchise_dashboard_screen.dart';

void main() {
  group('Quotation, MOQ, and Franchise UI Multi-Viewport Responsiveness Audit', () {
    final Map<String, Size> viewports = {
      '320px Ultra-Compact (iPhone SE 1st)': const Size(320, 568),
      '360px Compact Android': const Size(360, 780),
      '375px Standard iPhone': const Size(375, 667),
      '393px Modern iPhone (14/15/16 Pro)': const Size(393, 852),
      '412px Modern Pixel / Galaxy': const Size(412, 915),
      '480px Large Handheld Phablet': const Size(480, 800),
      '568px Landscape Compact Phone': const Size(568, 320),
      '600px 7-inch Small Tablet / Foldable': const Size(600, 960),
      '768px iPad Portrait': const Size(768, 1024),
      '800px Android Tablet': const Size(800, 1280),
      '1024px iPad Landscape / Laptop': const Size(1024, 768),
      '1200px Desktop Wide Screen': const Size(1200, 800),
    };

    setUp(() {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };
    });

    for (final entry in viewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('AdminQuotationsScreen renders without pixel overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: AdminQuotationsScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on $name');
      });

      testWidgets('FranchiseQuotationsScreen renders without pixel overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const FranchiseQuotationsScreen(),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on $name');
      });

      testWidgets('FranchiseMoqDialog renders without pixel overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => const FranchiseMoqDialog(),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on $name');
      });

      testWidgets('FranchiseDashboardScreen renders without pixel overflow on $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => AuthProvider()),
              ChangeNotifierProvider(create: (_) => ProductProvider()),
            ],
            child: MaterialApp(
              theme: ThemeData.light(),
              home: const FranchiseDashboardScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on $name');
      });
    }
  });
}
