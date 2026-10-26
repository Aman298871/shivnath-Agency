import '../services/product_service.dart';
import '../../models/product_model.dart';

class ProductRepository {
  final ProductService _productService;

  ProductRepository({ProductService? productService})
      : _productService = productService ?? ProductService();

  static List<ProductModel> get cachedProducts => ProductService.products;
  List<ProductModel> get products => ProductService.products;

  Future<Map<String, dynamic>> getProducts({
    String? search,
    String? category,
    int? categoryId,
    String? status,
    bool? activeOnly,
  }) async {
    return await _productService.getProducts(
      search: search,
      category: category,
      categoryId: categoryId,
      status: status,
      activeOnly: activeOnly,
    );
  }

  Future<Map<String, dynamic>> getProduct(int id) async {
    return await _productService.getProduct(id);
  }

  Future<Map<String, dynamic>> getCategories({
    bool treeOnly = false,
    bool activeOnly = false,
    bool hasActiveProducts = false,
  }) async {
    return await _productService.getCategories(
      treeOnly: treeOnly,
      activeOnly: activeOnly,
      hasActiveProducts: hasActiveProducts,
    );
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    return await _productService.createCategory(data);
  }

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) async {
    return await _productService.updateCategory(id, data);
  }

  Future<Map<String, dynamic>> deleteCategory(int id) async {
    return await _productService.deleteCategory(id);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    return await _productService.createProduct(data);
  }

  Future<Map<String, dynamic>> updateProduct(int id, Map<String, dynamic> data) async {
    return await _productService.updateProduct(id, data);
  }

  Future<Map<String, dynamic>> updateProductPricing(int id, Map<String, dynamic> data) async {
    return await _productService.updateProductPricing(id, data);
  }

  Future<Map<String, dynamic>> deleteProduct(int id) async {
    return await _productService.deleteProduct(id);
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _productService.getStats();
  }
}
