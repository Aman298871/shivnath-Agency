import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'session_service.dart';


class OrderService {
  static String get baseUrl => AppConstants.apiBaseUrl;

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

  // =====================================================
  // GET ALL ORDERS
  // =====================================================

  Future<Map<String, dynamic>> getOrders({
    String? search,
    String? status,
  }) async {
    try {
      final queryParameters = <String, String>{};

      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      if (status != null &&
          status.trim().isNotEmpty &&
          status != 'All') {
        queryParameters['status'] = _statusToApi(status);
      }

      final uri = Uri.parse(
        '$baseUrl/api/orders/',
      ).replace(
        queryParameters:
            queryParameters.isEmpty ? null : queryParameters,
      );

      final response = await http.get(
        uri,
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // GET SINGLE ORDER
  // =====================================================

  Future<Map<String, dynamic>> getOrder(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // CREATE ORDER
  // =====================================================

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/orders/'),
        headers: await _headers(),
        body: jsonEncode(_prepareOrderData(data)),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // UPDATE ORDER
  // =====================================================

  Future<Map<String, dynamic>> updateOrder(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
        body: jsonEncode(_prepareOrderData(data)),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // UPDATE ORDER STATUS (dedicated endpoint used by dialog)
  // =====================================================

  Future<Map<String, dynamic>> updateOrderStatus(
    int id,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/orders/$id/status/'),
        headers: await _headers(),
        body: jsonEncode({
          'status': _statusToApi(status),
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // DELETE ORDER
  // =====================================================

  Future<Map<String, dynamic>> deleteOrder(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // GET STATS
  // =====================================================

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/orders/stats/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: $e',
      };
    }
  }

  // =====================================================
  // PREPARE ORDER DATA FOR API
  // =====================================================

  Map<String, dynamic> _prepareOrderData(
    Map<String, dynamic> data,
  ) {
    return {
      'franchise_name':
          data['franchise']?.toString().trim() ?? '',

      'city': data['city']?.toString().trim() ?? '',

      'items_count': int.tryParse(
            data['items']?.toString() ?? '0',
          ) ??
          0,

      'amount': double.tryParse(
            data['amount']?.toString() ?? '0',
          ) ??
          0,

      'status': _statusToApi(
        data['status']?.toString() ?? 'Order Placement',
      ),

      'payment_status': _paymentToApi(
        data['payment']?.toString() ?? 'Pending',
      ),
    };
  }

  // =====================================================
  // MAP BACKEND ORDER -> SCREEN FORMAT
  // =====================================================

  Map<String, dynamic> mapOrder(
    Map<String, dynamic> item,
  ) {
    return {
      'id': item['id'],

      'orderId': item['order_id']?.toString() ?? '',

      'franchise': item['franchise_name']?.toString() ?? '',

      'city': item['city']?.toString() ?? '',

      'date': _formatDate(item['order_date']),

      'items': item['items_count'] ?? 0,

      'amount': double.tryParse(
            item['amount']?.toString() ?? '0',
          ) ??
          0,

      'status': item['status_display']?.toString() ??
          _statusDisplay(item['status']?.toString() ?? ''),

      'payment': item['payment_display']?.toString() ??
          _paymentDisplay(
            item['payment_status']?.toString() ?? '',
          ),
    };
  }

  // =====================================================
  // RESPONSE HANDLER
  // =====================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
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
        'success': true,
        'data': decoded,
      };
    }

    String message = 'Something went wrong.';

    if (decoded is Map<String, dynamic>) {
      if (decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded['detail'] != null) {
        message = decoded['detail'].toString();
      } else if (decoded['errors'] != null) {
        message = _formatErrors(decoded['errors']);
      }
    }

    return {
      'success': false,
      'message': message,
      'statusCode': response.statusCode,
      'data': decoded,
    };
  }

  String _formatErrors(dynamic errors) {
    if (errors is Map) {
      final messages = <String>[];

      errors.forEach((key, value) {
        if (value is List) {
          messages.add(value.join(', '));
        } else {
          messages.add(value.toString());
        }
      });

      return messages.join('\n');
    }

    return errors.toString();
  }

  // =====================================================
  // STATUS CONVERSION
  // =====================================================

  String _statusToApi(String value) {
    switch (value) {
      case 'Order Placement':
        return 'order_placement';
      case 'Plant Approval':
        return 'plant_approval';
      case 'Invoice Generated':
        return 'invoice_generated';
      case 'Dispatch':
        return 'dispatch';
      case 'Delivered':
        return 'delivered';
      case 'Payment Collection':
        return 'payment_collection';
      default:
        return value.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  String _statusDisplay(String value) {
    switch (value) {
      case 'order_placement':
        return 'Order Placement';
      case 'plant_approval':
        return 'Plant Approval';
      case 'invoice_generated':
        return 'Invoice Generated';
      case 'dispatch':
        return 'Dispatch';
      case 'delivered':
        return 'Delivered';
      case 'payment_collection':
        return 'Payment Collection';
      default:
        return value;
    }
  }

  // =====================================================
  // PAYMENT CONVERSION
  // =====================================================

  String _paymentToApi(String value) {
    switch (value) {
      case 'Pending':
        return 'pending';
      case 'Partial':
        return 'partial';
      case 'Paid':
        return 'paid';
      default:
        return value.trim().toLowerCase();
    }
  }

  String _paymentDisplay(String value) {
    switch (value) {
      case 'pending':
        return 'Pending';
      case 'partial':
        return 'Partial';
      case 'paid':
        return 'Paid';
      default:
        return value;
    }
  }

  // =====================================================
  // DATE FORMAT
  // =====================================================

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${date.day.toString().padLeft(2, '0')} '
          '${months[date.month]} '
          '${date.year}';
    } catch (_) {
      return value.toString();
    }
  }
}