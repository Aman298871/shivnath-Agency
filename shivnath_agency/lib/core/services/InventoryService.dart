import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'session_service.dart';


class InventoryService {
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
  // GET ALL ITEMS
  // =====================================================

  Future<Map<String, dynamic>> getItems({
    String? search,
    String? type,
  }) async {
    try {
      final queryParameters = <String, String>{};

      if (search != null && search.trim().isNotEmpty) {
        queryParameters['search'] = search.trim();
      }

      if (type != null &&
          type.trim().isNotEmpty &&
          type != 'All') {
        queryParameters['type'] = _typeToApi(type);
      }

      final uri = Uri.parse(
        '$baseUrl/api/inventory/items/',
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
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // CREATE ITEM
  // =====================================================

  Future<Map<String, dynamic>> createItem(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/items/'),
        headers: await _headers(),
        body: jsonEncode(_prepareItemData(data)),
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
  // UPDATE ITEM
  // =====================================================

  Future<Map<String, dynamic>> updateItem(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/inventory/items/$id/'),
        headers: await _headers(),
        body: jsonEncode(_prepareItemData(data)),
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
  // DELETE ITEM
  // =====================================================

  Future<Map<String, dynamic>> deleteItem(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/inventory/items/$id/'),
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
      final response = await http.get(
        Uri.parse('$baseUrl/api/inventory/stats/'),
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
  // STOCK REQUESTS: LIST
  // =====================================================

  Future<Map<String, dynamic>> getStockRequests({
    String? status,
  }) async {
    try {
      final queryParameters = <String, String>{};

      if (status != null &&
          status.trim().isNotEmpty &&
          status != 'All') {
        queryParameters['status'] = status.toLowerCase();
      }

      final uri = Uri.parse(
        '$baseUrl/api/inventory/requests/',
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
        'message': 'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // =====================================================
  // STOCK REQUESTS: CREATE (Stock Entry dialog)
  // =====================================================

  Future<Map<String, dynamic>> createStockRequest({
    required int itemId,
    required String type, // 'Stock In' or 'Stock Out'
    required int quantity,
    String reason = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inventory/requests/'),
        headers: await _headers(),
        body: jsonEncode({
          'item_id': itemId,
          'request_type': _requestTypeToApi(type),
          'quantity': quantity,
          'reason': reason,
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
  // STOCK REQUESTS: APPROVE
  // =====================================================

  Future<Map<String, dynamic>> approveStockRequest(
    int id,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '$baseUrl/api/inventory/requests/$id/approve/',
        ),
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
  // STOCK REQUESTS: REJECT
  // =====================================================

  Future<Map<String, dynamic>> rejectStockRequest(
    int id, {
    required String reason,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '$baseUrl/api/inventory/requests/$id/reject/',
        ),
        headers: await _headers(),
        body: jsonEncode({
          'rejection_reason': reason,
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
  // PREPARE ITEM DATA FOR API
  // =====================================================

  Map<String, dynamic> _prepareItemData(
    Map<String, dynamic> data,
  ) {
    return {
      'name': data['name']?.toString().trim() ?? '',
      'item_type': _typeToApi(
        data['type']?.toString() ?? 'Raw Material',
      ),
      'sku': data['sku']?.toString().trim() ?? '',
      'unit': _unitToApi(
        data['unit']?.toString() ?? 'Pcs',
      ),
      'stock': int.tryParse(
            data['stock']?.toString() ?? '0',
          ) ??
          0,
      'min_stock': int.tryParse(
            data['minStock']?.toString() ?? '0',
          ) ??
          0,
      'purchase_rate': double.tryParse(
            data['purchaseRate']?.toString() ?? '0',
          ) ??
          0,
      'batch': data['batch']?.toString().trim() ?? '',
      'supplier': data['supplier']?.toString().trim() ?? '',
    };
  }

  // =====================================================
  // MAP BACKEND ITEM -> SCREEN FORMAT
  // =====================================================

  Map<String, dynamic> mapItem(
    Map<String, dynamic> item,
  ) {
    return {
      'id': item['id'],
      'name': item['name']?.toString() ?? '',
      'type': item['type_display']?.toString() ??
          _typeDisplay(item['item_type']?.toString() ?? ''),
      'sku': item['sku']?.toString() ?? '',
      'unit': item['unit_display']?.toString() ??
          _unitDisplay(item['unit']?.toString() ?? ''),
      'stock': item['stock'] ?? 0,
      'minStock': item['min_stock'] ?? 0,
      'purchaseRate': double.tryParse(
            item['purchase_rate']?.toString() ?? '0',
          ) ??
          0,
      'batch': item['batch']?.toString() ?? '',
      'supplier': item['supplier']?.toString() ?? '',
    };
  }

  // =====================================================
  // MAP BACKEND STOCK REQUEST -> SCREEN FORMAT
  // =====================================================

  Map<String, dynamic> mapStockRequest(
    Map<String, dynamic> item,
  ) {
    return {
      'id': item['id'],
      'itemId': item['item_id'],
      'itemName': item['item_name']?.toString() ?? '',
      'type': item['type_display']?.toString() ??
          _requestTypeDisplay(
            item['request_type']?.toString() ?? '',
          ),
      'quantity': item['quantity'] ?? 0,
      'requestedBy': item['requested_by_name']?.toString() ?? '',
      'date': _formatDate(item['created_at']),
      'status': item['status_display']?.toString() ??
          _statusDisplay(item['status']?.toString() ?? ''),
      'reason': item['reason']?.toString() ?? '',
      'rejectionReason': item['rejection_reason']?.toString() ?? '',
    };
  }

  // =====================================================
  // FRANCHISE INVENTORY METHODS
  // =====================================================

  Future<Map<String, dynamic>> getFranchiseRawMaterials() async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory/franchise/raw-materials/');
      final response = await http.get(uri, headers: await _headers());
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFranchiseTransactions() async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory/franchise/transactions/');
      final response = await http.get(uri, headers: await _headers());
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> getFranchiseProductionLogs() async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory/franchise/production-logs/');
      final response = await http.get(uri, headers: await _headers());
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> createFranchiseProductionLog(Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/api/inventory/franchise/production-logs/');
      final response = await http.post(
        uri,
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return _decodeResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
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
  // TYPE / UNIT / STATUS CONVERSIONS
  // =====================================================

  String _typeToApi(String value) {
    switch (value) {
      case 'Raw Material':
        return 'raw_material';
      case 'Finished Product':
        return 'finished_product';
      default:
        return value.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  String _typeDisplay(String value) {
    switch (value) {
      case 'raw_material':
        return 'Raw Material';
      case 'finished_product':
        return 'Finished Product';
      default:
        return value;
    }
  }

  String _unitToApi(String value) {
    switch (value) {
      case 'Pcs':
        return 'pcs';
      case 'Bottles':
        return 'bottles';
      case 'Jars':
        return 'jars';
      case 'Kg':
        return 'kg';
      default:
        return value.trim().toLowerCase();
    }
  }

  String _unitDisplay(String value) {
    switch (value) {
      case 'pcs':
        return 'Pcs';
      case 'bottles':
        return 'Bottles';
      case 'jars':
        return 'Jars';
      case 'kg':
        return 'Kg';
      default:
        return value;
    }
  }

  String _requestTypeToApi(String value) {
    switch (value) {
      case 'Stock In':
        return 'stock_in';
      case 'Stock Out':
        return 'stock_out';
      default:
        return value.trim().toLowerCase().replaceAll(' ', '_');
    }
  }

  String _requestTypeDisplay(String value) {
    switch (value) {
      case 'stock_in':
        return 'Stock In';
      case 'stock_out':
        return 'Stock Out';
      default:
        return value;
    }
  }

  String _statusDisplay(String value) {
    switch (value) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
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