import 'dart:convert';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'session_service.dart';

class ChatService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  final SessionService _sessionService = SessionService();

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String appType = 'customer',
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final token = await _sessionService.getAccessToken();

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'message': message,
        'app_type': appType,
        'history': history,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat/'),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

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
          'reply': decoded['reply']?.toString() ??
              'Thank you for contacting Shivnath Agency. How can I assist you further?',
        };
      }

      return {
        'success': true,
        'reply': decoded is Map && decoded['error'] != null
            ? decoded['error'].toString()
            : 'I am here to help you with Shivnath products, orders, and franchise information. What would you like to know?',
      };
    } catch (e) {
      return {
        'success': true,
        'reply':
            'Namaste! I am currently assisting you. For immediate support, feel free to contact our executive at +91 98062 47194 or ask your questions here.',
      };
    }
  }
}
