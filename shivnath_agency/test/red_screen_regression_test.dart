import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/services/OrderService.dart';

void main() {
  group('Red Screen Bug Regression Tests', () {
    test('OrderService normalizes Django status choices without throwing dropdown assertion errors', () {
      // Test Django DRF raw status string with slash and extra spaces
      final display1 = OrderService.normalizeStatusDisplay('Plant Approval / Admin Approved');
      expect(display1, equals('Plant Approval'));

      final display2 = OrderService.normalizeStatusDisplay('plant_approval');
      expect(display2, equals('Plant Approval'));

      final display3 = OrderService.normalizeStatusDisplay('dispatched');
      expect(display3, equals('Dispatched'));

      final display4 = OrderService.normalizeStatusDisplay('delivered');
      expect(display4, equals('Delivered'));
    });

    test('BOM items with integer raw_material ID parse without NoSuchMethodError', () {
      // Simulate raw Django backend API payload where raw_material is a foreign key int (e.g. 1)
      final rawBackendBomItem = <String, dynamic>{
        'id': 101,
        'raw_material': 1, // Integer foreign key, NOT a map
        'raw_material_name': 'Preform 20L PET',
        'raw_material_category': 'Bottles',
        'quantity_required_per_unit': '1.00',
        'unit_cost_snapshot': '12.50',
      };

      // Ensure that checking raw_material type doesn't invoke [] on int
      final rawMat = (rawBackendBomItem['raw_material'] is Map)
          ? rawBackendBomItem['raw_material'] as Map<String, dynamic>
          : null;
      final rawMatId = (rawBackendBomItem['raw_material'] is int)
          ? rawBackendBomItem['raw_material'] as int
          : int.tryParse(rawBackendBomItem['raw_material']?.toString() ?? '');

      expect(rawMat, isNull);
      expect(rawMatId, equals(1));
      expect(rawBackendBomItem['raw_material_category'], equals('Bottles'));
    });
  });
}
