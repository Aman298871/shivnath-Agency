import 'dart:async';
import 'dart:convert';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryPricingService {
  static final DeliveryPricingService _instance = DeliveryPricingService._internal();
  factory DeliveryPricingService() => _instance;
  DeliveryPricingService._internal();

  static const Duration _timeoutDuration = Duration(seconds: 10);

  static const Map<String, dynamic> fallbackOrigin = {
    'name': 'Shivnath Agency Central Dispatch',
    'depot_name': 'Shivnath Agency Central Dispatch',
    'address': 'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
    'pincode': '492014',
    'latitude': 21.267800,
    'longitude': 81.671100,
    'free_delivery_radius_km': 0.0,
    'max_serviceable_radius_km': 25.0,
    'default_delivery_charge': 30.0,
    'is_active': true,
    'is_fallback': true,
  };

  static const List<Map<String, dynamic>> fallbackBands = [
    {
      'id': 1,
      'name': 'Local Delivery (0-2 km)',
      'label': 'Local Delivery (0-2 km)',
      'min_distance_km': 0.0,
      'max_distance_km': 2.0,
      'delivery_charge': 30.0,
      'is_active': true,
      'is_supported': true,
      'order': 1,
      'is_fallback': true,
    },
    {
      'id': 2,
      'name': 'Sub-Urban Delivery (2-5 km)',
      'label': 'Sub-Urban Delivery (2-5 km)',
      'min_distance_km': 2.0,
      'max_distance_km': 5.0,
      'delivery_charge': 60.0,
      'is_active': true,
      'is_supported': true,
      'order': 2,
      'is_fallback': true,
    },
    {
      'id': 3,
      'name': 'Outskirts Delivery (5-10 km)',
      'label': 'Outskirts Delivery (5-10 km)',
      'min_distance_km': 5.0,
      'max_distance_km': 10.0,
      'delivery_charge': 120.0,
      'is_active': true,
      'is_supported': true,
      'order': 3,
      'is_fallback': true,
    },
    {
      'id': 4,
      'name': 'Extended Delivery (10-25 km)',
      'label': 'Extended Delivery (10-25 km)',
      'min_distance_km': 10.0,
      'max_distance_km': 25.0,
      'delivery_charge': 250.0,
      'is_active': true,
      'is_supported': true,
      'order': 4,
      'is_fallback': true,
    },
    {
      'id': 5,
      'name': 'Regional Delivery (25-50 km)',
      'label': 'Regional Delivery (25-50 km)',
      'min_distance_km': 25.0,
      'max_distance_km': 50.0,
      'delivery_charge': 450.0,
      'is_active': true,
      'is_supported': true,
      'order': 5,
      'is_fallback': true,
    },
    {
      'id': 6,
      'name': 'Inter-District Delivery (50-100 km)',
      'label': 'Inter-District Delivery (50-100 km)',
      'min_distance_km': 50.0,
      'max_distance_km': 100.0,
      'delivery_charge': 850.0,
      'is_active': true,
      'is_supported': true,
      'order': 6,
      'is_fallback': true,
    },
    {
      'id': 7,
      'name': 'Statewide Delivery (100-300 km)',
      'label': 'Statewide Delivery (100-300 km)',
      'min_distance_km': 100.0,
      'max_distance_km': 300.0,
      'delivery_charge': 1500.0,
      'is_active': true,
      'is_supported': true,
      'order': 7,
      'is_fallback': true,
    },
    {
      'id': 8,
      'name': 'Above 300 km Special Freight Review',
      'label': 'Above 300 km Special Freight Review',
      'min_distance_km': 300.0,
      'max_distance_km': null,
      'delivery_charge': 0.0,
      'is_active': true,
      'is_supported': false,
      'order': 8,
      'is_fallback': true,
    },
  ];

  static const String _originCacheKey = 'cached_delivery_origin_v1';
  static const String _bandsCacheKey = 'cached_distance_bands_v1';

  Future<void> _cacheOrigin(Map<String, dynamic> origin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_originCacheKey, jsonEncode(origin));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _getCachedOrigin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_originCacheKey);
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _cacheBands(List<dynamic> bands) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_bandsCacheKey, jsonEncode(bands));
    } catch (_) {}
  }

  Future<List<dynamic>?> _getCachedBands() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_bandsCacheKey);
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

  Future<Map<String, dynamic>> getDeliveryOrigin() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/origin/');
      final res = await ApiClient.get(url, headers: await _authHeaders())
          .timeout(_timeoutDuration);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final originData = (decoded is Map && decoded.containsKey('origin')) ? decoded['origin'] : decoded;
        if (originData is Map) {
          await _cacheOrigin(Map<String, dynamic>.from(originData));
        }
        return {'success': true, 'origin': originData};
      }
      final cached = await _getCachedOrigin();
      return {
        'success': false,
        'message': 'HTTP ${res.statusCode}: Failed to fetch from server.${cached != null ? " Displaying saved local cache." : ""}',
        'origin': cached ?? fallbackOrigin,
        'is_cached': cached != null,
      };
    } on TimeoutException {
      final cached = await _getCachedOrigin();
      return {
        'success': false,
        'message': 'Server request timed out.${cached != null ? " Displaying saved local cache." : ""}',
        'origin': cached ?? fallbackOrigin,
        'is_cached': cached != null,
      };
    } catch (e) {
      final cached = await _getCachedOrigin();
      return {
        'success': false,
        'message': 'Error: $e.${cached != null ? " Displaying saved local cache." : ""}',
        'origin': cached ?? fallbackOrigin,
        'is_cached': cached != null,
      };
    }
  }

  String _extractErrorMessage(dynamic decoded, String defaultMessage) {
    if (decoded is Map) {
      if (decoded['message'] != null && decoded['message'].toString().isNotEmpty) {
        return decoded['message'].toString();
      }
      if (decoded['error'] != null && decoded['error'].toString().isNotEmpty) {
        return decoded['error'].toString();
      }
      if (decoded['detail'] != null && decoded['detail'].toString().isNotEmpty) {
        return decoded['detail'].toString();
      }
      if (decoded['errors'] != null) {
        final errors = decoded['errors'];
        if (errors is Map) {
          final firstEntry = errors.entries.firstOrNull;
          if (firstEntry != null) {
            final val = firstEntry.value;
            final valStr = val is List ? val.join(', ') : val.toString();
            return firstEntry.key != 'non_field_errors' ? '${firstEntry.key}: $valStr' : valStr;
          }
        } else if (errors is List) {
          return errors.join(', ');
        }
        return errors.toString();
      }
    }
    return defaultMessage;
  }

  Future<Map<String, dynamic>> updateDeliveryOrigin(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/origin/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data))
          .timeout(_timeoutDuration);
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final originData = (decoded is Map && decoded.containsKey('origin')) ? decoded['origin'] : decoded;
        if (originData is Map) {
          await _cacheOrigin(Map<String, dynamic>.from(originData));
        } else {
          await _cacheOrigin(Map<String, dynamic>.from(data));
        }
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _extractErrorMessage(decoded, 'Failed to update origin')};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out while saving origin. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDistanceBands() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/');
      final res = await ApiClient.get(url, headers: await _authHeaders())
          .timeout(_timeoutDuration);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List ? decoded : (decoded['bands'] ?? decoded['data'] ?? []);
        final listTyped = list is List ? list : [];
        await _cacheBands(listTyped);
        return {'success': true, 'bands': listTyped};
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {}
      final cached = await _getCachedBands();
      return {
        'success': false,
        'message': _extractErrorMessage(decoded, 'HTTP ${res.statusCode}: Failed to load distance bands from server.${cached != null && cached.isNotEmpty ? " Displaying saved local cache." : ""}'),
        'bands': cached ?? [],
        'is_cached': cached != null && cached.isNotEmpty,
      };
    } on TimeoutException {
      final cached = await _getCachedBands();
      return {
        'success': false,
        'message': 'Request timed out while loading distance bands.${cached != null && cached.isNotEmpty ? " Displaying saved local cache." : ""}',
        'bands': cached ?? [],
        'is_cached': cached != null && cached.isNotEmpty,
      };
    } catch (e) {
      final cached = await _getCachedBands();
      return {
        'success': false,
        'message': 'Error loading distance bands: $e.${cached != null && cached.isNotEmpty ? " Displaying saved local cache." : ""}',
        'bands': cached ?? [],
        'is_cached': cached != null && cached.isNotEmpty,
      };
    }
  }

  Future<Map<String, dynamic>> createDistanceBand(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data))
          .timeout(_timeoutDuration);
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _extractErrorMessage(decoded, 'Failed to create band')};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while creating band. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDistanceBand(int id, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/$id/');
      final res = await ApiClient.patch(url, headers: await _authHeaders(), body: jsonEncode(data))
          .timeout(_timeoutDuration);
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': _extractErrorMessage(decoded, 'Failed to update band')};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while updating band. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDistanceBand(int id) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/$id/');
      final res = await ApiClient.delete(url, headers: await _authHeaders())
          .timeout(_timeoutDuration);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true};
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {}
      return {'success': false, 'message': _extractErrorMessage(decoded, 'HTTP ${res.statusCode}: Failed to delete band')};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while deleting band. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteAllDistanceBands() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/');
      final res = await ApiClient.delete(url, headers: await _authHeaders())
          .timeout(_timeoutDuration);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true};
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(res.body);
      } catch (_) {}
      return {'success': false, 'message': _extractErrorMessage(decoded, 'HTTP ${res.statusCode}: Failed to clear distance bands')};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while clearing bands. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> calculateDelivery({
    double? latitude,
    double? longitude,
    String? address,
    String channel = 'CUSTOMER',
  }) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/calculate/');
      final Map<String, dynamic> body = {
        'channel': channel,
      };
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (address != null && address.trim().isNotEmpty) body['address'] = address.trim();

      final res = await ApiClient.post(
        url,
        headers: await _authHeaders(),
        body: jsonEncode(body),
      ).timeout(_timeoutDuration);
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {
          'success': decoded['success'] == true,
          'data': decoded,
        };
      }
      return {
        'success': false,
        'message': decoded['message'] ?? 'HTTP ${res.statusCode}',
        'data': decoded is Map<String, dynamic> ? decoded : null,
      };
    } on TimeoutException {
      return {'success': false, 'message': 'Fee calculation timed out after 30s. Please retry.'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
