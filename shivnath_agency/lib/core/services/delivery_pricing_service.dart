import 'dart:async';
import 'dart:convert';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class DeliveryPricingService {
  static final DeliveryPricingService _instance = DeliveryPricingService._internal();
  factory DeliveryPricingService() => _instance;
  DeliveryPricingService._internal();

  static const Duration _timeoutDuration = Duration(seconds: 30);

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
      'name': 'Local Radius (0-2 km)',
      'label': 'Local Radius (0-2 km)',
      'min_distance_km': 0.0,
      'max_distance_km': 2.0,
      'delivery_charge': 0.0,
      'is_active': true,
      'is_supported': true,
    },
    {
      'id': 2,
      'name': 'City Standard (2-5 km)',
      'label': 'City Standard (2-5 km)',
      'min_distance_km': 2.0,
      'max_distance_km': 5.0,
      'delivery_charge': 30.0,
      'is_active': true,
      'is_supported': true,
    },
    {
      'id': 3,
      'name': 'Suburban Belt (5-10 km)',
      'label': 'Suburban Belt (5-10 km)',
      'min_distance_km': 5.0,
      'max_distance_km': 10.0,
      'delivery_charge': 50.0,
      'is_active': true,
      'is_supported': true,
    },
    {
      'id': 4,
      'name': 'Outer Radius (10-25 km)',
      'label': 'Outer Radius (10-25 km)',
      'min_distance_km': 10.0,
      'max_distance_km': 25.0,
      'delivery_charge': 80.0,
      'is_active': true,
      'is_supported': true,
    },
  ];

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
        return {'success': true, 'origin': originData};
      }
      return {
        'success': false,
        'message': 'HTTP ${res.statusCode}: Failed to load delivery origin',
        'origin': null,
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out after 30s while loading origin. Please retry.',
        'origin': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'origin': null,
      };
    }
  }

  Future<Map<String, dynamic>> updateDeliveryOrigin(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/origin/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data))
          .timeout(_timeoutDuration);
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to update origin'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while saving origin. Please retry.'};
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
        return {'success': true, 'bands': list};
      }
      return {
        'success': false,
        'message': 'HTTP ${res.statusCode}: Failed to load distance bands',
        'bands': [],
      };
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out after 30s while loading distance bands. Please retry.',
        'bands': [],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'bands': [],
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
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to create band'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while creating band. Please retry.'};
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
      return {'success': false, 'message': 'HTTP ${res.statusCode}'};
    } on TimeoutException {
      return {'success': false, 'message': 'Request timed out after 30s while deleting band. Please retry.'};
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
