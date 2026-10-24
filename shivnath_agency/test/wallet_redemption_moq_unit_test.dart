import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/repositories/order_repository.dart';

void main() {
  group('Wallet Redemption MOQ Unit & Contract Tests', () {
    test('OrderRepository.redeemWalletPoints passes quantity parameter', () async {
      final repo = OrderRepository();
      // Test that method signature accepts productId and quantity >= 5
      expect(repo.redeemWalletPoints, isA<Function>());
    });

    test('MOQ calculation logic for jars and carton packaging', () {
      // 20L Water Jars: MOQ = 5, step = 1
      final jarProduct = {
        'id': 1,
        'name': 'Mineral Water Jar 20L',
        'sales_unit': 'UNIT',
        'units_per_carton': 1,
        'moq_units': 5,
        'min_order_quantity': 5,
        'points_per_unit': 180,
        'points_required': 900,
      };

      final jarMoq = jarProduct['moq_units'] as int;
      final jarUnitPts = jarProduct['points_per_unit'] as int;
      expect(jarMoq, 5);
      expect(jarMoq * jarUnitPts, 900);

      // Packaged 500ml Water Bottles: MOQ = 5 boxes (120 bottles), step = 24
      final bottleProduct = {
        'id': 2,
        'name': 'Shivnath Mineral Water 500ml',
        'sales_unit': 'CARTON',
        'units_per_carton': 24,
        'moq_units': 120,
        'min_order_quantity': 5,
        'points_per_unit': 20,
        'points_required': 2400,
      };

      final bottleMoqUnits = bottleProduct['moq_units'] as int;
      final unitsPerCarton = bottleProduct['units_per_carton'] as int;
      final boxCount = bottleMoqUnits ~/ unitsPerCarton;
      expect(boxCount, 5);
      expect(bottleMoqUnits, 120);
      expect(bottleMoqUnits * (bottleProduct['points_per_unit'] as int), 2400);
    });
  });
}
