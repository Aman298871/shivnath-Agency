import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../notifications/customer_notifications_screen.dart';
import '../stock/customer_stock_screen.dart';
import '../wallet/customer_wallet_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final SessionService _sessionService = SessionService();
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = true;
  String _savedAddress = 'Farishta Complex, G.E. Road, Raipur, Chhattisgarh - 492001';

  Map<String, dynamic>? _territoryData;
  Map<String, dynamic>? _stockCycleData;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadUserDataInstant();
  }

  /// Phase 1 – show UI immediately from local session cache (no network).
  Future<void> _loadUserDataInstant() async {
    final user = await _sessionService.getCurrentUser();
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString('customer_delivery_address');

    if (mounted) {
      setState(() {
        _currentUser = user;
        if (address != null && address.isNotEmpty) {
          _savedAddress = address;
        }
        _isLoading = false; // show the screen immediately
      });
    }

    // Phase 2 – refresh territory/stock from network in the background.
    _refreshFromNetwork();
  }

  /// Phase 2 – silent background network refresh; updates UI when data arrives.
  Future<void> _refreshFromNetwork() async {
    try {
      final res = await _authService.getCurrentUser();
      if (!mounted) return;
      if (res['success'] == true && res['data'] is Map<String, dynamic>) {
        final d = res['data'] as Map<String, dynamic>;
        try {
          final user = UserModel.fromJson(d);
          await _sessionService.saveUser(user);
          _currentUser = user;
        } catch (_) {}
        setState(() {
          _territoryData = (d['territory_info'] ?? d['territory']) as Map<String, dynamic>?;
          _stockCycleData = d['stock_cycle'] as Map<String, dynamic>?;
        });
      }
    } catch (_) {
      // Network unavailable – silently ignore; cached data is already shown.
    }
  }

  Future<void> _loadUserData() async {
    await _loadUserDataInstant();
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
    return 'Valued Customer';
  }

  String get _displayEmail {
    final email = _currentUser?.email.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'customer@shivnath.com';
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

  // =========================================================
  // INTERACTIVE DIALOGS
  // =========================================================

  void _showPersonalInfoDialog() {
    final nameController = TextEditingController(text: _displayName);
    final phoneController = TextEditingController(text: _displayPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.person_outline, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('Personal Information', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: TextEditingController(text: _displayEmail),
              enabled: false,
              decoration: const InputDecoration(labelText: 'Email Address (Registered)', prefixIcon: Icon(Icons.email_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_currentUser != null) {
                final updated = _currentUser!.copyWith(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                );
                await _sessionService.saveUser(updated);
                setState(() => _currentUser = updated);
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Personal information updated successfully!'),
                  backgroundColor: Color(0xFF0284C7),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddressesDialog() {
    final addressController = TextEditingController(text: _savedAddress);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                const Text(
                  'Delivery Address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Set your primary address for water jar and bottle deliveries.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Complete Street / Office Address',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 18),
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
                  final newAddr = addressController.text.trim();
                  if (newAddr.isNotEmpty) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('customer_delivery_address', newAddr);
                    setState(() => _savedAddress = newAddr);
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Delivery address saved successfully!'),
                      backgroundColor: Color(0xFF0284C7),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Delivery Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTerritoryLocationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
    );

    final masterRes = await _authService.getTerritoryMaster();
    if (!mounted) return;
    Navigator.pop(context); // Close spinner

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

    String? selectedDistrict = _currentUser?.district?.isNotEmpty == true
        ? _currentUser!.district
        : (_territoryData?['district']?.toString() ?? districts.first['name'].toString());

    if (!districts.any((d) => d['name'].toString() == selectedDistrict)) {
      selectedDistrict = districts.first['name'].toString();
    }

    List<Map<String, dynamic>> getZonesForDistrict(String? distName) {
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
    int? selectedZoneId = _currentUser?.zoneId ?? (_territoryData?['zone_id'] as int?);
    if (selectedZoneId == null || !availableZones.any((z) => z['id'] == selectedZoneId)) {
      selectedZoneId = availableZones.isNotEmpty ? availableZones.first['id'] as int? : null;
    }

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
    String? selectedArea = _currentUser?.locality?.isNotEmpty == true
        ? _currentUser!.locality
        : (availableAreas.isNotEmpty ? availableAreas.first : null);
    if (selectedArea != null && !availableAreas.contains(selectedArea) && availableAreas.isNotEmpty) {
      selectedArea = availableAreas.first;
    }

    final addressController = TextEditingController(text: _currentUser?.address ?? _savedAddress);

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
                          'Delivery Territory & Location',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select your authoritative district, zone, and service area. No PIN code required.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedDistrict,
                    decoration: const InputDecoration(
                      labelText: 'Select District',
                      prefixIcon: Icon(Icons.map_outlined),
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Select Territory / Zone',
                      prefixIcon: Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(),
                    ),
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
                    decoration: const InputDecoration(
                      labelText: 'Select Service Area / Locality',
                      prefixIcon: Icon(Icons.near_me_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: availableAreas.map((area) {
                      return DropdownMenuItem(value: area, child: Text(area));
                    }).toList(),
                    onChanged: (val) {
                      setSheetState(() => selectedArea = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street Address / Landmark',
                      prefixIcon: Icon(Icons.home_outlined),
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

                        final payload = {
                          'district': selectedDistrict,
                          'zone_id': selectedZoneId,
                          'territory': zName,
                          if (selectedArea != null) 'locality': selectedArea,
                          'address': addressController.text.trim(),
                        };

                        final res = await _authService.updateProfile(payload);
                        if (!ctx.mounted) return;

                        if (res['success'] == true) {
                          Navigator.pop(ctx);
                          final prefs = await SharedPreferences.getInstance();
                          if (addressController.text.trim().isNotEmpty) {
                            await prefs.setString('customer_delivery_address', addressController.text.trim());
                            setState(() => _savedAddress = addressController.text.trim());
                          }
                          await _refreshFromNetwork();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Territory and service location updated successfully!'),
                              backgroundColor: Color(0xFF0284C7),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(res['message']?.toString() ?? 'Failed to update territory'),
                              backgroundColor: Colors.red.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Save Territory & Location'),
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.settings_outlined, color: Color(0xFF0284C7)),
            SizedBox(width: 10),
            Text('App Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.water_drop_outlined, color: Color(0xFF0284C7)),
              title: const Text('Water Brand Theme'),
              subtitle: const Text('Shivnath Pure Blue'),
              trailing: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF0284C7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notifications_active_outlined, color: Color(0xFF0284C7)),
              title: const Text('Order Tracking Updates'),
              subtitle: const Text('Real-time delivery status'),
              trailing: Switch(
                value: true,
                activeColor: const Color(0xFF0284C7),
                onChanged: (_) {},
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.support_agent, size: 48, color: Color(0xFF0284C7)),
            const SizedBox(height: 12),
            const Text(
              'Shivnath Customer Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Need help with an order, water delivery, or bulk enquiry? We are here to help!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await WhatsAppService.openWhatsApp(
                    phone: WhatsAppService.officialSupportPhone,
                    message: 'Namaste Shivnath Support Team,\nI have a question regarding drinking water supply.',
                  );
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Chat on WhatsApp Support'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCustomerServiceStatusChange(String currentStatus) async {
    final isHold = currentStatus == 'hold';
    final action = isHold ? 'resume' : 'hold';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isHold ? 'Resume Water Delivery' : 'Pause Water Delivery (Hold)', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHold
                  ? 'Reactivate daily water deliveries. Your remaining stock cycle days will resume from today.'
                  : 'Going on vacation or renovation? Pause your service and freeze remaining days safely.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: isHold ? 'Notes (Optional)' : 'Reason for Hold *',
                hintText: isHold ? 'e.g. Back from trip' : 'e.g. Out of station for 10 days',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isHold ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isHold ? 'Resume Now' : 'Confirm Pause'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUpdatingStatus = true);
    final res = await _authService.updateServiceStatus(
      action: action,
      reason: reasonController.text.trim(),
    );
    setState(() => _isUpdatingStatus = false);

    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['data']?['message']?.toString() ?? 'Service status updated successfully.'),
          backgroundColor: isHold ? const Color(0xFF16A34A) : const Color(0xFF0284C7),
        ),
      );
      _loadUserData();
    } else {
      final msg = res['message'] ?? 'Failed to update service status';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  Widget _buildServiceTerritoryCard() {
    final district = _currentUser?.district ?? _territoryData?['district']?.toString() ?? 'Unassigned';
    final zone = _currentUser?.zoneName ?? _territoryData?['zone_name']?.toString() ?? _territoryData?['territory']?.toString() ?? 'Unassigned';
    final locality = _currentUser?.locality ?? _territoryData?['locality']?.toString() ?? _territoryData?['service_area']?.toString() ?? 'Unassigned';
    final address = _currentUser?.address ?? _savedAddress;
    final franchise = _territoryData?['current_serving_franchise_name']?.toString() ??
        _territoryData?['registered_franchise_name']?.toString() ??
        'Shivnath Agency (Direct Company Fulfillment)';

    final cycleStatus = _stockCycleData?['status']?.toString() ?? 'none';
    final daysRemaining = _stockCycleData?['days_remaining'] ?? 0;
    final expectedEnd = _stockCycleData?['expected_end_date']?.toString() ?? '';

    final bool hasTerritory = district != 'Unassigned' && zone != 'Unassigned';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasTerritory ? const Color(0xFFBAE6FD) : const Color(0xFFFED7AA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.water_drop, color: Color(0xFF0284C7), size: 20),
                  SizedBox(width: 8),
                  Text('Delivery Territory & Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ],
              ),
              if (cycleStatus == 'active')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Text('ACTIVE', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w800, fontSize: 11)),
                )
              else if (cycleStatus == 'hold')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Text('ON HOLD', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 11)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasTerritory ? const Color(0xFFE0F2FE) : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasTerritory ? 'CONFIGURED' : 'ACTION REQUIRED',
                    style: TextStyle(
                      color: hasTerritory ? const Color(0xFF0284C7) : const Color(0xFFC2410C),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_city_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Territory: $zone ($district)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.near_me_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Locality / Service Area: $locality',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.home_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Address: $address',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Serving Supply: $franchise',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(hasTerritory ? 'Change Delivery Territory & Location' : 'Set Delivery Territory & Location'),
              onPressed: _showTerritoryLocationDialog,
            ),
          ),
          if (cycleStatus == 'active' || cycleStatus == 'hold') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cycleStatus == 'active' ? const Color(0xFFF0F9FF) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    cycleStatus == 'active' ? Icons.timer_outlined : Icons.pause_circle_outline,
                    color: cycleStatus == 'active' ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cycleStatus == 'active'
                              ? '$daysRemaining Days Supply Remaining'
                              : 'Service Paused ($daysRemaining Days Preserved)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: cycleStatus == 'active' ? const Color(0xFF0369A1) : const Color(0xFF92400E),
                          ),
                        ),
                        if (expectedEnd.isNotEmpty)
                          Text(
                            cycleStatus == 'active' ? 'Ends around $expectedEnd' : 'Countdown paused safely',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                  _isUpdatingStatus
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cycleStatus == 'active' ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            side: BorderSide(
                              color: cycleStatus == 'active' ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _handleCustomerServiceStatusChange(cycleStatus),
                          child: Text(
                            cycleStatus == 'active' ? 'Hold' : 'Resume',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                          ),
                        ),
                ],
              ),
            ),
          ],
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerStockScreen()),
              );
            },
            child: const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View Stock Cycles & History',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0284C7)),
                ],
              ),
            ),
          ),
        ],
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
        if (desktop) {
          return _desktop(context);
        }
        return _mobile(context);
      },
    );
  }

  // ===========================
  // MOBILE
  // ===========================

  Widget _mobile(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _profileContent(context, desktop: false),
    );
  }

  // ===========================
  // DESKTOP
  // ===========================

  Widget _desktop(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Profile',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Manage your account information and preferences.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT PROFILE CARD
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFE0F2FE),
                              child: Text(
                                _initials,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0284C7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _displayName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _displayEmail,
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _displayPhone,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                '💧 Pure Water Customer',
                                style: TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildServiceTerritoryCard(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 22),
                    // RIGHT OPTIONS
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _ProfileTile(
                            icon: Icons.person_outline,
                            title: 'Personal Information',
                            subtitle: 'Name, email and mobile number',
                            onTap: _showPersonalInfoDialog,
                          ),
                          _ProfileTile(
                            icon: Icons.location_on_outlined,
                            title: 'My Addresses',
                            subtitle: _savedAddress,
                            onTap: _showAddressesDialog,
                          ),
                          _ProfileTile(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'My Wallet',
                            subtitle: 'Balance and transactions',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CustomerWalletScreen()),
                              );
                            },
                          ),
                          _ProfileTile(
                            icon: Icons.water_drop_outlined,
                            title: 'My Water Stock',
                            subtitle: 'Active stock cycles, countdown & refills',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CustomerStockScreen()),
                              );
                            },
                          ),
                          _ProfileTile(
                            icon: Icons.notifications_none,
                            title: 'Notifications',
                            subtitle: 'View order and delivery updates',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
                              );
                            },
                          ),
                          _ProfileTile(
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            subtitle: 'App preferences and delivery alerts',
                            onTap: _showSettingsDialog,
                          ),
                          _ProfileTile(
                            icon: Icons.support_agent,
                            title: 'Help & Support',
                            subtitle: 'WhatsApp & phone customer support',
                            onTap: _showHelpSupportDialog,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                minimumSize: const Size(double.infinity, 48),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileContent(BuildContext context, {required bool desktop}) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFFE0F2FE),
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0284C7),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _displayName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _displayEmail,
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            _displayPhone,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(height: 14),
        _buildServiceTerritoryCard(),
        const SizedBox(height: 14),
        _ProfileTile(
          icon: Icons.person_outline,
          title: 'Personal Information',
          subtitle: 'Name, email and mobile number',
          onTap: _showPersonalInfoDialog,
        ),
        _ProfileTile(
          icon: Icons.location_on_outlined,
          title: 'My Addresses',
          subtitle: _savedAddress,
          onTap: _showAddressesDialog,
        ),
        _ProfileTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'My Wallet',
          subtitle: 'Balance and transactions',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerWalletScreen()),
            );
          },
        ),
        _ProfileTile(
          icon: Icons.water_drop_outlined,
          title: 'My Water Stock',
          subtitle: 'Active stock cycles, countdown & refills',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerStockScreen()),
            );
          },
        ),
        _ProfileTile(
          icon: Icons.notifications_none,
          title: 'Notifications',
          subtitle: 'View order and delivery updates',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerNotificationsScreen()),
            );
          },
        ),
        _ProfileTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'App preferences and delivery alerts',
          onTap: _showSettingsDialog,
        ),
        _ProfileTile(
          icon: Icons.support_agent,
          title: 'Help & Support',
          subtitle: 'WhatsApp & phone customer support',
          onTap: _showHelpSupportDialog,
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(double.infinity, 48),
          ),
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF0284C7)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        onTap: onTap,
      ),
    );
  }
}