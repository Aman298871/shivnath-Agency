import 'package:flutter/foundation.dart';
import '../../models/product_model.dart';
import '../repositories/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepository;

  ProductProvider({ProductRepository? productRepository})
      : _productRepository = productRepository ?? ProductRepository();

  List<ProductModel> _products = [];
  List<Map<String, dynamic>> _rawProducts = [];
  List<Map<String, dynamic>> _categories = [];
  String _selectedCategory = 'All';
  int? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  List<ProductModel> get products => List.unmodifiable(_products);
  List<Map<String, dynamic>> get rawProducts => List.unmodifiable(_rawProducts);
  List<Map<String, dynamic>> get categories => List.unmodifiable(_categories);
  String get selectedCategory => _selectedCategory;
  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ProductModel> get filteredProducts {
    return _products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          p.category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> loadProducts({
    String? category,
    int? categoryId,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (category != null) _selectedCategory = category;
    if (categoryId != null) _selectedCategoryId = categoryId;
    if (search != null) _searchQuery = search;

    if (_products.isNotEmpty && !forceRefresh && category == null && categoryId == null && search == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _productRepository.getProducts(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        category: _selectedCategory != 'All' ? _selectedCategory : null,
        categoryId: _selectedCategoryId,
        activeOnly: true,
      );

      if (res['success'] == true) {
        if (res['parsed_products'] is List<ProductModel>) {
          _products = res['parsed_products'] as List<ProductModel>;
        } else if (res['data'] is List) {
          _products = (res['data'] as List)
              .whereType<Map>()
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (res['data'] is List) {
          _rawProducts = (res['data'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } else {
        _errorMessage = res['message']?.toString() ?? 'Failed to load products';
      }
    } catch (e) {
      _errorMessage = 'Error loading products: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      final res = await _productRepository.getCategories(activeOnly: true);
      if (res['success'] == true && res['data'] is List) {
        _categories = (res['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ProductProvider] loadCategories error: $e');
    }
  }

  void setCategory(String category, {int? categoryId}) {
    _selectedCategory = category;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<void> refresh() async {
    await Future.wait([
      loadProducts(forceRefresh: true),
      loadCategories(),
    ]);
  }

  ProductModel? getProductById(int id) {
    try {
      return _products.firstWhere((p) => p.id == id.toString());
    } catch (_) {
      return null;
    }
  }
}
