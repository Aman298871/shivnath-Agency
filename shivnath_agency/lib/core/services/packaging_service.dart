import 'dart:convert';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class PackagingService {
  static final PackagingService _instance = PackagingService._internal();
  factory PackagingService() => _instance;
  PackagingService._internal();

  Future<Map<String, String>> _authHeaders() async {
    final token = await SessionService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> getPackagingRules() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/');
      final res = await ApiClient.get(url, headers: await _authHeaders());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List ? decoded : (decoded['rules'] ?? decoded['data'] ?? []);
        return {'success': true, 'rules': list};
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}: Failed to load rules'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createPackagingRule(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to create rule'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePackagingRule(int id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/$id/');
      final res = await ApiClient.patch(url, headers: await _authHeaders(), body: jsonEncode(data));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to update rule'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePackagingRule(int id) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/$id/');
      final res = await ApiClient.delete(url, headers: await _authHeaders());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true};
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
