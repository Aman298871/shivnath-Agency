import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'session_service.dart';

class AuthService {
  static String get baseUrl => AppConstants.apiBaseUrl;

  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to fetch user data', 'data': decoded};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }


  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    return _post(
      '/api/auth/login/',
      {
        'email': email,
        'password': password,
        'role': role,
      },
    );
  }

  Future<Map<String, dynamic>>
      registerCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    return _post(
      '/api/auth/register/customer/',
      {
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'confirm_password':
            confirmPassword,
      },
    );
  }

  Future<Map<String, dynamic>> registerFranchise({
  required String ownerName,
  required String businessName,
  required String phone,
  required String email,
  required String password,
  required String confirmPassword,
  required String city,
  required String address,
  required String territory,
  required String panNumber,
  required String aadhaarNumber,
  String gstNumber = '',
}) async {
  return _post(
    '/api/auth/register/franchise/',
    {
      'owner_name': ownerName,
      'business_name': businessName,
      'phone': phone,
      'email': email,
      'password': password,
      'confirm_password': confirmPassword,
      'city': city,
      'address': address,
      'territory': territory,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
    },
  );
}
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '$baseUrl$endpoint',
            ),
            headers: {
              'Content-Type':
                  'application/json',
              'Accept':
                  'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(
              seconds: 15,
            ),
          );

      dynamic decoded;

      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      final Map<String, dynamic> data =
          decoded
                  is Map<String, dynamic>
              ? decoded
              : {};

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return {
          'success': true,
          'data': data,
        };
      }

      return {
        'success': false,
        'message':
            _extractError(data),
        'data': data,
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Unable to connect to server.',
      };
    }
  }

  String _extractError(
    Map<String, dynamic> data,
  ) {
    if (data['message'] != null) {
      return data['message'].toString();
    }

    if (data['detail'] != null) {
      return _valueToString(
        data['detail'],
      );
    }

    if (data['errors']
        is Map<String, dynamic>) {
      final errors =
          data['errors']
              as Map<String, dynamic>;

      if (errors.isNotEmpty) {
        return _valueToString(
          errors.values.first,
        );
      }
    }

    for (final key in [
      'email',
      'password',
      'role',
      'non_field_errors',
    ]) {
      if (data[key] != null) {
        return _valueToString(
          data[key],
        );
      }
    }

    return 'Something went wrong.';
  }

  String _valueToString(
    dynamic value,
  ) {
    if (value is List &&
        value.isNotEmpty) {
      return value.first.toString();
    }

    if (value is Map &&
        value.isNotEmpty) {
      return _valueToString(
        value.values.first,
      );
    }

    return value.toString();
  }
}