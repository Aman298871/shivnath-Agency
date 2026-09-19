import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/whatsapp_service.dart';
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
  UserModel? _currentUser;
  Map<String, dynamic>? _territoryInfo;
  bool _isTerritoryAssigned = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
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
      if (mounted && res['success'] == true && res['data'] is Map<String, dynamic>) {
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
          _isTerritoryAssigned = _territoryInfo?['is_assigned'] == true ||
              (_currentUser?.isTerritoryAssigned == true) ||
              (_territoryInfo?['territory'] != null && _territoryInfo!['territory'].toString().isNotEmpty);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    return _displayName.substring(0, _displayName.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _editProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    final phoneCtrl = TextEditingController(text: _displayPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Edit Franchise Profile', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Franchise Owner Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Contact Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                    content: Text(res['message']?.toString() ?? 'Failed to update profile'),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
    );

    final masterRes = await _authService.getTerritoryMaster();
    if (!mounted) return;
    Navigator.pop(context);

    List<Map<String, dynamic>> districts = [];
    if (masterRes['success'] == true && masterRes['data'] is Map && masterRes['data']['districts'] is List) {
      districts = List<Map<String, dynamic>>.from(masterRes['data']['districts']);
    }

    if (districts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load territory master. Please check connection.')),
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
    int? selectedZoneId = availableZones.isNotEmpty ? availableZones.first['id'] as int? : null;

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
    String? selectedArea = availableAreas.isNotEmpty ? availableAreas.first : null;
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
                      const Icon(Icons.add_location_alt_outlined, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Initial Territory Setup',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Assign your authoritative franchise distribution zone. Once approved by Admin, this becomes read-only.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDistrict,
                    decoration: const InputDecoration(labelText: 'Select District', border: OutlineInputBorder()),
                    items: districts.map((d) {
                      final name = d['name'].toString();
                      return DropdownMenuItem(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedDistrict = val;
                          availableZones = getZonesForDistrict(val);
                          selectedZoneId = availableZones.isNotEmpty ? availableZones.first['id'] as int? : null;
                          availableAreas = getAreasForZone(selectedZoneId);
                          selectedArea = availableAreas.isNotEmpty ? availableAreas.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: selectedZoneId,
                    decoration: const InputDecoration(labelText: 'Select Territory / Zone', border: OutlineInputBorder()),
                    items: availableZones.map((z) {
                      final name = z['name'].toString();
                      return DropdownMenuItem(value: z['id'] as int?, child: Text(name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setSheetState(() {
                          selectedZoneId = val;
                          availableAreas = getAreasForZone(val);
                          selectedArea = availableAreas.isNotEmpty ? availableAreas.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedArea,
                    decoration: const InputDecoration(labelText: 'Service Area / Locality', border: OutlineInputBorder()),
                    items: availableAreas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final zName = availableZones.firstWhere(
                          (z) => z['id'] == selectedZoneId,
                          orElse: () => {},
                        )['name']?.toString() ?? '';

                        final res = await _authService.updateProfile({
                          'district': selectedDistrict,
                          'zone_id': selectedZoneId,
                          'territory': zName,
                          if (selectedArea != null) 'locality': selectedArea,
                          'address': addressCtrl.text.trim(),
                        });
                        if (!ctx.mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          await _loadUser();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Initial territory assigned successfully!'),
                              backgroundColor: Color(0xFF0284C7),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? 'Failed to assign territory'),
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
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
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
                  title: const Text('Franchise Profile', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(desktop ? 28 : 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 900,
                ),
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
                        style: TextStyle(
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                        ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                          _ProfileField('Assigned District', _territoryInfo?['district']?.toString() ?? _currentUser?.district ?? _currentUser?.city ?? 'Unassigned'),
                          _ProfileField('Assigned Territory / Zone', _territoryInfo?['territory']?.toString() ?? _currentUser?.zoneName ?? _currentUser?.territory ?? 'Unassigned'),
                          _ProfileField('Service Area / Coverage', _territoryInfo?['service_area']?.toString() ?? _currentUser?.locality ?? 'All Assigned Localities'),
                          if ((_territoryInfo?['address'] != null && _territoryInfo!['address'].toString().isNotEmpty) || (_currentUser?.address != null && _currentUser!.address.isNotEmpty))
                            _ProfileField('Facility Address', _territoryInfo?['address']?.toString() ?? _currentUser?.address ?? ''),
                          _ProfileField('Franchise Status', 'Active & Approved'),
                          _ProfileField('Territory Status', _isTerritoryAssigned ? 'Authoritative Assignment (Admin Managed)' : 'Initial Setup Required'),
                          const SizedBox(height: 16),
                          if (!_isTerritoryAssigned) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: _showInitialTerritoryDialog,
                                icon: const Icon(Icons.add_location_alt_outlined),
                                label: const Text('Complete Initial Territory Setup'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Authoritative territory assignment is managed by Admin to maintain customer relationship stability.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
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
                                    backgroundColor: const Color(0xFF0284C7),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  onPressed: () => WhatsAppService.openWhatsApp(
                                    phone: WhatsAppService.officialSupportPhone,
                                    message: 'Namaste Admin Team,\nFranchise query from $_displayName ($_displayEmail).',
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
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: _logout,
                              icon: const Icon(Icons.logout, color: Colors.red),
                              label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
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