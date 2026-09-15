import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
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
    String? status,
  }) async {
    try {
      final query =
          <String, String>{};

      if (search != null &&
          search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }

      if (category != null &&
          category != 'All') {
        query['category'] = category;
      }

      if (status != null &&
          status.trim().isNotEmpty) {
        query['status'] = status;
      }

      final uri = Uri.parse(
        '$baseUrl/api/products/',
      ).replace(
        queryParameters:
            query.isEmpty ? null : query,
      );

      final response = await http.get(
  uri,
  headers: await _headers(),
);

final result = _decode(response);

      if (result["success"] == true && result["data"] is Map) {
        final rawList = result["data"]["products"];
        if (rawList is List) {
          products = rawList
              .whereType<Map>()
              .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        } else {
          products = [];
        }
      }

return result;
    } catch (e) {
      return {
        "success": false,
        "message":
            "Unable to connect : $e",
      };
    }
  }

  //=========================================
  // PRODUCT DETAIL
  //=========================================

  Future<Map<String, dynamic>> getProduct(
      int id) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/products/$id/'),
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Unable to connect : $e",
      };
    }
  }

  //=========================================
  // CREATE
  //=========================================

  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> data) async {
    try {
      final response = await http.post(
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
            "Unable to connect : $e",
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
      final response = await http.patch(
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
            "Unable to connect : $e",
      };
    }
  }

  //=========================================
  // DELETE
  //=========================================

  Future<Map<String, dynamic>> deleteProduct(
      int id) async {
    try {
      final response = await http.delete(
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
            "Unable to connect : $e",
      };
    }
  }

  //=========================================
  // STATS
  //=========================================

  Future<Map<String, dynamic>>
      getStats() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/products/stats/'),
        headers: await _headers(),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Unable to connect : $e",
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

    return {
      "success": false,
      "message":
          decoded["message"] ??
              "Something went wrong.",
      "data": decoded,
    };
  }
}