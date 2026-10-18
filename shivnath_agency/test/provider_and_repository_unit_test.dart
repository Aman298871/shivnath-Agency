import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/providers/product_provider.dart';
import 'package:shivnath_agency/core/repositories/inventory_repository.dart';
import 'package:shivnath_agency/core/repositories/order_repository.dart';
import 'package:shivnath_agency/core/services/support_desk_service.dart';

void main() {
  group('SupportDeskService Admin Phone Verification Tests', () {
    test('Admin contact uses authoritative admin phone 9826421818', () {
      expect(SupportDeskService.adminPhone, contains('98264 21818'));
      expect(SupportDeskService.formatCleanPhone(SupportDeskService.adminPhone), contains('9826421818'));

      final adminContact = SupportDeskService.adminContact;
      expect(adminContact.phone, contains('98264 21818'));
      expect(SupportDeskService.formatCleanPhone(adminContact.phone), contains('9826421818'));
      expect(adminContact.role, 'admin');
    });

    test('fetchAllSupportContacts returns admin contact with 9826421818', () async {
      final contacts = await SupportDeskService.fetchAllSupportContacts();
      expect(contacts.isNotEmpty, true);

      final admin = contacts.firstWhere((c) => c.role.toLowerCase() == 'admin');
      expect(admin.phone, contains('98264 21818'));
    });

    test('fetchSupportContact for admin returns adminContact', () async {
      final contact = await SupportDeskService.fetchSupportContact(role: 'admin');
      expect(contact.phone, contains('98264 21818'));
      expect(contact.role, 'admin');
    });
  });

  group('ProductProvider Unit Tests', () {
    test('ProductProvider initializes with default state and updates filters', () {
      final provider = ProductProvider();
      expect(provider.isLoading, false);
      expect(provider.errorMessage, isNull);
      expect(provider.selectedCategory, 'All');
      expect(provider.searchQuery, '');
      expect(provider.products, isEmpty);
      expect(provider.filteredProducts, isEmpty);

      provider.setCategory('Packaged Water');
      expect(provider.selectedCategory, 'Packaged Water');

      provider.setSearchQuery('mineral');
      expect(provider.searchQuery, 'mineral');
    });

    test('ProductProvider getProductById returns null for missing product', () {
      final provider = ProductProvider();
      expect(provider.getProductById(999), isNull);
    });
  });

  group('InventoryRepository Mapping Tests', () {
    test('mapItem maps backend schema to UI format', () {
      final repo = InventoryRepository();
      final raw = {
        'id': 10,
        'name': '20L Empty Jars',
        'item_type': 'raw_material',
        'sku': 'RM-JAR-20L',
        'unit': 'piece',
        'stock': 250,
        'min_stock': 50,
        'purchase_rate': '35.50',
        'batch': 'B-2026-001',
        'supplier': 'Plastics Corp',
      };

      final mapped = repo.mapItem(raw);
      expect(mapped['id'], 10);
      expect(mapped['name'], '20L Empty Jars');
      expect(mapped['type'], 'Raw Material');
      expect(mapped['stock'], 250);
      expect(mapped['purchaseRate'], 35.50);
    });

    test('mapStockRequest transforms request fields accurately', () {
      final repo = InventoryRepository();
      final raw = {
        'id': 5,
        'item_id': 10,
        'item_name': '20L Empty Jars',
        'request_type': 'restock',
        'quantity': 100,
        'requested_by_name': 'Franchise A',
        'created_at': '2026-10-18T10:00:00Z',
        'status': 'pending',
        'reason': 'Low inventory',
      };

      final mapped = repo.mapStockRequest(raw);
      expect(mapped['id'], 5);
      expect(mapped['itemId'], 10);
      expect(mapped['itemName'], '20L Empty Jars');
      expect(mapped['quantity'], 100);
      expect(mapped['reason'], 'Low inventory');
    });
  });

  group('OrderRepository Mapping Tests', () {
    test('mapOrder correctly parses order details', () {
      final repo = OrderRepository();
      final raw = {
        'id': 201,
        'order_id': 'ORD-201',
        'customer_name': 'Amit Verma',
        'customer_phone': '9826421818',
        'delivery_address': 'Main Road, Raipur',
        'amount': '1200.00',
        'amount_paid': '1200.00',
        'status': 'Delivered',
        'items': [],
      };

      final mapped = repo.mapOrder(raw);
      expect(mapped['id'], 201);
      expect(mapped['customer_name'], 'Amit Verma');
      expect(mapped['amount'], 1200.0);
      expect(mapped['amount_paid'], 1200.0);
      expect(mapped['status'], 'Delivered');
    });
  });
}
