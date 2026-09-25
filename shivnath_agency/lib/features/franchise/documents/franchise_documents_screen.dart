import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class FranchiseDocumentsScreen extends StatefulWidget {
  const FranchiseDocumentsScreen({super.key});

  @override
  State<FranchiseDocumentsScreen> createState() =>
      _FranchiseDocumentsScreenState();
}

class _FranchiseDocumentsScreenState extends State<FranchiseDocumentsScreen> {
  final List<Map<String, dynamic>> _documents = [
    {
      'id': 'DOC-01',
      'title': 'Franchise Master Agreement',
      'filename': 'Shivnath_Franchise_Agreement_2026.pdf',
      'status': 'Verified',
      'date': '12 Jan 2026',
      'size': '2.4 MB',
      'doc_number': 'SHIV-FR-AGR-8842',
      'type': 'Agreement',
    },
    {
      'id': 'DOC-02',
      'title': 'GST Registration Certificate',
      'filename': 'GST_Certificate_27AAACS1234F1Z5.pdf',
      'status': 'Verified',
      'date': '15 Jan 2026',
      'size': '1.1 MB',
      'doc_number': '27AAACS1234F1Z5',
      'type': 'Tax Compliance',
    },
    {
      'id': 'DOC-03',
      'title': 'Aadhaar Identification Card',
      'filename': 'Aadhaar_Card_Owner.pdf',
      'status': 'Verified',
      'date': '10 Jan 2026',
      'size': '850 KB',
      'doc_number': 'XXXX-XXXX-9182',
      'type': 'KYC Identity',
    },
    {
      'id': 'DOC-04',
      'title': 'PAN Card (Business / Owner)',
      'filename': 'PAN_Card_ABCDE1234F.pdf',
      'status': 'Verified',
      'date': '10 Jan 2026',
      'size': '620 KB',
      'doc_number': 'ABCDE1234F',
      'type': 'KYC Identity',
    },
    {
      'id': 'DOC-05',
      'title': 'FSSAI Water Packaging License',
      'filename': 'FSSAI_License_10022021000123.pdf',
      'status': 'Verified',
      'date': '18 Jan 2026',
      'size': '1.8 MB',
      'doc_number': '10022021000123',
      'type': 'Food Safety',
    },
    {
      'id': 'DOC-06',
      'title': 'Water Quality Lab Test Report',
      'filename': 'Water_TDS_Lab_Report_Q1_2026.pdf',
      'status': 'Under Review',
      'date': '05 Sep 2026',
      'size': '3.2 MB',
      'doc_number': 'LAB-NABL-7729',
      'type': 'Quality Testing',
    },
  ];

  void _viewDocument(Map<String, dynamic> doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF0284C7),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                doc['title'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _docRow(
                    'Document No.',
                    doc['doc_number']?.toString() ?? 'N/A',
                  ),
                  const Divider(height: 14),
                  _docRow(
                    'File Name',
                    doc['filename']?.toString() ?? 'document.pdf',
                  ),
                  const Divider(height: 14),
                  _docRow('Category', doc['type']?.toString() ?? 'General'),
                  const Divider(height: 14),
                  _docRow('Upload Date', doc['date']?.toString() ?? 'Recent'),
                  const Divider(height: 14),
                  _docRow('File Size', doc['size']?.toString() ?? '1.2 MB'),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verification Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      _statusBadge(doc['status']?.toString() ?? 'Verified'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFDC2626),
                    size: 38,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    doc['filename']?.toString() ?? 'document.pdf',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Text(
                    'Encrypted & verified on Shivnath Agency Cloud',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${doc['title']} downloaded to your device.'),
                  backgroundColor: const Color(0xFF0284C7),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Widget _docRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final isVerified = status == 'Verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 13,
            color: isVerified
                ? const Color(0xFF16A34A)
                : const Color(0xFFD97706),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isVerified
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
          ),
        ],
      ),
    );
  }

  void _openUploadDialog() {
    String selectedType = 'FSSAI License';
    final docNumberCtrl = TextEditingController();
    String selectedFileName = '';
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bCtx) => StatefulBuilder(
        builder: (bCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(bCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.upload_file_rounded,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Upload Franchise Document',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(bCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Document Type',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'FSSAI License',
                    child: Text('FSSAI Food Safety & Water License'),
                  ),
                  DropdownMenuItem(
                    value: 'GST Certificate',
                    child: Text('GST Registration Certificate'),
                  ),
                  DropdownMenuItem(
                    value: 'Trade License',
                    child: Text('Municipal Trade License'),
                  ),
                  DropdownMenuItem(
                    value: 'Lab Test Report',
                    child: Text('Water Mineral & TDS Lab Report'),
                  ),
                  DropdownMenuItem(
                    value: 'Rent / Property Agreement',
                    child: Text('Plant / Shop Rent Agreement'),
                  ),
                  DropdownMenuItem(
                    value: 'Identity Proof',
                    child: Text('Aadhaar / Voter ID'),
                  ),
                  DropdownMenuItem(
                    value: 'PAN Card',
                    child: Text('Business / Personal PAN Card'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedType = val);
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Document / Registration Number',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: docNumberCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. FSSAI-100220260012 or GSTIN',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Document File (PDF / Image)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final file = result.files.first;
                      final sizeInKb = file.size > 0 ? (file.size / 1024).round() : 1500;
                      final sizeDisplay = sizeInKb > 1024
                          ? '${(sizeInKb / 1024).toStringAsFixed(1)} MB'
                          : '$sizeInKb KB';
                      setModalState(() {
                        selectedFileName = file.name;
                      });
                    }
                  } catch (e) {
                    setModalState(() {
                      selectedFileName = '${selectedType.replaceAll(' ', '_')}_Upload.pdf';
                    });
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selectedFileName.isNotEmpty
                          ? const Color(0xFF0284C7)
                          : const Color(0xFFCBD5E1),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        selectedFileName.isNotEmpty
                            ? Icons.check_circle_rounded
                            : Icons.cloud_upload_outlined,
                        color: selectedFileName.isNotEmpty
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF0284C7),
                        size: 34,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        selectedFileName.isNotEmpty
                            ? selectedFileName
                            : 'Tap to browse or attach document file',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selectedFileName.isNotEmpty
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF475569),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedFileName.isNotEmpty
                            ? 'File selected & ready for upload'
                            : 'Supports PDF, JPG, PNG up to 10 MB',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () {
                          if (selectedFileName.isEmpty) {
                            selectedFileName =
                                '${selectedType.replaceAll(' ', '_')}_Document.pdf';
                          }

                          setModalState(() => isUploading = true);

                          Future.delayed(const Duration(milliseconds: 600), () {
                            if (!mounted) return;
                            setState(() {
                              _documents.insert(0, {
                                'id': 'DOC-0${_documents.length + 1}',
                                'title': selectedType,
                                'filename': selectedFileName,
                                'status': 'Under Review',
                                'date': 'Today',
                                'size': '1.4 MB',
                                'doc_number':
                                    docNumberCtrl.text.trim().isNotEmpty
                                    ? docNumberCtrl.text.trim()
                                    : 'SHIV-DOC-${DateTime.now().millisecondsSinceEpoch % 10000}',
                                'type': selectedType,
                              });
                            });

                            Navigator.pop(bCtx);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$selectedType uploaded successfully! Sent for verification.',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF0284C7),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          });
                        },
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_done_rounded),
                  label: Text(
                    isUploading
                        ? 'Uploading & Encrypting...'
                        : 'Upload & Submit Document',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text('Franchise Documents'),
                  actions: [
                    IconButton(
                      tooltip: 'Upload Document',
                      icon: const Icon(Icons.upload_file_rounded),
                      onPressed: _openUploadDialog,
                    ),
                  ],
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Franchise Documents & KYC',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Manage verified compliance certificates, licenses and agreements.',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _openUploadDialog,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: const Text('Upload Document'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _documents.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: desktop ? 2 : 1,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: desktop ? 3.4 : 2.7,
                      ),
                      itemBuilder: (context, index) {
                        final doc = _documents[index];

                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _viewDocument(doc),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.description_outlined,
                                      color: Color(0xFF0284C7),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc['title'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          doc['filename'] as String,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            _statusBadge(
                                              doc['status'] as String,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              doc['date'] as String,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'View Document Details',
                                    onPressed: () => _viewDocument(doc),
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    if (!desktop)
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _openUploadDialog,
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text(
                            'Upload New Document',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
