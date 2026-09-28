import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/franchise_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/support_desk_modal.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';

class FranchiseProfileScreen extends StatefulWidget {
  const FranchiseProfileScreen({super.key});

  @override
  State<FranchiseProfileScreen> createState() => _FranchiseProfileScreenState();
}

class _FranchiseProfileScreenState extends State<FranchiseProfileScreen> {
  final SessionService _sessionService = SessionService();
  final AuthService _authService = AuthService();
  final FranchiseService _franchiseService = FranchiseService();
  UserModel? _currentUser;
  Map<String, dynamic>? _territoryInfo;
  bool _isTerritoryAssigned = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoadingDocs = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadDocuments();
  }

  Future<void> _loadUser() async {
    final user = await _sessionService.getCurrentUser();
    if (mounted && user != null) {
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    }

    try {
      final res = await _authService.getCurrentUser();
      if (mounted &&
          res['success'] == true &&
          res['data'] is Map<String, dynamic>) {
        final d = res['data'] as Map<String, dynamic>;
        try {
          final u = UserModel.fromJson(d);
          await _sessionService.saveUser(u);
          _currentUser = u;
        } catch (_) {}
        setState(() {
          _territoryInfo = d['territory_info'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(d['territory_info'])
              : null;
          _isTerritoryAssigned =
              _territoryInfo?['is_assigned'] == true ||
              (_currentUser?.isTerritoryAssigned == true) ||
              (_territoryInfo?['territory'] != null &&
                  _territoryInfo!['territory'].toString().isNotEmpty);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoadingDocs = true);
    final res = await _franchiseService.getFranchiseDocuments();
    if (mounted) {
      List<Map<String, dynamic>> docList = [];
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        if (data is Map && data['documents'] is List) {
          docList = List<Map<String, dynamic>>.from(data['documents']);
        } else if (data is List) {
          docList = List<Map<String, dynamic>>.from(data);
        }
      }
      setState(() {
        _documents = docList;
        _isLoadingDocs = false;
      });
    }
  }

  void _openUploadDocumentSheet({String? defaultType, int? replaceDocId}) {
    String selectedType = defaultType ?? 'GST';
    final docNumberCtrl = TextEditingController();
    String? selectedFileName;
    List<int>? selectedFileBytes;
    bool isUploading = false;

    final docTypeLabels = {
      'GST': 'GST Registration Certificate',
      'PAN': 'Business / Owner PAN Card',
      'TRADE_LICENSE': 'Municipal Trade License / FSSAI',
      'AADHAAR': 'Proprietor / Director Aadhaar Card',
      'AGREEMENT': 'Wholesale Distributor Agreement',
      'OTHER': 'Other Supporting Document',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.upload_file_rounded,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        replaceDocId != null
                            ? 'Re-upload Document'
                            : 'Upload Business Document',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Document Type *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: docTypeLabels.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: docNumberCtrl,
                    decoration: InputDecoration(
                      labelText: 'Document / Registration Number (Optional)',
                      hintText: selectedType == 'GST'
                          ? 'e.g. 22AAAAA0000A1Z5'
                          : selectedType == 'PAN'
                          ? 'e.g. ABCDE1234F'
                          : 'Registration / ID Number',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Document File (PDF, JPG, PNG):',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: isUploading
                        ? null
                        : () async {
                            try {
                              final result = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: [
                                      'pdf',
                                      'jpg',
                                      'jpeg',
                                      'png',
                                    ],
                                    allowMultiple: false,
                                    withData: true,
                                  );
                              if (result != null && result.files.isNotEmpty) {
                                final f = result.files.first;
                                List<int>? bytes = f.bytes;
                                if ((bytes == null || bytes.isEmpty) &&
                                    f.path != null &&
                                    f.path!.isNotEmpty) {
                                  try {
                                    bytes = await File(f.path!).readAsBytes();
                                  } catch (_) {}
                                }
                                setSheetState(() {
                                  selectedFileName = f.name;
                                  selectedFileBytes = bytes;
                                });
                              }
                            } catch (e) {
                              debugPrint('Error picking file: $e');
                            }
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: selectedFileName != null
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFileName != null
                              ? const Color(0xFF86EFAC)
                              : const Color(0xFFCBD5E1),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFileName != null
                                ? Icons.check_circle
                                : Icons.attach_file,
                            color: selectedFileName != null
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedFileName ??
                                      'Tap to browse document file',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selectedFileName != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selectedFileName != null
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (selectedFileBytes != null)
                                  Text(
                                    '${(selectedFileBytes!.length / 1024).toStringAsFixed(1)} KB',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            selectedFileName != null ? 'Change' : 'Browse',
                            style: const TextStyle(
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isUploading
                          ? null
                          : () async {
                              if (selectedFileBytes == null ||
                                  selectedFileName == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select a document file (PDF or Image).',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isUploading = true);
                              final res = await _franchiseService
                                  .uploadFranchiseDocument(
                                    documentType: selectedType,
                                    documentNumber: docNumberCtrl.text.trim(),
                                    fileBytes: selectedFileBytes!,
                                    fileName: selectedFileName!,
                                  );
                              setSheetState(() => isUploading = false);
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                              if (res['success'] == true) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Document uploaded successfully for verification.',
                                      ),
                                      backgroundColor: Color(0xFF16A34A),
                                    ),
                                  );
                                }
                                _loadDocuments();
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        res['message']?.toString() ??
                                            'Failed to upload document.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      child: isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              replaceDocId != null
                                  ? 'Re-upload Document'
                                  : 'Submit Document',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDocument(int docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Document?'),
        content: const Text(
          'Are you sure you want to remove this document? You will need to upload a replacement if required for verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final res = await _franchiseService.deleteFranchiseDocument(docId);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted.'),
              backgroundColor: Colors.black87,
            ),
          );
        }
        _loadDocuments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to delete document.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _viewDocument(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document file is not accessible.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _sessionService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.roleSelection,
      (_) => false,
    );
  }

  String get _displayName {
    final name = _currentUser?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Franchise Partner';
  }

  String get _displayEmail {
    final email = _currentUser?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'franchise@shivnath.com';
  }

  String get _displayPhone {
    final phone = _currentUser?.phone.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return '+91 98062 47194';
  }

  String get _initials {
    final parts = _displayName.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _displayName
        .substring(0, _displayName.length >= 2 ? 2 : 1)
        .toUpperCase();
  }

  void _editProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    final phoneCtrl = TextEditingController(text: _displayPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Edit Franchise Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Franchise Owner Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              final newPhone = phoneCtrl.text.trim();
              final res = await _authService.updateProfile({
                'name': newName,
                'phone': newPhone,
              });
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (res['success'] == true) {
                await _loadUser();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Franchise profile updated successfully!'),
                    backgroundColor: Color(0xFF0284C7),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? 'Failed to update profile',
                    ),
                    backgroundColor: Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showInitialTerritoryDialog() async {
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        );
      },
    );

    final masterRes = await _authService.getTerritoryMaster();
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.pop(dialogContext!);
    }
    if (!mounted) return;

    List<Map<String, dynamic>> districts = [];
    if (masterRes['success'] == true &&
        masterRes['data'] is Map &&
        masterRes['data']['districts'] is List) {
      districts = List<Map<String, dynamic>>.from(
        masterRes['data']['districts'],
      );
    }

    if (districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load territory master. Please check connection.',
          ),
        ),
      );
      return;
    }

    String selectedDistrict = districts.first['name'].toString();

    List<Map<String, dynamic>> getZonesForDistrict(String distName) {
      final d = districts.firstWhere(
        (elem) => elem['name'].toString() == distName,
        orElse: () => districts.first,
      );
      if (d['zones'] is List) {
        return List<Map<String, dynamic>>.from(d['zones']);
      }
      return [];
    }

    var availableZones = getZonesForDistrict(selectedDistrict);
    int? selectedZoneId = availableZones.isNotEmpty
        ? availableZones.first['id'] as int?
        : null;

    List<String> getAreasForZone(int? zId) {
      if (zId == null) return [];
      final z = availableZones.firstWhere(
        (elem) => elem['id'] == zId,
        orElse: () => {},
      );
      if (z['areas'] is List) {
        return List<String>.from(z['areas'].map((a) => a.toString()));
      }
      return [];
    }

    var availableAreas = getAreasForZone(selectedZoneId);
    String? selectedArea = availableAreas.isNotEmpty
        ? availableAreas.first
        : null;
    final addressCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.add_location_alt_outlined,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Initial Territory Setup',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Assign your authoritative franchise distribution zone. Once approved by Admin, this becomes read-only.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDistrict,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select District',
                      border: OutlineInputBorder(),
                    ),
                    items: districts.map((d) {
                      final name = d['name'].toString();
                      return DropdownMenuItem(
                        value: name,
                        child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedDistrict = val;
                          availableZones = getZonesForDistrict(val);
                          selectedZoneId = availableZones.isNotEmpty
                              ? availableZones.first['id'] as int?
                              : null;
                          availableAreas = getAreasForZone(selectedZoneId);
                          selectedArea = availableAreas.isNotEmpty
                              ? availableAreas.first
                              : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedZoneId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Territory / Zone',
                      border: OutlineInputBorder(),
                    ),
                    items: availableZones.map((z) {
                      final name = z['name'].toString();
                      return DropdownMenuItem(
                        value: z['id'] as int?,
                        child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedZoneId = val;
                          availableAreas = getAreasForZone(val);
                          selectedArea = availableAreas.isNotEmpty
                              ? availableAreas.first
                              : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedArea,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Service Area / Locality',
                      border: OutlineInputBorder(),
                    ),
                    items: availableAreas
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text(a, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ))
                        .toList(),
                    onChanged: (val) => setSheetState(() => selectedArea = val),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Registered Franchise Facility Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final zName =
                            availableZones
                                .firstWhere(
                                  (z) => z['id'] == selectedZoneId,
                                  orElse: () => {},
                                )['name']
                                ?.toString() ??
                            '';

                        final res = await _authService.updateProfile({
                          'district': selectedDistrict,
                          'zone_id': selectedZoneId,
                          'territory': zName,
                          'locality': ?selectedArea,
                          'address': addressCtrl.text.trim(),
                        });
                        if (!ctx.mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          await _loadUser();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Initial territory assigned successfully!',
                              ),
                              backgroundColor: Color(0xFF0284C7),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                res['message']?.toString() ??
                                    'Failed to assign territory',
                              ),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Save Initial Territory'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: desktop
              ? null
              : AppBar(
                  title: const Text(
                    'Franchise Profile',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      const Text(
                        'Franchise Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'Manage your authorized franchise details and business credentials.',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 22),
                    ],

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFFE0F2FE),
                            child: Text(
                              _initials,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Authorized Water Franchise',
                              style: TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _ProfileField('Registered Email', _displayEmail),
                          _ProfileField('Contact Phone', _displayPhone),
                          _ProfileField(
                            'Assigned District',
                            _territoryInfo?['district']?.toString() ??
                                _currentUser?.district ??
                                _currentUser?.city ??
                                'Unassigned',
                          ),
                          _ProfileField(
                            'Assigned Territory / Zone',
                            _territoryInfo?['territory']?.toString() ??
                                _currentUser?.zoneName ??
                                _currentUser?.territory ??
                                'Unassigned',
                          ),
                          _ProfileField(
                            'Service Area / Coverage',
                            _territoryInfo?['service_area']?.toString() ??
                                _currentUser?.locality ??
                                'All Assigned Localities',
                          ),
                          if ((_territoryInfo?['address'] != null &&
                                  _territoryInfo!['address']
                                      .toString()
                                      .isNotEmpty) ||
                              (_currentUser?.address != null &&
                                  _currentUser!.address.isNotEmpty))
                            _ProfileField(
                              'Facility Address',
                              _territoryInfo?['address']?.toString() ??
                                  _currentUser?.address ??
                                  '',
                            ),
                          _ProfileField(
                            'Franchise Status',
                            'Active & Approved',
                          ),
                          _ProfileField(
                            'Territory Status',
                            _isTerritoryAssigned
                                ? 'Authoritative Assignment (Admin Managed)'
                                : 'Initial Setup Required',
                          ),
                          const SizedBox(height: 16),
                          if (!_isTerritoryAssigned) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _showInitialTerritoryDialog,
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                ),
                                label: const Text(
                                  'Complete Initial Territory Setup',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFBAE6FD),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Color(0xFF0284C7),
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Authoritative territory assignment is managed by Admin to maintain customer relationship stability.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF0369A1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: BrandColors.greenDark,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: _editProfileDialog,
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit Details'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF25D366),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  onPressed: () => WhatsAppService.openWhatsApp(
                                    phone: WhatsAppService.officialSupportPhone,
                                    message:
                                        'Namaste Admin Team,\nFranchise query from $_displayName ($_displayEmail).',
                                  ),
                                  icon: const Icon(Icons.chat_outlined),
                                  label: const Text('Admin WhatsApp'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: BrandColors.greenDark,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () => SupportDeskModal.show(context),
                              icon: const Icon(
                                Icons.headset_mic_outlined,
                                color: BrandColors.greenDark,
                              ),
                              label: const Text(
                                'Admin Support Desk (+91 98062 47194)',
                                style: TextStyle(
                                  color: BrandColors.greenDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildKycDocumentsSection(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
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

  Widget _buildKycDocumentsSection() {
    final standardDocTypes = [
      {
        'type': 'GST',
        'title': 'GST Registration Certificate',
        'subtitle': 'Tax compliance for wholesale invoicing',
        'required': true,
      },
      {
        'type': 'PAN',
        'title': 'Business / Owner PAN Card',
        'subtitle': 'Identity & corporate tax verification',
        'required': true,
      },
      {
        'type': 'TRADE_LICENSE',
        'title': 'Trade License / FSSAI',
        'subtitle': 'Municipal / state food & beverage permit',
        'required': false,
      },
      {
        'type': 'AADHAAR',
        'title': 'Proprietor / Director Aadhaar Card',
        'subtitle': 'Authorized signatory proof of identity',
        'required': false,
      },
      {
        'type': 'AGREEMENT',
        'title': 'Shivnath Franchise Agreement',
        'subtitle': 'Signed distributorship contract',
        'required': false,
      },
    ];

    Map<String, Map<String, dynamic>> uploadedByType = {};
    List<Map<String, dynamic>> otherDocs = [];

    for (final doc in _documents) {
      final t = doc['document_type']?.toString().toUpperCase() ?? 'OTHER';
      if (['GST', 'PAN', 'TRADE_LICENSE', 'AADHAAR', 'AGREEMENT'].contains(t) &&
          !uploadedByType.containsKey(t)) {
        uploadedByType[t] = doc;
      } else {
        otherDocs.add(doc);
      }
    }

    final uploadedCount = uploadedByType.length + otherDocs.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_shared_outlined,
                  color: Color(0xFF0284C7),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Documents & KYC',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$uploadedCount uploaded',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () => _openUploadDocumentSheet(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Document'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Keep your franchise compliance up-to-date. Upload official documents for plant verification and GST invoicing.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingDocs)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            ...standardDocTypes.map((item) {
              final typeKey = item['type'] as String;
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final isRequired = item['required'] as bool;
              final doc = uploadedByType[typeKey];

              return _buildDocCard(
                typeKey: typeKey,
                title: title,
                subtitle: subtitle,
                isRequired: isRequired,
                doc: doc,
              );
            }),
            if (otherDocs.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Other Uploaded Files',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              ...otherDocs.map((doc) {
                return _buildDocCard(
                  typeKey: doc['document_type']?.toString() ?? 'OTHER',
                  title:
                      doc['document_name']?.toString() ?? 'Supporting Document',
                  subtitle: doc['document_number']?.toString() ?? '',
                  isRequired: false,
                  doc: doc,
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDocCard({
    required String typeKey,
    required String title,
    required String subtitle,
    required bool isRequired,
    Map<String, dynamic>? doc,
  }) {
    final isUploaded = doc != null;
    final isVerified =
        doc?['is_verified'] == true ||
        doc?['verification_status'] == 'verified';
    final isRejected = doc?['verification_status'] == 'rejected';
    final fileUrl =
        doc?['file']?.toString() ?? doc?['file_url']?.toString() ?? '';
    final docNumber = doc?['document_number']?.toString() ?? '';
    final docId = doc?['id'] is int
        ? doc!['id'] as int
        : int.tryParse(doc?['id']?.toString() ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVerified
              ? const Color(0xFF86EFAC)
              : isUploaded
              ? const Color(0xFFCBD5E1)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isVerified
                  ? const Color(0xFFDCFCE7)
                  : isUploaded
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isVerified
                  ? Icons.verified_rounded
                  : isUploaded
                  ? Icons.description_outlined
                  : Icons.upload_file_outlined,
              size: 20,
              color: isVerified
                  ? const Color(0xFF16A34A)
                  : isUploaded
                  ? const Color(0xFFD97706)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRequired && !isUploaded) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (docNumber.isNotEmpty)
                  Text(
                    'No: $docNumber',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0284C7),
                    ),
                  )
                else
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VERIFIED',
                      style: TextStyle(
                        color: Color(0xFF15803D),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isRejected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'REJECTED - RE-UPLOAD',
                      style: TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isUploaded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PENDING VERIFICATION',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NOT UPLOADED',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isUploaded) ...[
            if (fileUrl.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                tooltip: 'View Document',
                visualDensity: VisualDensity.compact,
                onPressed: () => _viewDocument(fileUrl),
              ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              onSelected: (action) {
                if (action == 'replace') {
                  _openUploadDocumentSheet(
                    defaultType: typeKey,
                    replaceDocId: docId,
                  );
                } else if (action == 'delete' && docId != null) {
                  _deleteDocument(docId);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'replace',
                  child: Text(
                    'Re-upload / Replace',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Document',
                    style: TextStyle(fontSize: 13, color: Colors.red),
                  ),
                ),
              ],
            ),
          ] else ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _openUploadDocumentSheet(defaultType: typeKey),
              child: const Text(
                'Upload',
                style: TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String title;
  final String value;

  const _ProfileField(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
