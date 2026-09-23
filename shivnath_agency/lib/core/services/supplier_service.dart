import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class SupplierService {
  static String get baseUrl => AppConstants.apiBaseUrl;

  final SessionService _sessionService = SessionService();
  final http.Client _client = ApiClient.client;


  Future<Map<String, String>> _headers() async {
    final token = await _sessionService.getAccessToken();

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty)
        'Authorization': 'Bearer $token',
    };
  }

  //==========================
  // GET SUPPLIERS
  //==========================

  Future<Map<String, dynamic>> getSuppliers({
    String? search,
    String? category,
    String? status,
  }) async {
    try {
      final query = <String, String>{};

      if (search != null && search.trim().isNotEmpty) {
        query["search"] = search.trim();
      }

      if (category != null &&
          category.trim().isNotEmpty &&
          category != "All") {
        query["category"] = category;
      }

      if (status != null &&
          status.trim().isNotEmpty &&
          status != "All") {
        query["status"] = status;
      }

      final uri = Uri.parse(
        "$baseUrl/api/suppliers/",
      ).replace(
        queryParameters:
            query.isEmpty ? null : query,
      );

      final response = await _client.get(
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

  //==========================
  // DETAIL
  //==========================

  Future<Map<String, dynamic>> getSupplier(
      int id) async {
    try {
      final response = await _client.get(
        Uri.parse(
          "$baseUrl/api/suppliers/$id/",
        ),
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

  //==========================
  // CREATE
  //==========================

  Future<Map<String, dynamic>> createSupplier(
      Map<String, dynamic> body) async {
    try {
      final response = await _client.post(
        Uri.parse(
          "$baseUrl/api/suppliers/",
        ),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //==========================
  // UPDATE
  //==========================

  Future<Map<String, dynamic>> updateSupplier(
    int id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.patch(
        Uri.parse(
          "$baseUrl/api/suppliers/$id/",
        ),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      return _decode(response);
    } catch (e) {
      return {
        "success": false,
        "message": "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  //==========================
  // DELETE
  //==========================

  Future<Map<String, dynamic>> deleteSupplier(
      int id) async {
    try {
      final response = await _client.delete(
        Uri.parse(
          "$baseUrl/api/suppliers/$id/",
        ),
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

  //==========================
  // STATS
  //==========================

  Future<Map<String, dynamic>>
      getStats() async {
    try {
      final response = await _client.get(
        Uri.parse(
          "$baseUrl/api/suppliers/stats/",
        ),
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

  //==========================
  // RESPONSE
  //==========================

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