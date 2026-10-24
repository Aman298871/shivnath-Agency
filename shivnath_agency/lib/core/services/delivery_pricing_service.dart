import 'dart:convert';
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class DeliveryPricingService {
  static final DeliveryPricingService _instance = DeliveryPricingService._internal();
  factory DeliveryPricingService() => _instance;
  DeliveryPricingService._internal();

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
      final res = await ApiClient.get(url, headers: await _authHeaders());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        return {'success': true, 'origin': decoded};
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}: Failed to load delivery origin'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> updateDeliveryOrigin(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/origin/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to update origin'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> getDistanceBands() async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/');
      final res = await ApiClient.get(url, headers: await _authHeaders());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List ? decoded : (decoded['bands'] ?? decoded['data'] ?? []);
        return {'success': true, 'bands': list};
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}: Failed to load distance bands'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> createDistanceBand(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/');
      final res = await ApiClient.post(url, headers: await _authHeaders(), body: jsonEncode(data));
      final decoded = jsonDecode(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['error'] ?? decoded['detail'] ?? 'Failed to create band'};
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteDistanceBand(int id) async {
    try {
      final url = Uri.parse('${AppConstants.apiBaseUrl}/api/billing/delivery/bands/$id/');
      final res = await ApiClient.delete(url, headers: await _authHeaders());
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'success': true};
      }
      return {'success': false, 'message': 'HTTP ${res.statusCode}'};
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
      );
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
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
}
