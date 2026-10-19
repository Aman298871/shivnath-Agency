import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shivnath_agency/core/providers/auth_provider.dart';
import 'package:shivnath_agency/core/providers/product_provider.dart';
import 'package:shivnath_agency/core/widgets/document_preview_dialog.dart';
import 'package:shivnath_agency/features/admin/reports/daily_pl_report_screen.dart';
import 'package:shivnath_agency/features/franchise/categories/franchise_categories_screen.dart';
import 'package:shivnath_agency/features/franchise/customers/franchise_customer_stocks_screen.dart';
import 'package:shivnath_agency/features/franchise/products/franchise_products_screen.dart';

void main() {
  group('Franchise & Reports Comprehensive Responsive & Pixel Overflow Audit', () {
    setUp(() {
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };
    });

    final testSizes = <String, Size>{
      'Small mobile (320x568)': const Size(320, 568),
      'Standard mobile (360x800)': const Size(360, 800),
      'Larger mobile (393x852)': const Size(393, 852),
      'Tablet (768x1024)': const Size(768, 1024),
      'Desktop small (1024x768)': const Size(1024, 768),
      'Desktop wide (1366x768)': const Size(1366, 768),
    };

    Widget createTestApp(Widget home) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ProductProvider()),
        ],
        child: MaterialApp(
          home: home,
        ),
      );
    }

    void verifyNoRenderFlexOverflow(WidgetTester tester, String screenName, String sizeName) {
      for (final element in tester.allElements) {
        final ro = element.renderObject;
        if (ro is RenderFlex && (ro.toString().contains('OVERFLOWING') || ro.toString().contains('overflowed'))) {
          debugPrint('>>> OVERFLOWING WIDGET IN $screenName ON $sizeName: ${element.widget}');
        }
      }

      final ex = tester.takeException();
      if (ex != null) {
        debugPrint('=== OVERFLOW EXCEPTION IN $screenName ON $sizeName: $ex ===');
      }
      expect(ex, isNull, reason: '$screenName has pixel overflow exception on $sizeName');
    }

    for (final entry in testSizes.entries) {
      final sizeName = entry.key;
      final size = entry.value;

      testWidgets('FranchiseProductsScreen renders cleanly without overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const FranchiseProductsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        verifyNoRenderFlexOverflow(tester, 'FranchiseProductsScreen', sizeName);
        expect(find.byType(FranchiseProductsScreen), findsOneWidget);
      });

      testWidgets('FranchiseCategoriesScreen renders cleanly without overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const FranchiseCategoriesScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        verifyNoRenderFlexOverflow(tester, 'FranchiseCategoriesScreen', sizeName);
        expect(find.byType(FranchiseCategoriesScreen), findsOneWidget);
      });

      testWidgets('FranchiseCustomerStocksScreen renders cleanly without overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const FranchiseCustomerStocksScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        verifyNoRenderFlexOverflow(tester, 'FranchiseCustomerStocksScreen', sizeName);
        expect(find.byType(FranchiseCustomerStocksScreen), findsOneWidget);
      });

      testWidgets('DailyPlReportScreen renders cleanly without overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(const DailyPlReportScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        verifyNoRenderFlexOverflow(tester, 'DailyPlReportScreen', sizeName);
        expect(find.byType(DailyPlReportScreen), findsOneWidget);
      });

      testWidgets('DocumentPreviewDialog renders cleanly without overflow on $sizeName', (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestApp(
            const Scaffold(
              body: DocumentPreviewDialog(
                title: 'FSSAI License & Certificate Preview 2026',
                documentUrl: 'https://example.com/test.pdf',
                documentNumber: '10022999000123',
                documentType: 'FSSAI_CENTRAL',
                verificationStatus: 'VERIFIED',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        verifyNoRenderFlexOverflow(tester, 'DocumentPreviewDialog', sizeName);
        expect(find.byType(DocumentPreviewDialog), findsOneWidget);
      });
    }
  });
}
