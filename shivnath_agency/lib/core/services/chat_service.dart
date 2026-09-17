import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'product_service.dart';
import 'session_service.dart';

class ChatService {
  static const String outOfScopeMessage =
      'I am the Shivnath Agency Pure Water Assistant. I can only assist with packaged drinking water products, pricing, orders, delivery, quotations, and franchise operations.';

  static String get baseUrl => AppConstants.apiBaseUrl;
  final SessionService _sessionService = SessionService();

  Future<Map<String, String>> _headers({bool requireAuth = false}) async {
    final token = await _sessionService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================
  // PUBLIC & CUSTOMER CHAT
  // =========================================================

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String appType = 'customer',
    int? optionId,
    String? sessionId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    List<Map<String, String>> history = const [],
  }) async {
    final headers = await _headers();

    final body = jsonEncode({
      'message': message,
      'app_type': appType,
      'option_id': optionId,
      'session_id': sessionId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_email': customerEmail,
      'history': history,
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat/'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map<String, dynamic>) {
        final replyText = decoded['reply']?.toString().trim() ?? '';
        if (replyText.isNotEmpty) {
          return {
            'success': true,
            'reply': replyText,
            'session_id': decoded['session_id'],
            'is_lead_trigger': decoded['is_lead_trigger'] == true,
            'lead_inquiry_type': decoded['lead_inquiry_type']?.toString() ?? '',
          };
        }
      }
    } catch (_) {
      // Fallback
    }

    final localReply = _generateLocalReasoning(message, appType);
    return {
      'success': true,
      'reply': localReply,
    };
  }

  // =========================================================
  // CHATBOT DYNAMIC HIERARCHY / OPTIONS
  // =========================================================

  Future<List<Map<String, dynamic>>> getPublicOptions({
    String? inquiryType,
    int? parentId,
    bool? tree,
  }) async {
    final query = <String, String>{};
    if (inquiryType != null && inquiryType.isNotEmpty) query['inquiry_type'] = inquiryType;
    if (parentId != null) query['parent_id'] = parentId.toString();
    if (tree == true) query['tree'] = 'true';

    final uri = Uri.parse('$baseUrl/api/chat/options/').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    try {
      final response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['options'] is List) {
          return List<Map<String, dynamic>>.from(decoded['options']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getAdminChatbotOptions({String? inquiryType}) async {
    final query = <String, String>{};
    if (inquiryType != null && inquiryType.isNotEmpty) query['inquiry_type'] = inquiryType;

    final uri = Uri.parse('$baseUrl/api/chat/admin/options/').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    try {
      final response = await http.get(uri, headers: await _headers(requireAuth: true)).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['options'] is List) {
          return List<Map<String, dynamic>>.from(decoded['options']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> createChatbotOption(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/chat/admin/options/'),
        headers: await _headers(requireAuth: true),
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateChatbotOption(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/chat/admin/options/$id/'),
        headers: await _headers(requireAuth: true),
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteChatbotOption(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chat/admin/options/$id/'),
        headers: await _headers(requireAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // =========================================================
  // QUOTATIONS API
  // =========================================================

  Future<List<Map<String, dynamic>>> getQuotations({String? target, String? type}) async {
    final query = <String, String>{};
    if (target != null && target.isNotEmpty) query['target'] = target;
    if (type != null && type.isNotEmpty) query['type'] = type;

    final uri = Uri.parse('$baseUrl/api/chat/quotations/').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    try {
      final response = await http.get(uri, headers: await _headers()).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['quotations'] is List) {
          return List<Map<String, dynamic>>.from(decoded['quotations']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> createQuotation(
    Map<String, dynamic> data, {
    String? pdfFilePath,
    List<int>? pdfBytes,
    String? pdfFileName,
  }) async {
    final token = await _sessionService.getAccessToken();
    try {
      if (pdfFilePath != null || pdfBytes != null) {
        final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/chat/quotations/'));
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        data.forEach((k, v) {
          if (v != null) request.fields[k] = v.toString();
        });
        if (pdfFilePath != null && pdfFilePath.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath('pdf_file', pdfFilePath, filename: pdfFileName));
        } else if (pdfBytes != null) {
          request.files.add(http.MultipartFile.fromBytes('pdf_file', pdfBytes, filename: pdfFileName ?? 'quotation.pdf'));
        }
        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamed);
        return jsonDecode(response.body);
      } else {
        final response = await http.post(
          Uri.parse('$baseUrl/api/chat/quotations/'),
          headers: await _headers(requireAuth: true),
          body: jsonEncode(data),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateQuotation(
    int id,
    Map<String, dynamic> data, {
    String? pdfFilePath,
    List<int>? pdfBytes,
    String? pdfFileName,
    bool removePdf = false,
  }) async {
    final token = await _sessionService.getAccessToken();
    try {
      if (pdfFilePath != null || pdfBytes != null || removePdf) {
        final request = http.MultipartRequest('PATCH', Uri.parse('$baseUrl/api/chat/quotations/$id/'));
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        data.forEach((k, v) {
          if (v != null) request.fields[k] = v.toString();
        });
        if (removePdf) {
          request.fields['remove_pdf'] = 'true';
        } else if (pdfFilePath != null && pdfFilePath.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath('pdf_file', pdfFilePath, filename: pdfFileName));
        } else if (pdfBytes != null) {
          request.files.add(http.MultipartFile.fromBytes('pdf_file', pdfBytes, filename: pdfFileName ?? 'quotation.pdf'));
        }
        final streamed = await request.send().timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamed);
        return jsonDecode(response.body);
      } else {
        final response = await http.patch(
          Uri.parse('$baseUrl/api/chat/quotations/$id/'),
          headers: await _headers(requireAuth: true),
          body: jsonEncode(data),
        );
        return jsonDecode(response.body);
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteQuotation(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chat/quotations/$id/'),
        headers: await _headers(requireAuth: true),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // =========================================================
  // PUBLIC LEAD CAPTURE (PROSPECT & QUALIFICATION)
  // =========================================================

  Future<Map<String, dynamic>> submitPublicLead(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/leads/public-capture/'),
        headers: await _headers(),
        body: jsonEncode(data),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // =========================================================
  // ADMIN CONVERSATIONS AUDIT
  // =========================================================

  Future<List<Map<String, dynamic>>> getAdminConversations({String? appType}) async {
    final query = <String, String>{};
    if (appType != null && appType.isNotEmpty) query['app_type'] = appType;

    final uri = Uri.parse('$baseUrl/api/chat/admin/conversations/').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    try {
      final response = await http.get(uri, headers: await _headers(requireAuth: true)).timeout(const Duration(seconds: 10));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['conversations'] is List) {
          return List<Map<String, dynamic>>.from(decoded['conversations']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> getAdminConversationDetail(int sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/admin/conversations/$sessionId/'),
        headers: await _headers(requireAuth: true),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  String _generateLocalReasoning(String query, String appType) {
    final msg = query.trim().toLowerCase();
    final isFranchise = appType == 'franchise';

    if (msg == 'hi' || msg == 'hello' || msg == 'namaste') {
      return 'Namaste! 🙏 Welcome to Shivnath Pure Water. I can assist you with product prices, home delivery, official quotations, and franchise partnership. How can I assist you today?';
    }

    final prods = ProductService.products;
    if (prods.isNotEmpty && (msg.contains('product') || msg.contains('price') || msg.contains('rate') || msg.contains('bottle') || msg.contains('jar'))) {
      final lines = prods.map((p) => '• ${p.name} (${p.size}): ₹${p.price.toStringAsFixed(2)} [Stock: ${p.stock}]').join('\n');
      return '💧 *Shivnath Agency Product Price List*:\n$lines\n\nContact +91 98062 47194 for bulk orders.';
    }

    if (isFranchise || msg.contains('franchise') || msg.contains('investment')) {
      return '🏢 *Franchise Opportunity*:\n• Territory: 5 KM Exclusive Zone\n• Margins: 25%-35% direct plant margin\n• Investment: ₹3 Lakh - ₹20 Lakh\n• Contact: +91 98062 47194';
    }

    return 'Thank you for your inquiry. Our team is available at +91 98062 47194 to assist you immediately.';
  }
}
