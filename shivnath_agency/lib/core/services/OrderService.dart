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
  // GET WALLET DETAILS
  // =====================================================
  Future<Map<String, dynamic>> getWalletDetails() async {
    try {
      final uri = Uri.parse('$baseUrl/api/orders/wallet/');
      final response = await ApiClient.get(
        uri,
        headers: await _headers(),
      ).timeout(const Duration(seconds: 4));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'balance': decoded['balance'] ?? decoded['wallet_balance'] ?? 0.0,
          'reward_points': decoded['reward_points'] ?? 0,
          'points_value_in_inr': (decoded['points_value_in_inr'] as num?)?.toDouble() ?? 0.0,
          'conversion_rule': decoded['conversion_rule'] is Map ? Map<String, dynamic>.from(decoded['conversion_rule']) : null,
          'recent_transactions': decoded['recent_transactions'] ?? [],
          'data': decoded,
        };
      }
      return {'success': false, 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Network unavailable'};
    }
  }

  // =====================================================
  // GET ALL ORDERS
  // =====================================================

  Future<Map<String, dynamic>> getOrders({
    String? search,
    String? status,
    String? orderSource,
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

      if (orderSource != null && orderSource.trim().isNotEmpty) {
        queryParameters['order_source'] = orderSource.trim();
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
    if (data.containsKey('payment_mode')) map['payment_mode'] = data['payment_mode'];
    if (data.containsKey('payment_method')) map['payment_method'] = data['payment_method'];
    if (data.containsKey('duration_choice')) map['duration_choice'] = data['duration_choice'];
    if (data.containsKey('duration_days')) map['duration_days'] = data['duration_days'];
    if (data.containsKey('customer_name')) map['customer_name'] = data['customer_name'];
    if (data.containsKey('phone')) map['phone'] = data['phone'];
    if (data.containsKey('delivery_address')) map['delivery_address'] = data['delivery_address'];
    if (data.containsKey('notes')) map['notes'] = data['notes'];
    if (data.containsKey('idempotency_key')) map['idempotency_key'] = data['idempotency_key'];

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

    final double rawGrandTotal = double.tryParse(item['invoice_grand_total']?.toString() ?? item['grand_total']?.toString() ?? '') ?? 0.0;
    final double rawBaseAmount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0.0;
    final double totalAmt = rawGrandTotal > 0 ? rawGrandTotal : rawBaseAmount;

    final bool isPaid = item['payment_collected'] == true ||
        (item['payment_status']?.toString().toLowerCase() == 'paid') ||
        (item['invoice_status']?.toString().toUpperCase() == 'PAID');

    final double amtPaid = isPaid
        ? totalAmt
        : (double.tryParse(item['amount_paid']?.toString() ?? '0') ?? 0.0);

    final double outstandingBal = isPaid
        ? 0.0
        : (double.tryParse(item['outstanding_balance']?.toString() ?? '') ??
            double.tryParse(item['outstanding_amount']?.toString() ?? '') ??
            (totalAmt - amtPaid).clamp(0.0, totalAmt));

    final bool isPartial = !isPaid && amtPaid > 0 && outstandingBal > 0;

    String paymentLabel;
    if (isPaid) {
      paymentLabel = 'PAYMENT COLLECTED';
    } else if (isPartial) {
      paymentLabel = 'PARTIALLY PAID';
    } else {
      paymentLabel = 'PAYMENT PENDING';
    }

    return {
      'id': item['id'],

      'orderId': item['order_id']?.toString() ?? '',

      'customer_name': (item['customer_name'] != null && item['customer_name'].toString().isNotEmpty)
          ? item['customer_name'].toString()
          : (item['created_by_name']?.toString() ?? ''),

      'franchise': _resolveFranchiseName(item),

      'serving_franchise_name': item['serving_franchise_name']?.toString() ?? '',
      'registered_franchise_name': item['registered_franchise_name']?.toString() ?? '',

      'customer_phone': item['customer_phone']?.toString() ?? '',
      'customer_email': item['customer_email']?.toString() ?? '',

      'delivery_address': item['delivery_address']?.toString() ?? '',

      'city': item['city']?.toString() ?? '',

      'date': _formatDate(item['order_date']),

      'items': item['items_count'] ?? (itemsList.isNotEmpty ? itemsList.length : 0),

      'items_list': itemsList,

      'amount': totalAmt,
      'base_amount': rawBaseAmount,
      'subtotal': double.tryParse(item['invoice_subtotal']?.toString() ?? '') ?? rawBaseAmount,
      'tax_amount': double.tryParse(item['invoice_tax']?.toString() ?? '') ?? 0.0,
      'grand_total': totalAmt,

      'status': normalizeStatusDisplay(
            item['status_display']?.toString() ??
                item['status']?.toString() ??
                '',
          ),

      'raw_status': item['status']?.toString() ?? '',

      'payment': paymentLabel,

      'payment_status': isPaid ? 'paid' : (isPartial ? 'partial' : 'pending'),

      'payment_collected': isPaid,

      'is_pending_verification': false,

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

      'amount_paid': amtPaid,
      'outstanding_balance': outstandingBal,
      'outstanding_amount': outstandingBal,
      'previous_outstanding': double.tryParse(item['previous_outstanding']?.toString() ?? '0') ?? 0.0,
      'current_order_amount': double.tryParse(item['current_order_amount']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0.0,
      'total_exposure': double.tryParse(item['total_exposure']?.toString() ?? '0') ?? 0.0,
      'credit_limit': double.tryParse(item['credit_limit']?.toString() ?? '0') ?? 0.0,
      'payment_terms_days': int.tryParse(item['payment_terms_days']?.toString() ?? '15') ?? 15,
      'credit_status': item['credit_status']?.toString() ?? 'GOOD_STANDING',

      'status_history': item['status_history'] is List ? item['status_history'] : [],

      'invoice_id': item['invoice_id'],
      'invoice_number': item['invoice_number']?.toString() ?? '',
      'invoice_status': isPaid ? 'PAID' : (isPartial ? 'PARTIALLY_PAID' : (item['invoice_status']?.toString() ?? 'UNPAID')),
      'invoice_subtotal': double.tryParse(item['invoice_subtotal']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0.0,
      'invoice_tax': double.tryParse(item['invoice_tax']?.toString() ?? '0') ?? 0.0,
      'invoice_grand_total': totalAmt,
      'delivery_charges': double.tryParse(item['delivery_charges']?.toString() ?? '0') ?? 0.0,
      'discount_amount': double.tryParse(item['discount_amount']?.toString() ?? '0') ?? 0.0,
      'payment_mode': item['payment_mode']?.toString() ?? 'Pending',
      'order_notes': item['order_notes']?.toString() ?? '',
      'fulfilling_entity': item['fulfilling_entity'] is Map ? Map<String, dynamic>.from(item['fulfilling_entity'] as Map) : null,

      'raw': item,
    };
  }

  // =====================================================
  // RECORD ORDER PAYMENT (FRANCHISE / ADMIN)
  // =====================================================

  Future<Map<String, dynamic>> recordOrderPayment(
    int orderId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/billing/orders/$orderId/payments/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to record payment. Please check your connection.',
      };
    }
  }

  Future<Map<String, dynamic>> getOrderPayments(int orderId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/billing/orders/$orderId/payments/'),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to fetch order payments.',
      };
    }
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
      } else if (decoded['error'] != null) {
        message = decoded['error'].toString();
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

  static String statusToApi(String value) {
    return canonicalStatus(value);
  }

  String _statusToApi(String value) {
    return statusToApi(value);
  }

  static String canonicalStatus(String? value) {
    if (value == null || value.trim().isEmpty) return 'order_placement';
    final lower = value.trim().toLowerCase().replaceAll(' ', '_');

    if (lower == 'dispatch' ||
        lower == 'dispatched' ||
        lower == 'out_for_delivery' ||
        lower == 'in_transit' ||
        lower == 'shipped' ||
        lower.contains('dispatch')) {
      return 'dispatch';
    }
    if (lower == 'invoice_generated' || lower.contains('invoice')) {
      return 'invoice_generated';
    }
    if (lower == 'preparing' || lower.contains('prepar') || lower.contains('bottling')) {
      return 'preparing';
    }
    if (lower == 'delivered' ||
        lower == 'completed' ||
        lower.contains('deliver') ||
        lower.contains('complet')) {
      return 'delivered';
    }
    if (lower == 'plant_approval' ||
        lower == 'approved' ||
        lower == 'admin_approved' ||
        (lower.contains('plant') && lower.contains('approv'))) {
      return 'plant_approval';
    }
    if (lower == 'cancelled' || lower == 'cancel') {
      return 'cancelled';
    }
    if (lower == 'payment_collection') {
      return 'payment_collection';
    }
    if (lower == 'order_placement' || lower == 'new' || lower == 'created' || lower == 'pending') {
      return 'order_placement';
    }
    return lower;
  }

  static List<String> getAllowedNextStatuses(String? currentStatus) {
    final canonical = canonicalStatus(currentStatus);
    switch (canonical) {
      case 'order_placement':
        return ['plant_approval', 'cancelled'];
      case 'plant_approval':
        return ['invoice_generated', 'preparing', 'cancelled'];
      case 'invoice_generated':
        return ['preparing', 'dispatch', 'cancelled'];
      case 'preparing':
        return ['invoice_generated', 'dispatch', 'cancelled'];
      case 'dispatch':
        return ['delivered', 'cancelled'];
      case 'delivered':
      case 'cancelled':
      default:
        return [];
    }
  }

  static String getStatusLabel(String? status) {
    final canonical = canonicalStatus(status);
    switch (canonical) {
      case 'order_placement':
        return 'Order Placement';
      case 'plant_approval':
        return 'Plant Approval';
      case 'invoice_generated':
        return 'Invoice Generated';
      case 'preparing':
        return 'Preparing / Bottling';
      case 'dispatch':
        return 'Dispatched / In Transit';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      case 'payment_collection':
        return 'Payment Collection';
      default:
        return normalizeStatusDisplay(status ?? '');
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

  static String _resolveFranchiseName(Map<String, dynamic> item) {
    final serving = item['serving_franchise_name']?.toString().trim();
    if (serving != null && serving.isNotEmpty && serving.toLowerCase() != 'null') {
      return serving;
    }
    final registered = item['registered_franchise_name']?.toString().trim();
    if (registered != null && registered.isNotEmpty && registered.toLowerCase() != 'null') {
      return registered;
    }
    final fn = item['franchise_name']?.toString().trim();
    final cust = (item['customer_name'] ?? item['created_by_name'] ?? '').toString().trim();
    if (fn != null && fn.isNotEmpty && fn.toLowerCase() != 'null') {
      if (cust.isEmpty || fn.toLowerCase() != cust.toLowerCase()) {
        return fn;
      }
    }
    if (item['order_source'] == 'WATER_WALLET' || item['order_source'] == 'WATER_WALLET_REDEMPTION') {
      return 'Shivnath Central Admin (Water Wallet)';
    }
    if (item['order_source'] == 'DIRECT_COMPANY') {
      return 'Shivnath Agency (Direct Company)';
    }
    return 'Shivnath Agency';
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

  // =====================================================
  // RAZORPAY ONLINE PAYMENT INTEGRATION
  // =====================================================

  Future<Map<String, dynamic>> getRazorpayStatus() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/razorpay/status/'),
        headers: await _headers(),
      );

      final res = _decodeResponse(response);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        return {
          'success': true,
          ...data,
          'data': data,
        };
      }
      return res;
    } catch (e) {
      return {
        'success': false,
        'available': false,
        'message': 'Unable to connect to payment diagnostic service.',
      };
    }
  }

  Future<Map<String, dynamic>> createRazorpayOrder({
    int? orderId,
    required double amount,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/razorpay/create-order/'),
        headers: await _headers(),
        body: jsonEncode({
          'order_id': ?orderId,
          'amount': amount,
        }),
      );

      final res = _decodeResponse(response);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        return {
          'success': true,
          ...data,
          'data': data,
        };
      }
      return res;
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to initialize online payment gateway. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> verifyRazorpayPayment({
    required int orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/razorpay/verify-payment/'),
        headers: await _headers(),
        body: jsonEncode({
          'order_id': orderId,
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
      );

      final res = _decodeResponse(response);
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        return {
          'success': true,
          ...data,
          'data': data,
        };
      }
      return res;
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to verify payment with backend. Please check your order history.',
      };
    }
  }

  Future<Map<String, dynamic>> cancelRazorpayPayment({
    required int orderId,
    String? reason,
    String? razorpayOrderId,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/razorpay/cancel-payment/'),
        headers: await _headers(),
        body: jsonEncode({
          'order_id': orderId,
          'reason': ?reason,
          'razorpay_order_id': ?razorpayOrderId,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error while recording payment cancellation.',
      };
    }
  }

  Future<Map<String, dynamic>> reconcileRazorpayPayment({
    required int orderId,
    String? razorpayOrderId,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/razorpay/reconcile/'),
        headers: await _headers(),
        body: jsonEncode({
          'order_id': orderId,
          'razorpay_order_id': ?razorpayOrderId,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error during payment reconciliation.',
      };
    }
  }

  // =====================================================
  // GET REDEMPTION ELIGIBLE PRODUCTS
  // =====================================================
  Future<Map<String, dynamic>> getRedemptionProducts() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/wallet/redemption-products/'),
        headers: await _headers(),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error loading redemption products.'};
    }
  }

  // =====================================================
  // REDEEM POINTS FOR PRODUCT (DIRECT ADMIN ORDER)
  // =====================================================
  Future<Map<String, dynamic>> redeemWalletPoints({
    required int productId,
    int quantity = 1,
    int? pointsToRedeem,
    dynamic deliveryAddress,
    String? notes,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/wallet/redeem/'),
        headers: await _headers(),
        body: jsonEncode({
          'product_id': productId,
          'quantity': quantity,
          'points_to_redeem': ?pointsToRedeem,
          'delivery_address': ?deliveryAddress,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error while redeeming points.'};
    }
  }

  // =====================================================
  // GET WALLET SETTINGS
  // =====================================================
  Future<Map<String, dynamic>> getWalletSettings() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/wallet/settings/'),
        headers: await _headers(),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error loading wallet settings.'};
    }
  }

  // =====================================================
  // UPDATE WALLET SETTINGS
  // =====================================================
  Future<Map<String, dynamic>> updateWalletSettings(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/wallet/settings/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error updating wallet settings.'};
    }
  }

  // =====================================================
  // INITIATE WALLET RECHARGE
  // =====================================================
  Future<Map<String, dynamic>> initiateWalletRecharge({required double amount}) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/wallet/recharge/'),
        headers: await _headers(),
        body: jsonEncode({'amount': amount}),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error initiating wallet recharge: $e'};
    }
  }

  // =====================================================
  // VERIFY WALLET RECHARGE
  // =====================================================
  Future<Map<String, dynamic>> verifyWalletRecharge({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/wallet/verify-recharge/'),
        headers: await _headers(),
        body: jsonEncode({
          'razorpay_order_id': razorpayOrderId,
          'razorpay_payment_id': razorpayPaymentId,
          'razorpay_signature': razorpaySignature,
        }),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error verifying wallet recharge: $e'};
    }
  }

  // =====================================================
  // PAY ORDER WITH WALLET
  // =====================================================
  Future<Map<String, dynamic>> payOrderWithWallet({required int orderId}) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/orders/wallet/pay-order/'),
        headers: await _headers(),
        body: jsonEncode({'order_id': orderId}),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error paying order with wallet: $e'};
    }
  }

  // =====================================================
  // GET WALLET TRANSACTIONS (LEDGER AUDIT TRAIL)
  // =====================================================
  Future<Map<String, dynamic>> getWalletTransactions() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/orders/wallet/transactions/'),
        headers: await _headers(),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error loading wallet transactions: $e'};
    }
  }
}