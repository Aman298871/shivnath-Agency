import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class PackagingService {
  static final PackagingService _instance = PackagingService._internal();
  factory PackagingService() => _instance;
  PackagingService._internal();

  static const String _rulesCacheKey = 'cached_moq_packaging_rules_v1';

  Future<void> _cacheRules(List<dynamic> rules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rulesCacheKey, jsonEncode(rules));
    } catch (_) {}
  }

  Future<List<dynamic>?> _getCachedRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_rulesCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await SessionService().getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _extractErrorMessage(dynamic decoded, int statusCode, String fallback) {
    if (decoded is Map) {
      if (decoded['message'] != null && decoded['message'].toString().trim().isNotEmpty) {
        return decoded['message'].toString().trim();
      }
      if (decoded['error'] != null && decoded['error'].toString().trim().isNotEmpty) {
        return decoded['error'].toString().trim();
      }
      if (decoded['detail'] != null && decoded['detail'].toString().trim().isNotEmpty) {
        return decoded['detail'].toString().trim();
      }
      if (decoded['errors'] != null) {
        final errs = decoded['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final firstKey = errs.keys.first;
          final firstVal = errs[firstKey];
          if (firstVal is List && firstVal.isNotEmpty) {
            return '$firstKey: ${firstVal.first}';
          }
          return '$firstKey: $firstVal';
        }
        return errs.toString();
      }
    }
    return 'HTTP $statusCode: $fallback';
  }

  Future<Map<String, dynamic>> getPackagingRules() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/');
      final res = await ApiClient.get(url, headers: await _authHeaders()).timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = decoded is List ? decoded : (decoded['rules'] ?? decoded['data'] ?? []);
        final listTyped = list is List ? list : [];
        await _cacheRules(listTyped);
        return {'success': true, 'rules': listTyped};
      }
      final cached = await _getCachedRules();
      return {
        'success': false,
        'message': _extractErrorMessage(decoded, res.statusCode, 'Failed to load rules.${cached != null ? " Showing saved local cache." : ""}'),
        'rules': cached ?? [],
        'is_cached': cached != null,
      };
    } catch (e) {
      final cached = await _getCachedRules();
      return {
        'success': false,
        'message': 'Network/Server Error: $e.${cached != null ? " Showing saved local cache." : ""}',
        'rules': cached ?? [],
        'is_cached': cached != null,
      };
    }
  }

  Future<Map<String, dynamic>> createPackagingRule(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data)).timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _extractErrorMessage(decoded, res.statusCode, 'Failed to create rule')};
    } catch (e) {
      return {'success': false, 'message': 'Network/Server Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updatePackagingRule(int id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/$id/');
      final res = await ApiClient.patch(url, headers: await _authHeaders(), body: jsonEncode(data)).timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _extractErrorMessage(decoded, res.statusCode, 'Failed to update rule')};
    } catch (e) {
      return {'success': false, 'message': 'Network/Server Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deletePackagingRule(int id) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/$id/');
      final res = await ApiClient.delete(url, headers: await _authHeaders()).timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true};
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {}
      return {'success': false, 'message': _extractErrorMessage(decoded, res.statusCode, 'Failed to delete rule')};
    } catch (e) {
      return {'success': false, 'message': 'Network/Server Error: $e'};
    }
  }
}
