import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_client.dart';
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

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/auth/franchise/dashboard-stats/'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to fetch dashboard stats', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable.'};
    }
  }

  Future<Map<String, dynamic>> getFranchiseDetail(int franchiseId) async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${AppConstants.apiBaseUrl}/api/auth/admin/franchises/$franchiseId/detail/'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': 'Failed to fetch franchise detail', 'data': decoded};
    } catch (_) {
      return {'success': false, 'message': 'Server unavailable.'};
    }
  }

  // ---------------------------------------
  // FRANCHISE / DEALER KYC DOCUMENTS
  // ---------------------------------------

  Future<Map<String, dynamic>> getFranchiseDocuments([int? dealerId]) async {
    try {
      final url = dealerId != null
          ? '${AppConstants.apiBaseUrl}/api/accounts/dealers/$dealerId/documents/'
          : '${AppConstants.apiBaseUrl}/api/accounts/dealers/documents/';
      final response = await ApiClient.get(
        Uri.parse(url),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Failed to load documents'};
    } catch (_) {
      return {'success': false, 'message': 'Network error loading documents'};
    }
  }

  Future<Map<String, dynamic>> uploadFranchiseDocument({
    required String documentType,
    required String documentNumber,
    required List<int> fileBytes,
    required String fileName,
    int? dealerId,
  }) async {
    try {
      final token = await _getToken();
      final url = dealerId != null
          ? '${AppConstants.apiBaseUrl}/api/accounts/dealers/$dealerId/documents/'
          : '${AppConstants.apiBaseUrl}/api/accounts/dealers/documents/';

      final request = http.MultipartRequest('POST', Uri.parse(url));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields['document_type'] = documentType;
      request.fields['document_number'] = documentNumber;
      request.files.add(
        http.MultipartFile.fromBytes(
          'document_file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamed = await ApiClient.sendRequest(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded, 'message': decoded['message'] ?? 'Document uploaded successfully.'};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Upload failed (${response.statusCode})'};
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteFranchiseDocument(int docId, [int? dealerId]) async {
    try {
      final url = dealerId != null
          ? '${AppConstants.apiBaseUrl}/api/accounts/dealers/$dealerId/documents/'
          : '${AppConstants.apiBaseUrl}/api/accounts/dealers/documents/';
      final response = await ApiClient.delete(
        Uri.parse('$url?document_id=$docId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'message': decoded['message'] ?? 'Document deleted successfully.'};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Failed to delete document'};
    } catch (_) {
      return {'success': false, 'message': 'Network error deleting document'};
    }
  }

  /// Admin: Verify (approve/reject) a franchise KYC document
  Future<Map<String, dynamic>> verifyFranchiseDocument({
    required int docId,
    required String action, // 'VERIFIED' or 'REJECTED'
    String rejectionReason = '',
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse('${AppConstants.apiBaseUrl}/api/accounts/dealers/documents/$docId/verify/'),
        headers: await _headers(),
        body: jsonEncode({
          'action': action,
          'rejection_reason': rejectionReason,
        }),
      ).timeout(const Duration(seconds: 15));

      final dynamic decoded = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': decoded, 'message': decoded['message'] ?? 'Document updated.'};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Action failed.'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}