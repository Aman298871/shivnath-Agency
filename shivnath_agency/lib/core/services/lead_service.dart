import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import 'api_client.dart';
import 'session_service.dart';


class LeadService {
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
  // GET ALL LEADS
  // =====================================================

  Future<Map<String, dynamic>> getLeads({
    String? search,
    String? status,
    String? score,
    String? city,
  }) async {
    try {
      final queryParameters =
          <String, String>{};

      if (search != null &&
          search.trim().isNotEmpty) {
        queryParameters['search'] =
            search.trim();
      }

      if (status != null &&
          status.trim().isNotEmpty &&
          status != 'All') {
        queryParameters['status'] =
            _statusToApi(status);
      }

      if (score != null &&
          score.trim().isNotEmpty &&
          score != 'All') {
        queryParameters['score'] =
            score.toLowerCase();
      }

      if (city != null &&
          city.trim().isNotEmpty) {
        queryParameters['city'] =
            city.trim();
      }

      final uri = Uri.parse(
        '$baseUrl/api/leads/',
      ).replace(
        queryParameters:
            queryParameters.isEmpty
                ? null
                : queryParameters,
      );

      final response = await ApiClient.get(
        uri,
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // GET SINGLE LEAD
  // =====================================================

  Future<Map<String, dynamic>> getLead(
    int id,
  ) async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/api/leads/$id/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // CREATE LEAD
  // =====================================================

  Future<Map<String, dynamic>> createLead(
    Map<String, dynamic> data,
  )
   
  async {
    
    try {
      final body = _prepareLeadData(data);
      debugPrint('[LeadService] Creating lead: $body');

      final response = await ApiClient.post(
        Uri.parse(
          '$baseUrl/api/leads/',
        ),
        headers: await _headers(),
        body: jsonEncode(
          _prepareLeadData(data),
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
    
  }


  // =====================================================
  // UPDATE LEAD
  // =====================================================

  Future<Map<String, dynamic>> updateLead(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await ApiClient.patch(
        Uri.parse(
          '$baseUrl/api/leads/$id/',
        ),
        headers: await _headers(),
        body: jsonEncode(
          _prepareLeadData(data),
        ),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // DELETE LEAD
  // =====================================================

  Future<Map<String, dynamic>> deleteLead(
    int id,
  ) async {
    try {
      final response = await ApiClient.delete(
        Uri.parse(
          '$baseUrl/api/leads/$id/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // CONVERT LEAD (Customer or Franchise Onboarding)
  // =====================================================

  Future<Map<String, dynamic>> convertLead(
    int id,
    String action, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(
          '$baseUrl/api/leads/$id/convert/',
        ),
        headers: await _headers(),
        body: jsonEncode({
          'action': action,
          ...?data,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // GET LEAD STATS
  // =====================================================

  Future<Map<String, dynamic>>
      getLeadStats() async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/api/leads/stats/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // GET ACTIVITIES
  // =====================================================

  Future<Map<String, dynamic>>
      getActivities(
    int leadId,
  ) async {
    try {
      final response = await ApiClient.get(
        Uri.parse(
          '$baseUrl/api/leads/'
          '$leadId/activities/',
        ),
        headers: await _headers(),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // ADD ACTIVITY
  // =====================================================

  Future<Map<String, dynamic>>
      addActivity({
    required int leadId,
    required String type,
    required String title,
    required String description,
  }) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(
          '$baseUrl/api/leads/'
          '$leadId/activities/',
        ),
        headers: await _headers(),
        body: jsonEncode({
          'activity_type': type,
          'title': title,
          'description': description,
        }),
      );

      return _decodeResponse(response);
    } catch (e) {
      return {
        'success': false,
        'message':
            'Server unavailable. Please start the backend and try again.',
      };
    }
  }


  // =====================================================
  // PREPARE FLUTTER DATA FOR API
  // =====================================================

  Map<String, dynamic> _prepareLeadData(
    Map<String, dynamic> data,
  ) {
    return {
      'name':
          data['name']?.toString().trim() ??
              '',

      'phone':
          data['phone']?.toString().trim() ??
              '',

      'city':
          data['city']?.toString().trim() ??
              '',

      'district':
          data['district']
                  ?.toString()
                  .trim() ??
              '',

      'investment_budget':
          data['budget']
                  ?.toString()
                  .trim() ??
              '',

      'existing_business':
          _existingBusinessToApi(
        data['existingBusiness']
                ?.toString() ??
            'No',
      ),

      'commercial_space':
          _commercialSpaceToApi(
        data['commercialSpace']
                ?.toString() ??
            'No',
      ),

      'previous_experience':
          data['experience']
                  ?.toString()
                  .trim() ??
              '',

      'preferred_location':
          data['location']
                  ?.toString()
                  .trim() ??
              '',

      'score':
          data['score']
                  ?.toString()
                  .toLowerCase() ??
              'warm',

      'status':
          _statusToApi(
        data['status']?.toString() ??
            'New Lead',
      ),

      'assigned_executive':
          data['executive']
                  ?.toString()
                  .trim() ??
              '',

      'next_followup':
          _followupToApi(
        data['followup']?.toString() ?? '',
      ),

      'source':
          data['source']
                  ?.toString()
                  .trim() ??
              '',

      'notes':
          data['notes']
                  ?.toString()
                  .trim() ??
              '',
      if (data.containsKey('interest_level')) 'interest_level': data['interest_level'],
      if (data.containsKey('site_visit_planned')) 'site_visit_planned': data['site_visit_planned'],
      if (data.containsKey('site_visit_completed')) 'site_visit_completed': data['site_visit_completed'],
      if (data.containsKey('site_visit_date')) 'site_visit_date': data['site_visit_date'],
      if (data.containsKey('site_visit_notes')) 'site_visit_notes': data['site_visit_notes'],
    };
  }


  // =====================================================
  // MAP BACKEND LEAD -> CURRENT SCREEN FORMAT
  // =====================================================

  Map<String, dynamic> mapLead(
    Map<String, dynamic> item,
  ) {
    return {
      'id': item['id'],

      'name':
          item['name']?.toString() ?? '',

      'phone':
          item['phone']?.toString() ?? '',

      'city':
          item['city']?.toString() ?? '',

      'district':
          item['district']?.toString() ?? '',

      'budget':
          item['investment_budget']
                  ?.toString() ??
              '',

      'existingBusiness':
          item['existing_business_display']
                  ?.toString() ??
              _existingBusinessDisplay(
                item['existing_business']
                        ?.toString() ??
                    '',
              ),

      'commercialSpace':
          item['commercial_space_display']
                  ?.toString() ??
              _commercialSpaceDisplay(
                item['commercial_space']
                        ?.toString() ??
                    '',
              ),

      'experience':
          item['previous_experience']
                  ?.toString() ??
              '',

      'location':
          item['preferred_location']
                  ?.toString() ??
              '',

      'score':
          item['score_display']
                  ?.toString() ??
              _capitalize(
                item['score']
                        ?.toString() ??
                    'warm',
              ),

      'status':
          item['status_display']
                  ?.toString() ??
              _statusDisplay(
                item['status']
                        ?.toString() ??
                    'new_lead',
              ),

      'executive':
          item['assigned_executive']
                  ?.toString() ??
              '',

      'followup':
          _formatFollowup(
        item['next_followup'],
      ),

      'email':
          item['email']?.toString() ?? '',

      'created_at':
          item['created_at']?.toString() ?? '',

      'updated_at':
          item['updated_at']?.toString() ?? '',

      'score_category':
          item['score_category']?.toString() ?? item['score']?.toString() ?? '',

      'lead_score_number':
          item['lead_score_number'] ?? 0,

      'source':
          item['source']?.toString() ?? '',

      'notes':
          item['notes']?.toString() ?? '',

      'interest_level':
          item['interest_level']?.toString() ?? item['score_display'] ?? '',

      'site_visit_planned':
          item['site_visit_planned'] == true,

      'site_visit_completed':
          item['site_visit_completed'] == true,

      'site_visit_date':
          item['site_visit_date']?.toString() ?? '',

      'site_visit_notes':
          item['site_visit_notes']?.toString() ?? '',

      'lead_type':
          item['lead_type']?.toString().toUpperCase() ?? 'FRANCHISE',

      'lead_type_display':
          item['lead_type_display']?.toString() ?? (item['lead_type'] == 'CUSTOMER' ? 'Customer' : 'Franchise'),

      'customer':
          item['customer'],

      'franchise':
          item['franchise'],

      'activities':
          item['activities'] ?? [],
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
      if (decoded is Map<String, dynamic>) {
        return {
          'success': true,
          'data': decoded,
        };
      }

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
        message =
            decoded['message'].toString();
      } else if (decoded['detail'] != null) {
        message =
            decoded['detail'].toString();
      } else if (decoded['errors'] != null) {
        message =
            _formatErrors(
          decoded['errors'],
        );
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
          messages.add(
            value.join(', '),
          );
        } else {
          messages.add(
            value.toString(),
          );
        }
      });

      return messages.join('\n');
    }

    return errors.toString();
  }


  // =====================================================
  // STATUS CONVERSION
  // =====================================================

  String _statusToApi(
    String value,
  ) {
    switch (value) {
      case 'New Lead':
        return 'new_lead';

      case 'Contacted':
        return 'contacted';

      case 'Follow-up 1':
        return 'followup_1';

      case 'Follow-up 2':
        return 'followup_2';

      case 'Interested':
        return 'interested';

      case 'Site Visit Scheduled':
        return 'site_visit_scheduled';

      case 'Agreement Pending':
        return 'agreement_pending';

      case 'Franchise Confirmed':
        return 'franchise_confirmed';

      case 'Hot Lead':
        return 'hot_lead';

      case 'Follow-up Required':
        return 'followup_required';

      case 'Site Visit Completed':
        return 'site_visit_completed';

      case 'Converted':
        return 'converted';

      case 'Not Interested':
        return 'not_interested';

      default:
        return value
            .trim()
            .toLowerCase();
    }
  }


  String _statusDisplay(
    String value,
  ) {
    switch (value) {
      case 'new_lead':
        return 'New Lead';

      case 'contacted':
        return 'Contacted';

      case 'followup_1':
        return 'Follow-up 1';

      case 'followup_2':
        return 'Follow-up 2';

      case 'interested':
        return 'Interested';

      case 'site_visit_scheduled':
        return 'Site Visit Scheduled';

      case 'agreement_pending':
        return 'Agreement Pending';

      case 'franchise_confirmed':
        return 'Franchise Confirmed';

      case 'lost':
        return 'Lost';

      case 'hot_lead':
        return 'Hot Lead';

      case 'followup_required':
        return 'Follow-up Required';

      case 'site_visit_completed':
        return 'Site Visit Completed';

      case 'converted':
        return 'Converted';

      case 'not_interested':
        return 'Not Interested';

      default:
        return value;
    }
  }


  String _existingBusinessToApi(
    String value,
  ) {
    return value.toLowerCase() == 'yes'
        ? 'yes'
        : 'no';
  }


  String _existingBusinessDisplay(
    String value,
  ) {
    return value == 'yes'
        ? 'Yes'
        : 'No';
  }


  String _commercialSpaceToApi(
    String value,
  ) {
    switch (value.toLowerCase()) {
      case 'available':
        return 'available';

      case 'searching':
        return 'searching';

      default:
        return 'no';
    }
  }


  String _commercialSpaceDisplay(
    String value,
  ) {
    switch (value) {
      case 'available':
        return 'Available';

      case 'searching':
        return 'Searching';

      default:
        return 'No';
    }
  }


  String _capitalize(
    String value,
  ) {
    if (value.isEmpty) {
      return '';
    }

    return value[0].toUpperCase() +
        value.substring(1);
  }


  // =====================================================
  // FOLLOWUP DATE
  // =====================================================

  dynamic _followupToApi(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      // 1. Try ISO8601 or YYYY-MM-DD directly
      final directDt = DateTime.tryParse(trimmed);
      if (directDt != null) {
        return directDt.toIso8601String();
      }

      // 2. Try DD/MM/YYYY
      if (trimmed.contains('/')) {
        final parts = trimmed.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day, 10, 0).toIso8601String();
        }
      }

      // 3. Try "25 Sep 2026" or "25 September 2026"
      final spaceParts = trimmed.split(RegExp(r'\s+'));
      if (spaceParts.length >= 3) {
        final day = int.tryParse(spaceParts[0]);
        final monthStr = spaceParts[1];
        final year = int.tryParse(spaceParts[2]);
        final month = _monthNumber(monthStr);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day, 10, 0).toIso8601String();
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  String _formatFollowup(
    dynamic value,
  ) {
    if (value == null ||
        value.toString().isEmpty) {
      return '';
    }

    try {
      final date =
          DateTime.parse(
        value.toString(),
      ).toLocal();

      return '${date.day.toString().padLeft(2, '0')} '
          '${_monthName(date.month)} '
          '${date.year}';
    } catch (_) {
      return value.toString();
    }
  }


  int? _monthNumber(
    String month,
  ) {
    switch (month.toLowerCase()) {
      case 'jan':
        return 1;
      case 'feb':
        return 2;
      case 'mar':
        return 3;
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'jun':
        return 6;
      case 'jul':
        return 7;
      case 'aug':
        return 8;
      case 'sep':
        return 9;
      case 'oct':
        return 10;
      case 'nov':
        return 11;
      case 'dec':
        return 12;
    }

    return null;
  }


  String _monthName(
    int month,
  ) {
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

    return months[month];
  }
  
}