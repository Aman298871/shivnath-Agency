import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'session_service.dart';

class StockService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  final SessionService _sessionService = SessionService();

  Future<Map<String, String>> _headers() async {
    final token = await _sessionService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================
  // CUSTOMER: GET MY STOCK CYCLES
  // =========================================================
  Future<Map<String, dynamic>> getCustomerStock() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/accounts/customer/stock/'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to load stock data',
        'data': decoded
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.'
      };
    }
  }

  // =========================================================
  // FRANCHISE: GET CUSTOMER STOCK CYCLES
  // =========================================================
  Future<Map<String, dynamic>> getFranchiseCustomerStocks({
    String? filter,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (filter != null && filter.isNotEmpty && filter != 'all') {
        queryParams['filter'] = filter;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/api/accounts/franchise/customer-stocks/')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to fetch customer stocks',
        'data': decoded
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.'
      };
    }
  }

  // =========================================================
  // ADMIN: GET ALL STOCK CYCLES & METRICS
  // =========================================================
  Future<Map<String, dynamic>> getAdminStocks({
    String? filter,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (filter != null && filter.isNotEmpty && filter != 'all') {
        queryParams['filter'] = filter;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/api/accounts/admin/stocks/')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to fetch admin stock data',
        'data': decoded
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.'
      };
    }
  }

  // =========================================================
  // CUSTOMER NOTIFICATIONS
  // =========================================================
  Future<Map<String, dynamic>> getCustomerNotifications() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/accounts/customer/notifications/'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to load notifications',
        'data': decoded
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.'
      };
    }
  }

  Future<Map<String, dynamic>> markCustomerNotificationsAsRead({
    int? id,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/accounts/customer/notifications/'),
            headers: await _headers(),
            body: jsonEncode(id != null ? {'id': id} : {}),
          )
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to mark notifications read',
        'data': decoded
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.'
      };
    }
  }
}
