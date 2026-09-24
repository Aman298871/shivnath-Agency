import 'dart:convert';

import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';

class FollowupService {
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

  // ===========================================
  // GET FOLLOWUPS
  // ===========================================

  Future<Map<String, dynamic>> getFollowups() async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/api/followups/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // GET STATS
  // ===========================================

  Future<Map<String, dynamic>> getStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/api/followups/stats/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // CREATE
  // ===========================================

  Future<Map<String, dynamic>> createFollowup({
    required int leadId,
    required DateTime dateTime,
    required String type,
    required String note,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(
          '$baseUrl/api/followups/',
        ),
        headers: await _headers(),
        body: jsonEncode({
          "lead_id": leadId,
          "followup_datetime":
              dateTime.toIso8601String(),
          "followup_type": type,
          "note": note,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // UPDATE / RESCHEDULE
  // ===========================================

  Future<Map<String, dynamic>> updateFollowup({
    required int id,
    required DateTime dateTime,
    required String type,
    required String note,
  }) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse(
          '$baseUrl/api/followups/$id/',
        ),
        headers: await _headers(),
        body: jsonEncode({
          "followup_datetime":
              dateTime.toIso8601String(),
          "followup_type": type,
          "note": note,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // COMPLETE
  // ===========================================

  Future<Map<String, dynamic>> completeFollowup(int id, {String? outcome}) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse('$baseUrl/api/followups/$id/complete/'),
        headers: await _headers(),
        body: jsonEncode({
          if (outcome != null && outcome.isNotEmpty) 'outcome': outcome,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // GET COMPLETED FOLLOWUPS
  // ===========================================

  Future<Map<String, dynamic>> getCompletedFollowups({
    String? period,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final qp = <String, String>{};
      if (period != null && period.isNotEmpty) qp['period'] = period;
      if (search != null && search.isNotEmpty) qp['search'] = search;
      if (startDate != null && startDate.isNotEmpty) qp['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) qp['end_date'] = endDate;

      final uri = Uri.parse('$baseUrl/api/followups/completed/').replace(
        queryParameters: qp.isEmpty ? null : qp,
      );

      final response = await ApiClient.get(
        uri,
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // DELETE
  // ===========================================

  Future<Map<String, dynamic>>
      deleteFollowup(int id) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse(
          '$baseUrl/api/followups/$id/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        "success": false,
        "message":
            "Server unavailable. Please start the backend and try again.",
      };
    }
  }

  // ===========================================
  // RESPONSE
  // ===========================================

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
        "success": true,
        "data": decoded,
      };
    }

    String message = "Something went wrong.";
    if (decoded is Map<String, dynamic>) {
      if (decoded['code'] == 'token_not_valid' ||
          (decoded['detail'] != null && decoded['detail'].toString().contains('token not valid'))) {
        message = 'Your session has expired. Please log in again.';
        _sessionService.refreshAccessToken();
      } else if (decoded['message'] != null) {
        message = decoded['message'].toString();
      } else if (decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    }

    return {
      "success": false,
      "statusCode": response.statusCode,
      "message": message,
      "data": decoded,
    };
  }
}