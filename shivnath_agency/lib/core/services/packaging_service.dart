import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class PackagingService {
  static final PackagingService _instance = PackagingService._internal();
  factory PackagingService() => _instance;
  PackagingService._internal() {
    loadCachedRules();
  }

  static const String _rulesCacheKey = 'cached_moq_packaging_rules_v1';

  List<Map<String, dynamic>> _inMemoryRules = [];
  List<Map<String, dynamic>> get rules => List.unmodifiable(_inMemoryRules);

  int? _currentServingFranchiseId;
  int? get currentServingFranchiseId => _currentServingFranchiseId;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _lastError;
  String? get lastError => _lastError;

  void setCurrentServingFranchise(int? franchiseId) {
    _currentServingFranchiseId = franchiseId;
  }

  Future<void> loadCachedRules() async {
    try {
      final cached = await _getCachedRules();
      if (cached != null) {
        _inMemoryRules = cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
  }

  /// Resolves the effective packaging & MOQ rule using Policy A:
  /// Effective MOQ = max(Admin Baseline MOQ, Serving Franchise MOQ).
  /// Admin baseline is mandatory; a franchise may increase MOQ but never lower it.
  Map<String, dynamic>? getRuleForProduct(
    dynamic productId, {
    String channel = 'CUSTOMER',
    int? franchiseId,
  }) {
    final pidStr = productId?.toString().trim();
    if (pidStr == null || pidStr.isEmpty) return null;

    final targetFranchiseId = franchiseId ?? _currentServingFranchiseId;
    final chUpper = channel.toUpperCase();

    // 1. Find Admin Baseline rule (where franchise is null)
    Map<String, dynamic>? baselineRule;
    for (final r in _inMemoryRules) {
      if (r['is_active'] == false) continue;
      final appliesTo = (r['applies_to'] ?? r['channel'] ?? 'ALL').toString().toUpperCase();
      if (appliesTo != 'ALL' && appliesTo != chUpper) continue;

      final isFranchiseSpecific = r['franchise'] != null || r['franchise_id'] != null;
      if (isFranchiseSpecific) continue;

      final rPid = (r['product'] ?? r['product_id'])?.toString().trim();
      if (rPid == pidStr) {
        baselineRule = r;
        break;
      }
    }

    // 2. If a serving franchise is specified and baseline allows override, evaluate franchise override
    if (targetFranchiseId != null && baselineRule != null && baselineRule['allow_franchise_override'] == true) {
      Map<String, dynamic>? franchiseRule;
      for (final r in _inMemoryRules) {
        if (r['is_active'] == false) continue;
        final appliesTo = (r['applies_to'] ?? r['channel'] ?? 'ALL').toString().toUpperCase();
        if (appliesTo != 'ALL' && appliesTo != chUpper) continue;

        final fId = (r['franchise'] ?? r['franchise_id'])?.toString().trim();
        if (fId == targetFranchiseId.toString().trim()) {
          final rPid = (r['product'] ?? r['product_id'])?.toString().trim();
          if (rPid == pidStr) {
            franchiseRule = r;
            break;
          }
        }
      }

      if (franchiseRule != null) {
        final bMoq = (baselineRule['min_order_quantity'] as num?)?.toInt() ?? 1;
        final fMoq = (franchiseRule['min_order_quantity'] as num?)?.toInt() ?? 1;
        final maxFMoq = (baselineRule['max_franchise_moq'] as num?)?.toInt();

        // Policy A Invariant: Franchise can increase minimum, but CANNOT reduce Admin minimum
        if (fMoq >= bMoq) {
          if (maxFMoq == null || fMoq <= maxFMoq) {
            return franchiseRule;
          }
        }
        // If franchise tried to lower MOQ below baseline or exceed max ceiling, fall back to Admin baseline
        return baselineRule;
      }
    }

    return baselineRule;
  }

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

  Future<Map<String, dynamic>> getPackagingRules({int? franchiseId, String? channel}) async {
    _isLoading = true;
    _lastError = null;
    try {
      final queryParams = <String, String>{};
      if (channel != null && channel.isNotEmpty) queryParams['channel'] = channel;
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/api/products/packaging-rules/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final res = await ApiClient.get(uri, headers: await _authHeaders()).timeout(const Duration(seconds: 35));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = decoded is List ? decoded : (decoded['rules'] ?? decoded['data'] ?? []);
        final listTyped = list is List ? list : [];
        _inMemoryRules = listTyped.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        await _cacheRules(listTyped);
        _isLoading = false;
        return {'success': true, 'rules': listTyped};
      }
      final err = _extractErrorMessage(decoded, res.statusCode, 'Failed to load rules.');
      _lastError = err;
      final cached = await _getCachedRules();
      if (cached != null) {
        _inMemoryRules = cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      _isLoading = false;
      return {
        'success': false,
        'message': '$err${cached != null ? " Showing saved local cache." : ""}',
        'rules': cached ?? [],
        'is_cached': cached != null,
      };
    } catch (e) {
      _lastError = 'Network/Server Error: $e';
      final cached = await _getCachedRules();
      if (cached != null) {
        _inMemoryRules = cached.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      _isLoading = false;
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
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data)).timeout(const Duration(seconds: 35));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Refresh rules in background to keep in-memory cache synchronized without blocking caller
        getPackagingRules().catchError((_) => <String, dynamic>{});
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
      final res = await ApiClient.patch(url, headers: await _authHeaders(), body: jsonEncode(data)).timeout(const Duration(seconds: 35));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Refresh rules in background to keep in-memory cache synchronized without blocking caller
        getPackagingRules().catchError((_) => <String, dynamic>{});
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
      final res = await ApiClient.delete(url, headers: await _authHeaders()).timeout(const Duration(seconds: 35));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        getPackagingRules().catchError((_) => <String, dynamic>{});
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
