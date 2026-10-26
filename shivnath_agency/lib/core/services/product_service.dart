import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import '../../models/product_model.dart';
class ProductService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  static List<ProductModel> products = [];    

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
        if (rawList is List) {
          parsedList = rawList
              .whereType<Map>()
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          products = parsedList;
        } else {
          products = [];
        }
        result['parsed_products'] = parsedList;
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
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
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