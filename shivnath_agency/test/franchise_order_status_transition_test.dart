import 'package:flutter_test/flutter_test.dart';
import 'package:shivnath_agency/core/repositories/order_repository.dart';
import 'package:shivnath_agency/core/services/OrderService.dart';

void main() {
  group('Franchise Order Status Canonicalization and State Machine Tests', () {
    final orderRepo = OrderRepository();

    test('OrderService.statusToApi canonicalizes statuses matching Django choices', () {
      expect(OrderService.statusToApi('Dispatched'), 'dispatch');
      expect(OrderService.statusToApi('dispatch'), 'dispatch');
      expect(OrderService.statusToApi('Delivered'), 'delivered');
      expect(OrderService.statusToApi('Completed'), 'delivered');
      expect(OrderService.statusToApi('Plant Approved'), 'plant_approval');
      expect(OrderService.statusToApi('Approved'), 'plant_approval');
      expect(OrderService.statusToApi('Invoice Generated'), 'invoice_generated');
      expect(OrderService.statusToApi('Cancelled'), 'cancelled');
    });

    test('OrderRepository.canonicalStatus normalizes legacy aliases and underscores', () {
      expect(orderRepo.canonicalStatus('dispatched'), 'dispatch');
      expect(orderRepo.canonicalStatus('completed'), 'delivered');
      expect(orderRepo.canonicalStatus('approved'), 'plant_approval');
      expect(orderRepo.canonicalStatus('invoice_generated'), 'invoice_generated');
      expect(orderRepo.canonicalStatus('Invoice Generated'), 'invoice_generated');
    });

    test('Allowed transitions from invoice_generated forbid direct delivery', () {
      final allowed = orderRepo.getAllowedNextStatuses('invoice_generated');
      expect(allowed, contains('preparing'));
      expect(allowed, contains('dispatch'));
      expect(allowed, contains('cancelled'));
      // Delivering directly from invoice_generated is strictly invalid
      expect(allowed, isNot(contains('delivered')));
    });

    test('Allowed transitions from dispatch allow delivered', () {
      final allowed = orderRepo.getAllowedNextStatuses('dispatch');
      expect(allowed, contains('delivered'));
      expect(allowed, contains('cancelled'));
    });

    test('Terminal statuses have zero allowed transitions', () {
      expect(orderRepo.getAllowedNextStatuses('delivered'), isEmpty);
      expect(orderRepo.getAllowedNextStatuses('cancelled'), isEmpty);
    });

    test('OrderRepository.getStatusLabel formats labels cleanly', () {
      expect(orderRepo.getStatusLabel('dispatch'), 'Dispatched / In Transit');
      expect(orderRepo.getStatusLabel('delivered'), 'Delivered');
      expect(orderRepo.getStatusLabel('invoice_generated'), 'Invoice Generated');
      expect(orderRepo.getStatusLabel('plant_approval'), 'Plant Approval');
    });
  });
}
