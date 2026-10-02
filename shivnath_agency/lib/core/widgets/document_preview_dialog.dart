import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_saver/file_saver.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_constants.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../utils/app_toast.dart';

class DocumentPreviewDialog extends StatefulWidget {
  final String title;
  final String documentUrl;
  final String? documentNumber;
  final String? documentType;
  final String? verificationStatus;

  const DocumentPreviewDialog({
    super.key,
    required this.title,
    required this.documentUrl,
    this.documentNumber,
    this.documentType,
    this.verificationStatus,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String documentUrl,
    String? documentNumber,
    String? documentType,
    String? verificationStatus,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DocumentPreviewDialog(
        title: title,
        documentUrl: documentUrl,
        documentNumber: documentNumber,
        documentType: documentType,
        verificationStatus: verificationStatus,
      ),
    );
  }

  @override
  State<DocumentPreviewDialog> createState() => _DocumentPreviewDialogState();
}

class _DocumentPreviewDialogState extends State<DocumentPreviewDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _fileBytes;
  String _contentType = '';
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  String get _resolvedDocumentUrl {
    final raw = widget.documentUrl.trim();
    if (raw.isEmpty) return '';
    if (raw.contains('localhost') || raw.contains('127.0.0.1') || raw.contains('10.0.2.2')) {
      final parsed = Uri.parse(raw);
      return '${AppConstants.apiBaseUrl}${parsed.path}${parsed.hasQuery ? '?${parsed.query}' : ''}';
    }
    if (raw.startsWith('/')) {
      return '${AppConstants.apiBaseUrl}$raw';
    }
    return raw;
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionService().getAccessToken();
      _token = token;

      final docUrl = _resolvedDocumentUrl;
      if (docUrl.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No document URL is associated with this application.';
        });
        return;
      }

      final uri = Uri.parse(docUrl);
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await ApiClient.get(uri, headers: headers).timeout(
        const Duration(seconds: 25),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cType = response.headers['content-type'] ?? '';
        setState(() {
          _isLoading = false;
          _fileBytes = response.bodyBytes;
          _contentType = cType;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Access denied. You do not have permission to view this document.';
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Document file was not found on server storage.';
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load document (Status: ${response.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Network error while fetching document. Please try again.';
      });
    }
  }

  bool get _isImage {
    if (_contentType.toLowerCase().contains('image')) return true;
    final lowerUrl = _resolvedDocumentUrl.toLowerCase();
    return lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.png');
  }

  bool get _isPdf {
    if (_contentType.toLowerCase().contains('pdf')) return true;
    return _resolvedDocumentUrl.toLowerCase().endsWith('.pdf');
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final base = _resolvedDocumentUrl;
      final separator = base.contains('?') ? '&' : '?';
      final finalUrl = _token != null && _token!.isNotEmpty
          ? '$base${separator}token=$_token'
          : base;

      final uri = Uri.parse(finalUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        AppToast.error(context, 'Could not launch URL');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Failed to open document: $e');
    }
  }

  Future<void> _downloadFile() async {
    if (_fileBytes == null) return;
    try {
      final isPdf = _isPdf;
      final ext = isPdf ? 'pdf' : (_contentType.contains('png') ? 'png' : 'jpg');
      final mime = isPdf ? MimeType.pdf : (_contentType.contains('png') ? MimeType.png : MimeType.jpeg);
      final sanitizedTitle = widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = 'Shivnath_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: _fileBytes!,
        ext: ext,
        mimeType: mime,
      );

      if (!mounted) return;
      AppToast.success(context, 'Document downloaded successfully.');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Download failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 720,
          maxHeight: 760,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: const Color(0xFF0F172A),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.documentNumber != null && widget.documentNumber!.isNotEmpty)
                          Text(
                            'Reg/License #: ${widget.documentNumber}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (widget.verificationStatus != null)
                    _statusBadge(widget.verificationStatus!),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              child: _buildBody(),
            ),

            // Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                  ),
                  Row(
                    children: [
                      if (_fileBytes != null) ...[
                        OutlinedButton.icon(
                          onPressed: _downloadFile,
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Download'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0284C7),
                            side: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      ElevatedButton.icon(
                        onPressed: _openInExternalBrowser,
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Open External'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Fetching authenticated document...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDocument,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry Loading'),
              ),
            ],
          ),
        ),
      );
    }

    if (_fileBytes != null && _isImage) {
      return Container(
        color: const Color(0xFF1E293B),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              _fileBytes!,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Text('Unable to display image preview', style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
    }

    // PDF or other binary file card
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                size: 56,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'PDF Document • ${_fileBytes != null ? (_fileBytes!.lengthInBytes / 1024).toStringAsFixed(1) : '0'} KB',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'This is an official FSSAI / KYC PDF certificate.\nClick "Open External" to view and verify the full multi-page document in your browser/PDF viewer, or click "Download".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    final upper = status.toUpperCase();

    switch (upper) {
      case 'VERIFIED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case 'PENDING':
      case 'PENDING_VERIFICATION':
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF0284C7);
        break;
      case 'MANUAL_REVIEW_REQUIRED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        break;
      case 'FAILED':
      case 'REJECTED':
      case 'EXPIRED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        upper.replaceAll('_', ' '),
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
