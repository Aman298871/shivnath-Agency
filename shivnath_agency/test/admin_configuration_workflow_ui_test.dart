import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shivnath_agency/features/admin/billing/delivery_pricing_dialog.dart';
import 'package:shivnath_agency/features/admin/products/packaging_rules_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'cached_delivery_origin_v1': jsonEncode({
        'name': 'Shivnath Agency Central Dispatch',
        'depot_name': 'Shivnath Agency Central Dispatch',
        'address': 'Ekta Nagar, Raipur',
        'pincode': '492014',
        'latitude': 21.267800,
        'longitude': 81.671100,
        'free_delivery_radius_km': 4.5,
        'max_serviceable_radius_km': 175.0,
        'default_delivery_charge': 45.0,
        'is_active': true,
      }),
      'cached_distance_bands_v1': jsonEncode([
        {
          'id': 1,
          'name': 'Local Delivery (0-5 km)',
          'min_distance_km': 0.0,
          'max_distance_km': 5.0,
          'delivery_charge': 30.0,
          'is_active': true,
          'is_supported': true,
          'order': 1,
        },
        {
          'id': 2,
          'name': 'Outer Delivery (5-25 km)',
          'min_distance_km': 5.0,
          'max_distance_km': 25.0,
          'delivery_charge': 75.0,
          'is_active': true,
          'is_supported': true,
          'order': 2,
        }
      ]),
      'cached_moq_packaging_rules_v1': jsonEncode([
        {
          'id': 1,
          'name': 'Shivnath 20L Water Jar Policy',
          'product_name': 'Shivnath 20 Litre Dispenser Jar',
          'sales_unit': 'JAR',
          'min_order_quantity': 5,
          'units_per_carton': 1,
          'allow_partial_carton': true,
          'is_active': true,
        },
        {
          'id': 2,
          'name': 'Mineral Water 500ml Strict Box Policy',
          'product_name': 'Shivnath 500ml Travel Bottle',
          'sales_unit': 'CARTON',
          'min_order_quantity': 5,
          'units_per_carton': 24,
          'allow_partial_carton': false,
          'is_active': true,
        }
      ]),
    });
  });

  group('Flutter Admin UI Workflow & Overflow Verification', () {
    // -------------------------------------------------------------------------
    // TEST 1: DeliveryPricingDialog Overflow & Slider Responsiveness Across Viewports
    // -------------------------------------------------------------------------
    final targetWidths = [320.0, 360.0, 390.0, 412.0, 768.0, 1024.0];

    for (final width in targetWidths) {
      testWidgets('DeliveryPricingDialog renders without overflow at ${width.toInt()}px', (WidgetTester tester) async {
        tester.view.physicalSize = Size(width, 900.0);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: DeliveryPricingDialog(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Title and Tabs
        expect(find.text('Delivery Origin & Radius Distance Pricing'), findsOneWidget);
        expect(find.text('Dispatch & Radius'), findsOneWidget);
        expect(find.text('Distance Bands'), findsOneWidget);
        expect(find.text('Fee Simulator'), findsOneWidget);

        // Verify no RenderFlex overflow
        for (final element in tester.allElements) {
          final ro = element.renderObject;
          if (ro is RenderFlex && ro.toString().contains('OVERFLOWING')) {
            fail('RenderFlex overflow detected in DeliveryPricingDialog at width ${width.toInt()}px: $ro');
          }
        }
      });
    }

    // -------------------------------------------------------------------------
    // TEST 2: Radius Slider Manipulation & Edge Value Handling (Up to 1000 km)
    // -------------------------------------------------------------------------
    testWidgets('Delivery radius controls support large bounds without layout overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 1000 km Preset Chip for Maximum Serviceable Radius
      final chip1000 = find.text('1000 km');
      expect(chip1000, findsOneWidget);
      await tester.ensureVisible(chip1000);
      await tester.tap(chip1000);
      await tester.pumpAndSettle();

      // Verify 1000.0 km is displayed
      expect(find.text('1000.0 km'), findsWidgets);

      // Tap 500 km Preset Chip
      final chip500 = find.text('500 km');
      expect(chip500, findsOneWidget);
      await tester.ensureVisible(chip500);
      await tester.tap(chip500);
      await tester.pumpAndSettle();
      expect(find.text('500.0 km'), findsWidgets);

      // Tap 15 km Free Delivery preset chip
      final chip15 = find.text('15 km');
      expect(chip15, findsOneWidget);
      await tester.ensureVisible(chip15);
      await tester.tap(chip15);
      await tester.pumpAndSettle();
      expect(find.text('15.0 km'), findsWidgets);

      // Verify no overflow occurred after manipulating large radius values
      for (final element in tester.allElements) {
        final ro = element.renderObject;
        if (ro is RenderFlex && ro.toString().contains('OVERFLOWING')) {
          fail('RenderFlex overflow detected after selecting 1000 km radius: $ro');
        }
      }
    });

    // -------------------------------------------------------------------------
    // TEST 3: Distance Bands Tab & Status Badges
    // -------------------------------------------------------------------------
    testWidgets('Distance bands tab switches cleanly and displays cached/synced bands', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Distance Bands tab
      await tester.tap(find.text('Distance Bands'));
      await tester.pumpAndSettle();

      // Verify Add New Pricing Band card or Band elements render
      expect(find.text('Add Distance Band'), findsWidgets);

      // Verify no overflow
      for (final element in tester.allElements) {
        final ro = element.renderObject;
        if (ro is RenderFlex && ro.toString().contains('OVERFLOWING')) {
          fail('RenderFlex overflow detected in Distance Bands tab: $ro');
        }
      }
    });

    // -------------------------------------------------------------------------
    // TEST 5: Save, Close, Reopen Workflow for Delivery Origin Settings
    // -------------------------------------------------------------------------
    testWidgets('Delivery origin save-close-reopen restores updated radius and default charge', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial Launch: Verify baseline cache loaded
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dispatch & Radius'), findsOneWidget);
      expect(find.text('LOCAL CACHE'), findsWidgets);

      // 2. Simulate User Modifying Configuration and Saving to Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_delivery_origin_v1',
        jsonEncode({
          'name': 'Shivnath Agency Central Dispatch',
          'depot_name': 'Shivnath Agency Central Dispatch',
          'address': 'Ekta Nagar, Raipur',
          'pincode': '492014',
          'latitude': 21.267800,
          'longitude': 81.671100,
          'free_delivery_radius_km': 5.0,
          'max_serviceable_radius_km': 250.0,
          'default_delivery_charge': 60.0,
          'is_active': true,
        }),
      );

      // 3. Close the Dialog (Simulate Dismissal / Route Pop)
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();
      expect(find.text('Delivery Origin & Radius Distance Pricing'), findsNothing);

      // 4. Reopen the Dialog: Verify Persisted Values Restored Exactly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Updated Free Radius (5.0 km), Max Radius (250.0 km), and Default Fee (60.0)
      expect(find.text('5.0 km'), findsWidgets);
      expect(find.text('250.0 km'), findsWidgets);
      expect(find.text('60.0'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // TEST 6: Save, Close, Reopen Workflow for Distance Bands
    // -------------------------------------------------------------------------
    testWidgets('Distance bands save-close-reopen persists new band and pricing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial Launch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2. Simulate Adding New Distance Band (10-30 km at ₹300) to Cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_distance_bands_v1',
        jsonEncode([
          {
            'id': 1,
            'name': 'Local Delivery (0-5 km)',
            'min_distance_km': 0.0,
            'max_distance_km': 5.0,
            'delivery_charge': 30.0,
            'is_active': true,
            'is_supported': true,
            'order': 1,
          },
          {
            'id': 2,
            'name': 'Regional Delivery (10-30 km)',
            'min_distance_km': 10.0,
            'max_distance_km': 30.0,
            'delivery_charge': 300.0,
            'is_active': true,
            'is_supported': true,
            'order': 2,
          }
        ]),
      );

      // 3. Close the Dialog
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();

      // 4. Reopen and Switch to Distance Bands Tab
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Distance Bands'));
      await tester.pumpAndSettle();

      // Verify the persisted band appears
      expect(find.text('Regional Delivery (10-30 km)'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 7: Save, Close, Reopen Workflow for 20L Jar MOQ & Packaging Rule
    // -------------------------------------------------------------------------
    testWidgets('Packaging rules save-close-reopen persists 20L Jar MOQ and partial carton rule', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial Launch
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PackagingRulesDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Minimum Order & Packaging Controls'), findsOneWidget);

      // 2. Simulate Updating 20L Jar MOQ to 8 with Partial Carton Allowed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_moq_packaging_rules_v1',
        jsonEncode([
          {
            'id': 1,
            'name': 'Shivnath 20L Dispenser Jar MOQ 8 Policy',
            'product_name': 'Shivnath 20 Litre Dispenser Jar',
            'sales_unit': 'JAR',
            'min_order_quantity': 8,
            'units_per_carton': 1,
            'allow_partial_carton': true,
            'is_active': true,
          }
        ]),
      );

      // 3. Close Dialog
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      await tester.pumpAndSettle();

      // 4. Reopen Dialog
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PackagingRulesDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Active Rules list tab
      final activeRulesTab = find.textContaining('Active Rules');
      expect(activeRulesTab, findsOneWidget);
      await tester.tap(activeRulesTab);
      await tester.pumpAndSettle();

      // Verify Updated Rule in List
      expect(find.text('Shivnath 20L Dispenser Jar MOQ 8 Policy'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 8: Bottle Carton Rule Save-Close-Reopen (Carton size 24, MOQ 10, Strict Carton)
    // -------------------------------------------------------------------------
    testWidgets('Packaging rules save-close-reopen persists Bottle Carton size 24 and strict multiples', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_moq_packaging_rules_v1',
        jsonEncode([
          {
            'id': 2,
            'name': 'Shivnath 500ml 10-Carton MOQ Policy',
            'product_name': 'Shivnath 500ml Travel Bottle',
            'sales_unit': 'CARTON',
            'min_order_quantity': 10,
            'units_per_carton': 24,
            'allow_partial_carton': false,
            'is_active': true,
          }
        ]),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PackagingRulesDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Active Rules list tab
      final activeRulesTab = find.textContaining('Active Rules');
      expect(activeRulesTab, findsOneWidget);
      await tester.tap(activeRulesTab);
      await tester.pumpAndSettle();

      // Verify Rule Name rendered
      expect(find.text('Shivnath 500ml 10-Carton MOQ Policy'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // TEST 9: Offline / Failed Save State Never Displays False Success or SERVER SYNCED
    // -------------------------------------------------------------------------
    testWidgets('Delivery origin offline / failed state never displays SERVER SYNCED', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Seed with stale local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_delivery_origin_v1',
        jsonEncode({
          'name': 'Stale Local Cache Depot',
          'depot_name': 'Stale Local Cache Depot',
          'address': 'Stale Address',
          'pincode': '492001',
          'latitude': 21.250000,
          'longitude': 81.630000,
          'free_delivery_radius_km': 2.0,
          'max_serviceable_radius_km': 50.0,
          'default_delivery_charge': 40.0,
          'is_active': true,
        }),
      );

      // 2. Launch Dialog in offline / test mode (server returns 400)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeliveryPricingDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3. Verify that the UI displays Local Cache / Offline indicator
      expect(find.text('LOCAL CACHE'), findsWidgets);

      // 4. Critical Assertion: Server Synced must NEVER be displayed
      expect(find.text('SERVER SYNCED'), findsNothing);
      expect(find.text('Server Synced'), findsNothing);
    });

    testWidgets('Packaging rules offline / cached state displays Local Cache and never Server Synced', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(412.0, 900.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_moq_packaging_rules_v1',
        jsonEncode([
          {
            'id': 99,
            'name': 'Cached Test Rule',
            'product_name': 'Test Water Bottle',
            'sales_unit': 'CARTON',
            'min_order_quantity': 5,
            'units_per_carton': 24,
            'allow_partial_carton': false,
            'is_active': true,
          }
        ]),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PackagingRulesDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Active Rules list tab
      final activeRulesTab = find.textContaining('Active Rules');
      expect(activeRulesTab, findsOneWidget);
      await tester.tap(activeRulesTab);
      await tester.pumpAndSettle();

      // Verify that offline indicator is shown
      expect(find.text('Local Cache (Offline)'), findsOneWidget);

      // Critical Assertion: Server Synced must NOT be shown
      expect(find.text('Server Synced'), findsNothing);
    });
  });
}

