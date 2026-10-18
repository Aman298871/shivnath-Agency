import 'package:flutter/foundation.dart';
import '../repositories/franchise_repository.dart';

class FranchiseProvider extends ChangeNotifier {
  final FranchiseRepository _franchiseRepository;

  FranchiseProvider({FranchiseRepository? franchiseRepository})
      : _franchiseRepository = franchiseRepository ?? FranchiseRepository();

  List<Map<String, dynamic>> _franchises = [];
  List<Map<String, dynamic>> _pendingFranchises = [];
  String _searchQuery = '';
  String _statusFilter = 'All';
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get franchises => List.unmodifiable(_franchises);
  List<Map<String, dynamic>> get pendingFranchises => List.unmodifiable(_pendingFranchises);
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Map<String, dynamic>> get filteredFranchises {
    return _franchises.where((f) {
      final name = (f['name'] ?? f['business_name'] ?? '').toString().toLowerCase();
      final city = (f['city'] ?? '').toString().toLowerCase();
      final status = (f['status'] ?? '').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          city.contains(_searchQuery.toLowerCase());
      final matchesStatus = _statusFilter == 'All' || status == _statusFilter.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<void> loadFranchises({bool forceRefresh = false}) async {
    if (_franchises.isNotEmpty && !forceRefresh) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _franchiseRepository.getFranchises();
      if (res['success'] == true && res['data'] is List) {
        _franchises = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (res['success'] == true && res['data'] is Map && res['data']['franchises'] is List) {
        _franchises = (res['data']['franchises'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        _errorMessage = res['message']?.toString();
      }
    } catch (e) {
      _errorMessage = 'Error loading franchises: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingFranchises({bool forceRefresh = false}) async {
    try {
      final res = await _franchiseRepository.getPendingFranchises();
      if (res['success'] == true && res['data'] is List) {
        _pendingFranchises = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FranchiseProvider] loadPendingFranchises error: $e');
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  Future<Map<String, dynamic>> approveFranchise(int franchiseId, {String? overrideReason}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _franchiseRepository.approveFranchise(franchiseId, overrideReason: overrideReason);
      if (res['success'] == true) {
        // Remove from pending
        _pendingFranchises.removeWhere((f) => (f['id'] as int? ?? 0) == franchiseId);
        await loadFranchises(forceRefresh: true);
      }
      return res;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      loadFranchises(forceRefresh: true),
      loadPendingFranchises(forceRefresh: true),
    ]);
  }
}
