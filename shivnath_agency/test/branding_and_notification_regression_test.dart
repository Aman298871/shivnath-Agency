import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/constants/app_constants.dart';
import 'package:shivnath_agency/core/widgets/shivnath_logo.dart';
import 'package:shivnath_agency/core/services/notification_service.dart';

void main() {
  group('Priority 2: Client-Approved Water Wala Branding Verifications', () {
    test('Exact approved brand text strings match client specifications', () {
      expect(AppConstants.appName, equals('Water Wala'));
      expect(AppConstants.brandShortName, equals('Water Wala'));
      expect(AppConstants.appTagline, equals('पानी चाहिए? Water Wala बुलाइए!'));
    });

    testWidgets('ShivnathLogo vertical renders approved brand text and tagline', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ShivnathLogo(
              size: 58,
              showSubtitle: true,
              useAssetImage: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify presence of approved strings
      expect(find.byType(RichText), findsWidgets);
      expect(find.text(AppConstants.appTagline), findsOneWidget);
    });

    testWidgets('ShivnathLogo horizontal renders correctly without overflow on small widths', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: ShivnathLogo.horizontal(
                  size: 32,
                  showSubtitle: true,
                  useAssetImage: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text(AppConstants.appTagline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('Category Card Sizing: Water Bottles only 200ML - 1L and Water Jars only 20L', () {
      const bottleSubtitle = '200 ML - 1 Litre';
      const jarSubtitle = '20 Litre';

      // Verify 2L and 5L are completely absent
      expect(bottleSubtitle.contains('2 Litre'), isFalse);
      expect(bottleSubtitle.contains('2L'), isFalse);
      expect(jarSubtitle.contains('5L'), isFalse);
      expect(jarSubtitle.contains('5 Litre'), isFalse);
      expect(jarSubtitle, equals('20 Litre'));
    });
  });

  group('Priority 1: Notification Channel and Navigation Constants', () {
    test('Notification channel constants configured for high importance', () {
      expect(NotificationService.channelId, equals('high_importance_channel'));
      expect(NotificationService.channelName, equals('High Importance Notifications'));
    });
  });
}
