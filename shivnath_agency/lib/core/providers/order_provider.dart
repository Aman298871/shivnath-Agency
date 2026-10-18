import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;

  OrderProvider({OrderRepository? orderRepository})
      : _orderRepository = orderRepository ?? OrderRepository();

  List<Map<String, dynamic>> _orders = [];
  String _selectedStatus = 'All';
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get orders => List.unmodifiable(_orders);
  String get selectedStatus => _selectedStatus;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get filteredOrders {
    return _orders.where((o) {
      final status = (o['status'] ?? '').toString().toLowerCase();
      final code = (o['order_code'] ?? o['id'] ?? '').toString().toLowerCase();
      final customer = (o['customer_name'] ?? '').toString().toLowerCase();

      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          code.contains(_searchQuery.toLowerCase()) ||
          customer.contains(_searchQuery.toLowerCase());

      return matchesStatus && matchesSearch;
    }).toList();
  }

  int get pendingCount => _orders.where((o) {
        final s = (o['status'] ?? '').toString().toLowerCase();
        return s == 'pending' || s == 'processing' || s == 'order_placed';
      }).length;

  Future<void> loadOrders({bool forceRefresh = false}) async {
    if (_orders.isNotEmpty && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _orderRepository.getOrders(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        status: _selectedStatus != 'All' ? _selectedStatus : null,
      );

      if (res['success'] == true) {
        List rawList = [];
        if (res['data'] is Map && res['data']['orders'] is List) {
          rawList = res['data']['orders'] as List;
        } else if (res['data'] is List) {
          rawList = res['data'] as List;
        }
        _orders = rawList
            .whereType<Map>()
            .map((e) => _orderRepository.mapOrder(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _errorMessage = res['message']?.toString() ?? 'Failed to load orders';
      }
    } catch (e) {
      _errorMessage = 'Error loading orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setStatusFilter(String status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _orderRepository.createOrder(data);
      if (res['success'] == true) {
        await loadOrders(forceRefresh: true);
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Create order error: $e'};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final res = await _orderRepository.updateOrderStatus(orderId, newStatus);
      if (res['success'] == true) {
        // Optimistically update local list
        final index = _orders.indexWhere((o) => (o['id'] as int? ?? 0) == orderId);
        if (index != -1) {
          _orders[index]['status'] = newStatus;
          notifyListeners();
        }
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Status update error: $e'};
    }
  }

  Future<void> refresh() async {
    await loadOrders(forceRefresh: true);
  }

  Map<String, dynamic>? getOrderById(int id) {
    try {
      return _orders.firstWhere((o) => (o['id'] as int? ?? 0) == id);
    } catch (_) {
      return null;
    }
  }
}
