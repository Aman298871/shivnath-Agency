import 'package:flutter/foundation.dart';
import '../repositories/inventory_repository.dart';

class InventoryProvider extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;

  InventoryProvider({InventoryRepository? inventoryRepository})
      : _inventoryRepository = inventoryRepository ?? InventoryRepository();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _rawMaterials = [];
  List<Map<String, dynamic>> _stockRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  List<Map<String, dynamic>> get rawMaterials => List.unmodifiable(_rawMaterials);
  List<Map<String, dynamic>> get stockRequests => List.unmodifiable(_stockRequests);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadInventory({bool forceRefresh = false}) async {
    if (_items.isNotEmpty && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _inventoryRepository.getItems();
      if (res['success'] == true && res['data'] is List) {
        _items = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _errorMessage = res['message']?.toString();
      }
    } catch (e) {
      _errorMessage = 'Error loading inventory: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRawMaterials() async {
    try {
      final res = await _inventoryRepository.getRawMaterials();
      if (res['success'] == true && res['data'] is List) {
        _rawMaterials = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[InventoryProvider] loadRawMaterials error: $e');
    }
  }

  Future<void> loadStockRequests({String? status, bool forceRefresh = false}) async {
    if (_stockRequests.isNotEmpty && !forceRefresh) return;

    _isLoading = true;
    notifyListeners();

    try {
      final res = await _inventoryRepository.getDealerStockRequests(status: status);
      if (res['success'] == true && res['data'] is List) {
        _stockRequests = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[InventoryProvider] loadStockRequests error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> createStockRequest(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _inventoryRepository.createDealerStockRequest(data);
      if (res['success'] == true) {
        await loadStockRequests(forceRefresh: true);
      }
      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> approveStockRequest(int id, {String? notes}) async {
    final res = await _inventoryRepository.approveDealerStockRequest(id, notes: notes);
    if (res['success'] == true) {
      await loadStockRequests(forceRefresh: true);
    }
    return res;
  }

  Future<Map<String, dynamic>> rejectStockRequest(int id, {String? reason}) async {
    final res = await _inventoryRepository.rejectDealerStockRequest(id, reason: reason);
    if (res['success'] == true) {
      await loadStockRequests(forceRefresh: true);
    }
    return res;
  }

  Future<void> refresh() async {
    await Future.wait([
      loadInventory(forceRefresh: true),
      loadRawMaterials(),
      loadStockRequests(forceRefresh: true),
    ]);
  }
}
