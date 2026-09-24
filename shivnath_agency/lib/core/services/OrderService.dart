import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
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

      final response = await ApiClient.get(
        uri,
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // GET SINGLE ORDER
  // =====================================================

  Future<Map<String, dynamic>> getOrder(int id) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
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
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/'),
        headers: await _headers(),
        body: jsonEncode(_prepareOrderData(data)),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
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
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
        body: jsonEncode(_prepareOrderData(data)),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
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
      final response = await ApiClient.patch(
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
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // DELETE ORDER
  // =====================================================

  Future<Map<String, dynamic>> deleteOrder(int id) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse('$baseUrl/api/orders/$id/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // GET STATS
  // =====================================================

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/stats/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // PREPARE ORDER DATA FOR API
  // =====================================================

  Map<String, dynamic> _prepareOrderData(
    Map<String, dynamic> data,
  ) {
    final map = <String, dynamic>{
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

    if (data.containsKey('order_items')) map['order_items'] = data['order_items'];
    if (data.containsKey('serving_franchise_id')) map['serving_franchise_id'] = data['serving_franchise_id'];
    if (data.containsKey('order_source')) map['order_source'] = data['order_source'];
    if (data.containsKey('duration_choice')) map['duration_choice'] = data['duration_choice'];
    if (data.containsKey('duration_days')) map['duration_days'] = data['duration_days'];
    if (data.containsKey('customer_name')) map['customer_name'] = data['customer_name'];
    if (data.containsKey('phone')) map['phone'] = data['phone'];
    if (data.containsKey('delivery_address')) map['delivery_address'] = data['delivery_address'];

    return map;
  }

  // =====================================================
  // MAP BACKEND ORDER -> SCREEN FORMAT
  // =====================================================

  Map<String, dynamic> mapOrder(
    Map<String, dynamic> item,
  ) {
    final rawItems = item['items'];
    final List<Map<String, dynamic>> itemsList = rawItems is List
        ? rawItems.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    return {
      'id': item['id'],

      'orderId': item['order_id']?.toString() ?? '',

      'franchise': item['franchise_name']?.toString() ?? '',

      'serving_franchise_name': item['serving_franchise_name']?.toString() ?? '',

      'customer_name': (item['customer_name'] != null && item['customer_name'].toString().isNotEmpty)
          ? item['customer_name'].toString()
          : (item['created_by_name']?.toString() ?? ''),

      'customer_phone': item['customer_phone']?.toString() ?? '',
      'customer_email': item['customer_email']?.toString() ?? '',

      'delivery_address': item['delivery_address']?.toString() ?? '',

      'city': item['city']?.toString() ?? '',

      'date': _formatDate(item['order_date']),

      'items': item['items_count'] ?? (itemsList.isNotEmpty ? itemsList.length : 0),

      'items_list': itemsList,

      'amount': double.tryParse(
            item['amount']?.toString() ?? '0',
          ) ??
          0,

      'status': normalizeStatusDisplay(
            item['status_display']?.toString() ??
                item['status']?.toString() ??
                '',
          ),

      'payment': item['payment_display']?.toString() ??
          _paymentDisplay(
            item['payment_status']?.toString() ?? '',
          ),

      'duration_choice': item['duration_choice']?.toString() ?? '',

      'order_source': item['order_source']?.toString() ?? '',

      'client_name': item['client_name']?.toString() ?? '',
      'label_requirement': item['label_requirement']?.toString() ?? '',
      'printing_requirement': item['printing_requirement']?.toString() ?? '',
      'branding_requirement': item['branding_requirement']?.toString() ?? '',
      'custom_shelf_life_days': item['custom_shelf_life_days'],
      'total_produced_units': int.tryParse(item['total_produced_units']?.toString() ?? '0') ?? 0,
      'total_delivered_units': int.tryParse(item['total_delivered_units']?.toString() ?? '0') ?? 0,
      'total_pending_stock_units': int.tryParse(item['total_pending_stock_units']?.toString() ?? '0') ?? 0,

      'previous_outstanding': double.tryParse(item['previous_outstanding']?.toString() ?? '0') ?? 0.0,
      'current_order_amount': double.tryParse(item['current_order_amount']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0.0,
      'total_exposure': double.tryParse(item['total_exposure']?.toString() ?? '0') ?? 0.0,
      'credit_limit': double.tryParse(item['credit_limit']?.toString() ?? '0') ?? 0.0,
      'payment_terms_days': int.tryParse(item['payment_terms_days']?.toString() ?? '15') ?? 15,
      'credit_status': item['credit_status']?.toString() ?? 'GOOD_STANDING',

      'status_history': item['status_history'] is List ? item['status_history'] : [],

      'raw': item,
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
      if (decoded['code'] == 'token_not_valid' ||
          (decoded['detail'] != null && decoded['detail'].toString().contains('token not valid'))) {
        message = 'Your session has expired. Please log in again.';
        _sessionService.refreshAccessToken();
      } else if (decoded['message'] != null) {
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
      case 'Preparing':
        return 'preparing';
      case 'Invoice Generated':
        return 'invoice_generated';
      case 'Dispatch':
        return 'dispatch';
      case 'Delivered':
        return 'delivered';
      case 'Payment Collection':
        return 'payment_collection';
      case 'Cancelled':
        return 'cancelled';
      default:
        return value.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  static String normalizeStatusDisplay(String value) {
    final lower = value.trim().toLowerCase();
    if ((lower.contains('plant') && lower.contains('approval')) ||
        lower.contains('admin approved') ||
        lower == 'plant_approval') {
      return 'Plant Approval';
    }
    switch (lower) {
      case 'order_placement':
        return 'Order Placement';
      case 'plant_approval':
        return 'Plant Approval';
      case 'preparing':
      case 'preparing / bottling':
        return 'Preparing';
      case 'invoice_generated':
        return 'Invoice Generated';
      case 'dispatch':
      case 'dispatched':
      case 'dispatch / in transit':
        return 'Dispatched';
      case 'delivered':
        return 'Delivered';
      case 'payment_collection':
        return 'Payment Collection';
      case 'cancelled':
        return 'Cancelled';
      default:
        return value;
    }
  }

  String _statusDisplay(String value) => normalizeStatusDisplay(value);

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

  // =====================================================
  // BULK ORDERS
  // =====================================================

  Future<Map<String, dynamic>> createBulkOrder(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/bulk/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  Future<Map<String, dynamic>> getBulkOrders() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/bulk/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }
}