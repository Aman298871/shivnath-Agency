import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'session_service.dart';

class CustomerService {
  final SessionService _sessionService = SessionService();

  Future<String?> _getToken() async {
    return await _sessionService.getAccessToken();
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('message')) {
          return decoded['message'].toString();
        }
        if (decoded.containsKey('detail')) {
          return decoded['detail'].toString();
        }
        if (decoded.containsKey('error')) {
          return decoded['error'].toString();
        }
      }
    } catch (_) {}
    return 'Request failed with status code ${response.statusCode}';
  }

  /// Get paginated authoritative customer directory with filters and metrics
  Future<Map<String, dynamic>> getCustomers({
    String? search,
    String? status,
    String? zone,
    String? franchise,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.trim().isNotEmpty && status.toLowerCase() != 'all') {
        queryParams['status'] = status.trim().toLowerCase();
      }
      if (zone != null && zone.trim().isNotEmpty && zone.toLowerCase() != 'all') {
        queryParams['zone'] = zone.trim();
      }
      if (franchise != null && franchise.trim().isNotEmpty && franchise.toLowerCase() != 'all') {
        queryParams['franchise'] = franchise.trim();
      }
      if (dateFrom != null && dateFrom.trim().isNotEmpty) {
        queryParams['date_from'] = dateFrom.trim();
      }
      if (dateTo != null && dateTo.trim().isNotEmpty) {
        queryParams['date_to'] = dateTo.trim();
      }

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/admin/customers/')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': _errorMessage(response),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load customer directory: $e',
      };
    }
  }

  /// Get comprehensive customer details including profile, attribution, stats, and paginated order history
  Future<Map<String, dynamic>> getCustomerDetail(
    int customerId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/admin/customers/$customerId/')
          .replace(queryParameters: queryParams);

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': _errorMessage(response),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load customer profile: $e',
      };
    }
  }

  /// Get authoritative untruncated Admin Dashboard metrics across all models
  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/auth/admin/dashboard-stats/');

      final response = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message': _errorMessage(response),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to load dashboard metrics: $e',
      };
    }
  }
}
