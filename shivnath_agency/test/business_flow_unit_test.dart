import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/services/OrderService.dart';
import 'package:shivnath_agency/features/customer/cart/cart_provider.dart';
import 'package:shivnath_agency/models/product_model.dart';
import 'package:shivnath_agency/core/utils/contact_action_helper.dart';

void main() {
  group('OrderService Unit Tests', () {
    test('mapOrder correctly parses amount, paid amount, and outstanding balance', () {
      final orderService = OrderService();
      final rawBackendData = {
        'id': 105,
        'order_id': 'ORD-105',
        'franchise_name': 'Shivnath Raipur',
        'customer_name': 'Rahul Sharma',
        'customer_phone': '9876543210',
        'delivery_address': 'Sector 5, Raipur',
        'city': 'Raipur',
        'order_date': '2026-09-25T10:00:00Z',
        'items_count': 50,
        'amount': '15000.00',
        'amount_paid': '5000.00',
        'outstanding_amount': '10000.00',
        'status': 'Plant Approval',
        'payment_status': 'partial',
        'items': [
          {
            'product_name': '500 ML Packaged Water',
            'quantity': 50,
            'unit_price': 300,
            'total_price': 15000,
          }
        ],
      };

      final mapped = orderService.mapOrder(rawBackendData);

      expect(mapped['id'], 105);
      expect(mapped['customer_name'], 'Rahul Sharma');
      expect(mapped['customer_phone'], '9876543210');
      expect(mapped['amount'], 15000.0);
      expect(mapped['amount_paid'], 5000.0);
      expect(mapped['outstanding_amount'], 10000.0);
      expect(mapped['status'], 'Plant Approval');
      expect(mapped['payment'], 'Partial');
      expect((mapped['items_list'] as List).length, 1);
    });

    test('normalizeStatusDisplay standardizes status strings', () {
      expect(OrderService.normalizeStatusDisplay('order_placement'), 'Order Placement');
      expect(OrderService.normalizeStatusDisplay('plant_approval'), 'Plant Approval');
      expect(OrderService.normalizeStatusDisplay('admin approved'), 'Plant Approval');
      expect(OrderService.normalizeStatusDisplay('preparing / bottling'), 'Preparing');
      expect(OrderService.normalizeStatusDisplay('dispatched'), 'Dispatched');
      expect(OrderService.normalizeStatusDisplay('delivered'), 'Delivered');
      expect(OrderService.normalizeStatusDisplay('cancelled'), 'Cancelled');
    });
  });

  group('CartProvider Unit Tests', () {
    test('Cart accurately tracks item count, total price, and clears correctly', () {
      final cart = CartProvider();
      expect(cart.itemCount, 0);
      expect(cart.totalAmount, 0.0);

      const p1 = ProductModel(
        id: '1',
        name: '500ml Water Bottle',
        category: 'Packaged Water',
        size: '500ml',
        price: 20.0,
        stock: 100,
        unit: 'Bottle',
        image: 'assets/images/bottle.png',
        description: 'Pure mineral water',
        sku: 'SHV-500',
      );

      const p2 = ProductModel(
        id: '2',
        name: '20 Litre Water Jar',
        category: 'Water Jar',
        size: '20L',
        price: 80.0,
        stock: 50,
        unit: 'Jar',
        image: 'assets/images/jar.png',
        description: '20L Jar',
        sku: 'SHV-20L',
      );

      cart.addProduct(p1);
      expect(cart.itemCount, 1);
      expect(cart.subtotal, 20.0);
      expect(cart.totalAmount, 50.0); // 20 + 30 delivery charge for orders < 500

      cart.addProduct(p2);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 100.0);
      expect(cart.totalAmount, 130.0); // 100 + 30 delivery charge

      cart.clearCart();
      expect(cart.itemCount, 0);
      expect(cart.subtotal, 0.0);
      expect(cart.totalAmount, 0.0);
    });
  });

  group('ContactActionHelper Tests', () {
    test('cleanPhoneNumber and formatForWhatsApp format correctly', () {
      expect(ContactActionHelper.cleanPhoneNumber('+91 98765-43210'), '+919876543210');
      expect(ContactActionHelper.cleanPhoneNumber('098765 43210'), '09876543210');
      expect(ContactActionHelper.formatForWhatsApp('9876543210'), '919876543210');
      expect(ContactActionHelper.formatForWhatsApp('+919876543210'), '919876543210');
    });
  });
}
