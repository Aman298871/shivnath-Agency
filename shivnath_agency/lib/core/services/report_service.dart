import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_constants.dart';
import 'session_service.dart';

class ReportExportResult {
  final bool success;
  final String? filePath;
  final String? fileName;
  final String message;
  final int byteCount;
  final Uint8List? bytes;

  ReportExportResult({
    required this.success,
    this.filePath,
    this.fileName,
    required this.message,
    this.byteCount = 0,
    this.bytes,
  });
}

class ReportService {
  static String get baseUrl => AppConstants.apiBaseUrl;
  final SessionService _sessionService = SessionService();

  Future<Map<String, String>> _headers() async {
    final token = await _sessionService.getAccessToken();
    return {
      'Accept': 'text/csv, application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Exports a report from the authoritative backend CSV endpoint
  /// and saves it locally to the device, making it ready to open or share.
  Future<ReportExportResult> exportReport({
    required String reportType,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? franchiseId,
    String? search,
    Uint8List? fallbackLocalBytes,
    bool openAfterDownload = true,
    bool shareAfterDownload = false,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (period != null && period.isNotEmpty && period != 'All Time') {
        queryParams['period'] = period.toLowerCase().replaceAll(' ', '_');
      }
      if (startDate != null) {
        queryParams['start_date'] = DateFormat('yyyy-MM-dd').format(startDate);
      }
      if (endDate != null) {
        queryParams['end_date'] = DateFormat('yyyy-MM-dd').format(endDate);
      }
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status;
      }
      if (franchiseId != null && franchiseId.isNotEmpty) {
        queryParams['franchise_id'] = franchiseId;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$baseUrl/api/reports/export/$reportType/',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      Uint8List? csvBytes;
      String? downloadedFileName;

      try {
        final headers = await _headers();
        final response = await http
            .get(
              uri,
              headers: headers,
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          csvBytes = response.bodyBytes;
          final cd = response.headers['content-disposition'] ?? '';
          if (cd.contains('filename=')) {
            final match = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
            if (match != null) {
              downloadedFileName = match.group(1);
            }
          }
        }
      } catch (netErr) {
        debugPrint('[ReportService] Remote export network error: $netErr');
      }

      // Fallback to local bytes if remote endpoint could not be reached
      if (csvBytes == null || csvBytes.isEmpty) {
        if (fallbackLocalBytes != null && fallbackLocalBytes.isNotEmpty) {
          csvBytes = fallbackLocalBytes;
        } else {
          return ReportExportResult(
            success: false,
            message:
                'Unable to download report from server. Please check internet connection.',
          );
        }
      }

      // Generate a standardized file name if not provided by backend
      final now = DateTime.now();
      final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(now);
      final finalFileName =
          downloadedFileName ?? 'waterwala_${reportType}_$dateSlug.csv';

      // Save file to device storage
      String? savedFilePath;
      if (!kIsWeb) {
        try {
          Directory appDir;
          if (Platform.isAndroid) {
            // On Android, prefer external storage or documents dir for user visibility
            final extDir = await getExternalStorageDirectory();
            appDir = extDir ?? await getApplicationDocumentsDirectory();
          } else {
            appDir = await getApplicationDocumentsDirectory();
          }

          final file = File('${appDir.path}/$finalFileName');
          await file.writeAsBytes(csvBytes, flush: true);
          savedFilePath = file.path;
        } catch (fileErr) {
          debugPrint(
            '[ReportService] Error writing to application storage: $fileErr',
          );
        }
      }

      // Also trigger FileSaver as secondary download registration (primary on Web)
      try {
        final baseName = finalFileName.replaceAll('.csv', '');
        await FileSaver.instance.saveFile(
          name: baseName,
          bytes: csvBytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
        if (kIsWeb) {
          savedFilePath = finalFileName;
        }
      } catch (_) {}

      // Automatically launch OpenFilex if requested (native only)
      if (!kIsWeb && openAfterDownload && savedFilePath != null) {
        try {
          final openRes = await OpenFilex.open(savedFilePath);
          debugPrint('[ReportService] OpenFilex result: ${openRes.message}');
        } catch (openErr) {
          debugPrint('[ReportService] OpenFilex error: $openErr');
        }
      }

      // Trigger Share sheet if requested (native only)
      if (!kIsWeb && shareAfterDownload && savedFilePath != null) {
        try {
          await Share.shareXFiles([
            XFile(savedFilePath),
          ], text: 'WATER WALA Report: $finalFileName');
        } catch (shareErr) {
          debugPrint('[ReportService] Share error: $shareErr');
        }
      }

      return ReportExportResult(
        success: true,
        filePath: savedFilePath,
        fileName: finalFileName,
        byteCount: csvBytes.length,
        bytes: csvBytes,
        message:
            'Report saved as $finalFileName (${(csvBytes.length / 1024).toStringAsFixed(1)} KB)',
      );
    } catch (e) {
      return ReportExportResult(
        success: false,
        message: 'Report export error: $e',
      );
    }
  }

  /// Opens an already downloaded report file
  Future<void> openReportFile(String filePath) async {
    try {
      await OpenFilex.open(filePath);
    } catch (e) {
      debugPrint('[ReportService] Failed to open report: $e');
    }
  }

  /// Opens the system Share sheet for a report file
  Future<void> shareReportFile(String filePath, {String? fileName}) async {
    try {
      await Share.shareXFiles([
        XFile(filePath),
      ], text: 'WATER WALA Report ${fileName != null ? ': $fileName' : ''}');
    } catch (e) {
      debugPrint('[ReportService] Failed to share report: $e');
    }
  }
}
