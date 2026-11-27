import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import '../../models/product_model.dart';
class ProductService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  static final List<ProductModel> _defaultCatalog = [
    ProductModel(
      id: "1",
      name: "Shivnath 200ml Event Bottle",
      sku: "SHV-200",
      category: "Water Bottles",
      size: "200 ML",
      price: 5.0,
      mrp: 5.0,
      unit: "Bottle",
      image: "products/bhoomi_200ml.png",
      stock: 500,
      description: "200ml event packaged drinking water bottle",
      status: "Active",
      packageType: "BOTTLE",
      unitsPerCase: 24,
    ),
    ProductModel(
      id: "2",
      name: "Shivnath 250ml Mini Bottle",
      sku: "SHV-250",
      category: "Water Bottles",
      size: "250 ML",
      price: 6.0,
      mrp: 6.0,
      unit: "Bottle",
      image: "products/bhoomi_250ml.png",
      stock: 500,
      description: "250ml mini packaged drinking water bottle",
      status: "Active",
      packageType: "BOTTLE",
      unitsPerCase: 24,
    ),
    ProductModel(
      id: "3",
      name: "Shivnath 500ml Travel Bottle",
      sku: "SHV-500",
      category: "Water Bottles",
      size: "500 ML",
      price: 10.0,
      mrp: 10.0,
      unit: "Bottle",
      image: "products/bhoomi_500ml.png",
      stock: 400,
      description: "500ml travel packaged drinking water bottle",
      status: "Active",
      packageType: "BOTTLE",
      unitsPerCase: 24,
    ),
    ProductModel(
      id: "4",
      name: "Shivnath 1 Litre Premium Mineral Bottle",
      sku: "SHV-1L",
      category: "Water Bottles",
      size: "1 Litre",
      price: 20.0,
      mrp: 20.0,
      unit: "Bottle",
      image: "products/bhoomi_1l.png",
      stock: 349,
      description: "1 Litre premium packaged drinking water bottle",
      status: "Active",
      packageType: "BOTTLE",
      unitsPerCase: 12,
    ),
    ProductModel(
      id: "5",
      name: "Shivnath 20 Litre Dispenser Jar",
      sku: "SHV-20L",
      category: "Water Jars",
      size: "20 Litre",
      price: 60.0,
      mrp: 60.0,
      unit: "Jar",
      image: "products/shv_20l.jpg",
      stock: 180,
      description: "20 Litre returnable dispenser water jar",
      status: "Active",
      packageType: "JAR",
      unitsPerCase: 1,
    ),
  ];

  static List<ProductModel> products = List.from(_defaultCatalog);    

  final SessionService _sessionService =
      SessionService();


  Future<Map<String, String>> _headers() async {
    final token =
        await _sessionService.getAccessToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  //=========================================
  // GET PRODUCTS
  //=========================================

  Future<Map<String, dynamic>> getProducts({
    String? search,
    String? category,
    int? categoryId,
    String? status,
    bool? activeOnly,
  }) async {
    try {
      final query = <String, String>{};

      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      if (category != null && category.trim().isNotEmpty && category != 'All') {
        query['category'] = category.trim();
      }
      if (categoryId != null) {
        query['category_id'] = categoryId.toString();
      }

      if (activeOnly == true) {
        query['active_only'] = 'true';
      }

      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status;
      }

      final uri = Uri.parse(
        '$baseUrl/api/products/',
      ).replace(
        queryParameters:
            query.isEmpty ? null : query,
      );

      final response = await ApiClient.get(
  uri,
  headers: await _headers(),
);

final result = _decode(response);

      if (result["success"] == true) {
        dynamic rawList;
        if (result["products"] is List) {
          rawList = result["products"];
        } else if (result["data"] is Map && result["data"]["products"] is List) {
          rawList = result["data"]["products"];
        } else if (result["data"] is List) {
          rawList = result["data"];
        }

        List<ProductModel> parsedList = [];
        if (rawList is List && rawList.isNotEmpty) {
          parsedList = rawList
              .whereType<Map>()
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          products = parsedList;
        } else {
          parsedList = List.from(_defaultCatalog);
          products = parsedList;
        }
        result['parsed_products'] = parsedList;
      }

      return result;
    } catch (e) {
      return {
        "success": true,
        "data": _defaultCatalog.map((p) => p.toJson()).toList(),
        "parsed_products": List<ProductModel>.from(_defaultCatalog),
        "message": "Loaded default catalog",
      };
    }
  }

  //=========================================
  // PRODUCT DETAIL
  //=========================================

  Future<Map<String, dynamic>> getProduct(
      int id) async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
            '$baseUrl/api/products/$id/'),
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // CREATE
  //=========================================

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(
            '$baseUrl/api/products/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      final result = _decode(response);

if (result["success"] == true) {
  await getProducts();
}

return result;
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // UPDATE
  //=========================================

  Future<Map<String, dynamic>> updateProduct(
      int id,
      Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse(
            '$baseUrl/api/products/$id/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

     final result = _decode(response);

if (result["success"] == true) {
  await getProducts();
}

return result;
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // UPDATE PRICING & PACKAGING
  //=========================================

  Future<Map<String, dynamic>> updateProductPricing(
      int id,
      Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse(
            '$baseUrl/api/products/$id/pricing/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      final result = _decode(response);

      if (result["success"] == true) {
        await getProducts();
      }

      return result;
    } catch (e) {
      return {
        "success": true,
        "data": _defaultCatalog.map((p) => p.toJson()).toList(),
        "parsed_products": List<ProductModel>.from(_defaultCatalog),
        "message": "Loaded default catalog",
      };
    }
  }

  //=========================================
  // DELETE
  //=========================================

  Future<Map<String, dynamic>> deleteProduct(
      int id) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse(
            '$baseUrl/api/products/$id/'),
        headers: await _headers(),
      );

      final result = _decode(response);

if (result["success"] == true) {
  await getProducts();
}

return result;
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // CATEGORIES
  //=========================================

  Future<Map<String, dynamic>> getCategories({
    bool treeOnly = false,
    bool activeOnly = false,
    bool hasActiveProducts = false,
  }) async {
    try {
      final query = <String, String>{};
      if (treeOnly) query['tree'] = 'true';
      if (activeOnly) query['active_only'] = 'true';
      if (hasActiveProducts) query['has_active_products'] = 'true';

      final uri = Uri.parse('$baseUrl/api/products/categories/').replace(
        queryParameters: query.isEmpty ? null : query,
      );

      final response = await ApiClient.get(
        uri,
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/products/categories/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  Future<Map<String, dynamic>> updateCategory(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/api/products/categories/$id/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  Future<Map<String, dynamic>> deleteCategory(int id) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('$baseUrl/api/products/categories/$id/'),
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // STATS
  //=========================================

  Future<Map<String, dynamic>>
      getStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
            '$baseUrl/api/products/stats/'),
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //=========================================
  // RESPONSE
  //=========================================

  Map<String, dynamic> _decode(
      http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {};
    } catch (_) {
      decoded = {};
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return {
        "success": true,
        "data": decoded,
      };
    }

    String message = "Something went wrong.";
    if (decoded is Map<String, dynamic>) {
      if (decoded['code'] == 'token_not_valid' ||
          (decoded['detail'] != null && decoded['detail'].toString().contains('token not valid'))) {
        message = 'Your session has expired. Please log in again.';
        _sessionService.refreshAccessToken();
      } else if (decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    }

    return {
      "success": false,
      "message": message,
      "data": decoded,
    };
  }
}