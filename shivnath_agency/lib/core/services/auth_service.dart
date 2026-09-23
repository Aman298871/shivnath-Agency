import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../../models/user_model.dart';
import 'api_client.dart';
import 'session_service.dart';

class AuthService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  static const Duration defaultTimeout = Duration(seconds: 45);

  Future<Map<String, dynamic>> getCurrentUser() async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/auth/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(defaultTimeout);

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
    } on TimeoutException {
      return {'success': false, 'message': 'Server is starting up. Please wait a moment and try again.'};
    } catch (_) {
      return {'success': false, 'message': 'Unable to connect to server. Please check your internet connection.'};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/api/accounts/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
        try {
          final user = UserModel.fromJson(decoded);
          await SessionService().saveUser(user);
        } catch (_) {}
        return {'success': true, 'data': decoded};
      }
      return {
        'success': false,
        'message': decoded is Map && decoded['message'] != null
            ? decoded['message'].toString()
            : (decoded is Map && decoded['detail'] != null ? decoded['detail'].toString() : 'Failed to update profile'),
        'data': decoded,
      };
    } catch (e) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
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

  Future<Map<String, dynamic>> getTerritories({required String district}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/territory-master/').replace(
        queryParameters: {'district': district.trim()},
      );
      final response = await ApiClient.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to load territories', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Network error loading territories'};
    }
  }

  Future<Map<String, dynamic>> getEligibleFranchises({
    int? territoryId,
    int? zoneId,
    String? district,
    String? city,
  }) async {
    try {
      final effectiveId = territoryId ?? zoneId;
      final params = <String, String>{};
      if (effectiveId != null) {
        params['territory_id'] = effectiveId.toString();
        params['zone_id'] = effectiveId.toString();
      }
      if (district != null && district.isNotEmpty) params['district'] = district;
      if (city != null && city.isNotEmpty) params['city'] = city;

      final uri = Uri.parse('$baseUrl/api/auth/eligible-franchises/').replace(
        queryParameters: params.isNotEmpty ? params : null,
      );
      final response = await ApiClient.get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to load franchises', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Network error loading franchises'};
    }
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String confirmPassword,
    required String city,
    required String district,
    required int zoneId,
    int? franchiseId,
    String address = '',
  }) async {
    return _post(
      '/api/auth/register/customer/',
      {
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'city': city,
        'district': district,
        'zone_id': zoneId,
        if (franchiseId != null) 'franchise_id': franchiseId,
        if (address.isNotEmpty) 'address': address,
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
          .timeout(defaultTimeout);

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
    } on TimeoutException {
      return {
        'success': false,
        'message':
            'Cloud server is starting up (cold start). Please wait a few seconds and try again.',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Unable to connect to server. Please check your internet connection and try again.',
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
      return value.toString();
    }

    return value?.toString() ?? '';
  }

  Future<Map<String, dynamic>> getUsers({
    String? role,
    String? search,
  }) async {
    final token = await SessionService().getAccessToken();
    try {
      final queryParams = <String, String>{};
      if (role != null && role.isNotEmpty && role != 'all') {
        queryParams['role'] = role;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/api/accounts/users/').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await ApiClient.get(
        uri,
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
      return {'success': false, 'message': 'Failed to fetch users', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  Future<Map<String, dynamic>> getAdminNotifications() async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/accounts/notifications/'),
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
      return {'success': false, 'message': 'Failed to fetch notifications', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  Future<Map<String, dynamic>> markNotificationsAsRead({int? id}) async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/accounts/notifications/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(id != null ? {'id': id} : {}),
      ).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to update notifications', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  // =========================================================
  // TERRITORY & ZONE RESOLUTION
  // =========================================================

  Future<Map<String, dynamic>> resolveZone({
    required String district,
    required String pincode,
    String locality = '',
  }) async {
    return _post(
      '/api/accounts/resolve-zone/',
      {
        'district': district.trim(),
        'pincode': pincode.trim(),
        if (locality.trim().isNotEmpty) 'locality': locality.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> getTerritoryMaster() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/accounts/territory-master/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
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
      return {'success': false, 'message': 'Failed to fetch territory master', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  // =========================================================
  // SERVICE STATUS (HOLD / RESUME)
  // =========================================================

  Future<Map<String, dynamic>> updateServiceStatus({
    required String action,
    String reason = '',
    int? customerId,
  }) async {
    final token = await SessionService().getAccessToken();
    try {
      final payload = <String, dynamic>{
        'action': action.trim().toLowerCase(),
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
        if (customerId != null) 'customer_id': customerId,
      };

      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/accounts/service-status/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
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
      final msg = decoded is Map && decoded['error'] != null ? decoded['error'].toString() : 'Failed to update service status';
      return {'success': false, 'message': msg, 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  // =========================================================
  // FRANCHISE CUSTOMERS
  // =========================================================

  Future<Map<String, dynamic>> getFranchiseCustomers({String? search}) async {
    final token = await SessionService().getAccessToken();
    try {
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/api/accounts/franchise-customers/').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await ApiClient.get(
        uri,
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
      return {'success': false, 'message': 'Failed to fetch franchise customers', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  // =========================================================
  // FRANCHISE NOTIFICATIONS
  // =========================================================

  Future<Map<String, dynamic>> getFranchiseNotifications() async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/accounts/franchise-notifications/'),
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
      return {'success': false, 'message': 'Failed to fetch franchise notifications', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  Future<Map<String, dynamic>> markFranchiseNotificationsAsRead({int? id}) async {
    final token = await SessionService().getAccessToken();
    try {
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/accounts/franchise-notifications/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(id != null ? {'id': id} : {}),
      ).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to update franchise notifications', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  // =========================================================
  // SUPPORT CONTACT
  // =========================================================

  Future<Map<String, dynamic>> getSupportContact({
    String? role,
    String? inquiryType,
    bool fetchAll = false,
  }) async {
    try {
      final token = await SessionService().getAccessToken();
      final queryParams = <String, String>{};
      if (role != null && role.isNotEmpty) queryParams['role'] = role;
      if (inquiryType != null && inquiryType.isNotEmpty) queryParams['inquiry_type'] = inquiryType;
      if (fetchAll) queryParams['all'] = 'true';

      final uri = Uri.parse('$baseUrl/api/accounts/support-contact/').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await ApiClient.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Failed to fetch support contact', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please start the backend and try again.'};
    }
  }

  Future<Map<String, dynamic>> updateSupportContact({
    required String role,
    required String name,
    required String phone,
    String email = '',
    String messageTemplate = '',
  }) async {
    try {
      final token = await SessionService().getAccessToken();
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/accounts/support-contact/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'role': role,
          'name': name,
          'phone': phone,
          'email': email,
          'message_template': messageTemplate,
        }),
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
      return {'success': false, 'message': decoded['message'] ?? decoded['error'] ?? 'Failed to update support contact'};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please try again.'};
    }
  }

  // =========================================================
  // SUPER ADMIN: ADMIN ACCOUNT MANAGEMENT
  // =========================================================

  Future<Map<String, dynamic>> getSuperAdminAdmins() async {
    try {
      final token = await SessionService().getAccessToken();
      final response = await ApiClient.get(
        Uri.parse('$baseUrl/api/accounts/super-admin/admins/'),
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
      return {'success': false, 'message': decoded['message'] ?? decoded['error'] ?? 'Failed to fetch admin accounts'};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> createSuperAdminAdmin(Map<String, dynamic> data) async {
    try {
      final token = await SessionService().getAccessToken();
      final response = await ApiClient.post(
        Uri.parse('$baseUrl/api/accounts/super-admin/admins/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
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
      return {'success': false, 'message': decoded['message'] ?? decoded['error'] ?? 'Failed to create admin account'};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> updateSuperAdminAdmin(int adminId, Map<String, dynamic> data) async {
    try {
      final token = await SessionService().getAccessToken();
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/api/accounts/super-admin/admins/$adminId/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
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
      return {'success': false, 'message': decoded['message'] ?? decoded['error'] ?? 'Failed to update admin account'};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please try again.'};
    }
  }

  Future<Map<String, dynamic>> toggleSuperAdminAdminActive(int adminId, bool isActive) async {
    return updateSuperAdminAdmin(adminId, {'is_active': isActive});
  }

  Future<Map<String, dynamic>> resetSuperAdminAdminPassword(int adminId, String newPassword) async {
    return updateSuperAdminAdmin(adminId, {'password': newPassword});
  }

  // =========================================================
  // SUPER ADMIN: ADMIN PERFORMANCE & ACTIVITY REPORTING
  // =========================================================

  Future<Map<String, dynamic>> getSuperAdminAdminPerformance({
    String dateFilter = 'today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final token = await SessionService().getAccessToken();
      final queryParams = <String, String>{'date_filter': dateFilter};
      if (startDate != null && startDate.isNotEmpty) queryParams['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['end_date'] = endDate;

      final uri = Uri.parse('$baseUrl/api/accounts/super-admin/admin-performance/').replace(
        queryParameters: queryParams,
      );

      final response = await ApiClient.get(
        uri,
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
      return {'success': false, 'message': decoded['message'] ?? decoded['error'] ?? 'Failed to fetch admin performance reporting'};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable. Please try again.'};
    }
  }
}