import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'auth_service.dart';
import 'session_service.dart';

class FranchiseService {
  final SessionService _sessionService =
      SessionService();

  Future<String?> _getToken() async {
    return await _sessionService
        .getAccessToken();
  }

  Future<Map<String, String>> _headers() async {
  final token = await _getToken();

  print('ACCESS TOKEN = $token');

  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty)
      'Authorization': 'Bearer $token',
  };
}
  // ---------------------------------------
  // ALL FRANCHISES
  // ---------------------------------------

  Future<Map<String, dynamic>>
      getFranchises() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConstants.apiBaseUrl}/api/auth/franchises/',
            ),
            headers: await _headers(),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body);

        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message':
            _errorMessage(response),
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // ---------------------------------------
  // PENDING FRANCHISES
  // ---------------------------------------

  Future<Map<String, dynamic>>
      getPendingFranchises() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConstants.apiBaseUrl}/api/auth/franchises/pending/',
            ),
            headers: await _headers(),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body);

        return {
          'success': true,
          'data': decoded,
        };
      }

      return {
        'success': false,
        'message':
            _errorMessage(response),
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // ---------------------------------------
  // APPROVE
  // ---------------------------------------
Future<Map<String, dynamic>> createFranchise({
  required Map<String, dynamic> data,
}) async {
  try {
    final response = await http
        .post(
          Uri.parse(
            '${AppConstants.apiBaseUrl}/api/auth/franchises/create/',
          ),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final dynamic decoded =
        response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};

    if (response.statusCode == 201) {
      return {
        'success': true,
        'data': decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map
          ? decoded['message'] ??
              decoded['detail'] ??
              'Unable to create franchise.'
          : 'Unable to create franchise.',
    };
  } catch (_) {
    return {
      'success': false,
      'message':
          'Server unavailable. Please start the backend and try again.',
    };
  }
}
  Future<Map<String, dynamic>>
      approveFranchise(
    int franchiseId,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${AppConstants.apiBaseUrl}/api/auth/franchises/$franchiseId/approve/',
            ),
            headers: await _headers(),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final decoded =
          response.body.isNotEmpty
              ? jsonDecode(response.body)
              : {};

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': decoded,
          'message':
              decoded['message'] ??
                  'Franchise approved successfully.',
        };
      }

      return {
        'success': false,
        'message':
            decoded['message'] ??
                'Unable to approve franchise.',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  // ---------------------------------------
  // REJECT
  // ---------------------------------------

  Future<Map<String, dynamic>>
      rejectFranchise({
    required int franchiseId,
    required String reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${AppConstants.apiBaseUrl}/api/auth/franchises/$franchiseId/reject/',
            ),
            headers: await _headers(),
            body: jsonEncode({
              'reason': reason,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
          );

      final decoded =
          response.body.isNotEmpty
              ? jsonDecode(response.body)
              : {};

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': decoded,
          'message':
              decoded['message'] ??
                  'Franchise rejected successfully.',
        };
      }

      return {
        'success': false,
        'message':
            decoded['message'] ??
                'Unable to reject franchise.',
      };
    } catch (_) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }

  String _errorMessage(
    http.Response response,
  ) {
    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded is Map &&
          decoded['detail'] != null) {
        return decoded['detail']
            .toString();
      }

      if (decoded is Map &&
          decoded['message'] != null) {
        return decoded['message']
            .toString();
      }
    } catch (_) {}

    if (response.statusCode == 401) {
      return 'Session expired. Please login again.';
    }

    if (response.statusCode == 403) {
      return 'Admin permission required.';
    }

    return 'Something went wrong.';
  }
  Future<Map<String, dynamic>> updateFranchise({
  required int franchiseId,
  required Map<String, dynamic> data,
}) async {
  try {
    final response = await http
        .put(
          Uri.parse(
            '${AppConstants.apiBaseUrl}/api/auth/franchises/$franchiseId/update/',
          ),
          headers: await _headers(),
          body: jsonEncode(data),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final dynamic decoded =
        response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map
          ? decoded['message'] ??
              decoded['detail'] ??
              'Unable to update franchise.'
          : 'Unable to update franchise.',
    };
  } catch (_) {
    return {
      'success': false,
      'message':
          'Server unavailable. Please start the backend and try again.',
    };
  }
}
Future<Map<String, dynamic>> deleteFranchise(
  int franchiseId,
) async {
  try {
    final response = await http
        .delete(
          Uri.parse(
            '${AppConstants.apiBaseUrl}/api/auth/franchises/$franchiseId/delete/',
          ),
          headers: await _headers(),
        )
        .timeout(
          const Duration(seconds: 15),
        );

    final dynamic decoded =
        response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': decoded,
      };
    }

    return {
      'success': false,
      'message': decoded is Map
          ? decoded['message'] ??
              decoded['detail'] ??
              'Unable to delete franchise.'
          : 'Unable to delete franchise.',
    };
  } catch (_) {
    return {
      'success': false,
      'message':
          'Server unavailable. Please start the backend and try again.',
    };
  }
}
}