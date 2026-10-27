import 'package:flutter/material.dart';
import '../../../core/services/delivery_pricing_service.dart';
import '../../../core/widgets/app_toast.dart';

class DeliveryPricingDialog extends StatefulWidget {
  const DeliveryPricingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeliveryPricingDialog(),
    );
  }

  @override
  State<DeliveryPricingDialog> createState() => _DeliveryPricingDialogState();
}

class _DeliveryPricingDialogState extends State<DeliveryPricingDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DeliveryPricingService _service = DeliveryPricingService();

  bool _loadingOrigin = true;
  String? _originError;
  bool _loadingBands = true;
  String? _bandsError;
  bool _savingOrigin = false;
  bool _creatingBand = false;

  // Origin Controllers
  final _originFormKey = GlobalKey<FormState>();
  final _depotNameCtrl =
      TextEditingController(text: 'Shivnath Agency Central Dispatch');
  final _addressCtrl = TextEditingController(
      text:
          'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh');
  final _pincodeCtrl = TextEditingController(text: '492014');
  final _latCtrl = TextEditingController(text: '21.267800');
  final _lngCtrl = TextEditingController(text: '81.671100');
  final _freeRadiusCtrl = TextEditingController(text: '0.0');
  final _maxRadiusCtrl = TextEditingController(text: '25.0');
  final _defaultFeeCtrl = TextEditingController(text: '30.0');
  bool _originActive = true;

  // Live Slider State (synced with text controllers)
  double _maxRadiusSlider = 25.0;
  double _freeRadiusSlider = 0.0;

  // Persisted snapshot for comparing and display
  double _savedMaxRadius = 25.0;
  double _savedFreeRadius = 0.0;
  double _savedDefaultFee = 30.0;
  String _savedDepotName = 'Central Dispatch';

  // Band Controllers
  final _bandFormKey = GlobalKey<FormState>();
  final _minKmCtrl = TextEditingController(text: '0');
  final _maxKmCtrl = TextEditingController(text: '10');
  final _chargeCtrl = TextEditingController(text: '30');
  final _labelCtrl = TextEditingController(text: 'Local Delivery');

  List<dynamic> _bands = [];

  // Simulator
  final _simLatCtrl = TextEditingController(text: '21.2200');
  final _simLngCtrl = TextEditingController(text: '81.3000');
  String? _simResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _maxRadiusCtrl.addListener(() {
      final v = double.tryParse(_maxRadiusCtrl.text);
      if (v != null && v >= 0 && v <= 100 && (v - _maxRadiusSlider).abs() > 0.1) {
        setState(() => _maxRadiusSlider = v);
      }
    });

    _freeRadiusCtrl.addListener(() {
      final v = double.tryParse(_freeRadiusCtrl.text);
      if (v != null && v >= 0 && v <= 30 && (v - _freeRadiusSlider).abs() > 0.1) {
        setState(() => _freeRadiusSlider = v);
      }
    });

    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _depotNameCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _freeRadiusCtrl.dispose();
    _maxRadiusCtrl.dispose();
    _defaultFeeCtrl.dispose();
    _minKmCtrl.dispose();
    _maxKmCtrl.dispose();
    _chargeCtrl.dispose();
    _labelCtrl.dispose();
    _simLatCtrl.dispose();
    _simLngCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOriginData() async {
    setState(() {
      _loadingOrigin = true;
      _originError = null;
    });
    final originRes = await _service.getDeliveryOrigin();
    if (mounted) {
      setState(() {
        _loadingOrigin = false;
        if (originRes['origin'] is Map) {
          var o = originRes['origin'] as Map;
          if (o.containsKey('origin') && o['origin'] is Map) {
            o = o['origin'] as Map;
          }
          if (o['name'] != null) _depotNameCtrl.text = o['name'].toString();
          if (o['depot_name'] != null) _depotNameCtrl.text = o['depot_name'].toString();
          if (o['address'] != null) _addressCtrl.text = o['address'].toString();
          if (o['pincode'] != null) _pincodeCtrl.text = o['pincode'].toString();
          if (o['latitude'] != null) _latCtrl.text = o['latitude'].toString();
          if (o['longitude'] != null) _lngCtrl.text = o['longitude'].toString();

          final freeVal = double.tryParse(o['free_delivery_radius_km']?.toString() ?? '0') ?? 0.0;
          final maxVal = double.tryParse(o['max_serviceable_radius_km']?.toString() ?? '25') ?? 25.0;
          final feeVal = double.tryParse(o['default_delivery_charge']?.toString() ?? '30') ?? 30.0;

          _freeRadiusCtrl.text = freeVal.toStringAsFixed(1);
          _maxRadiusCtrl.text = maxVal.toStringAsFixed(1);
          _defaultFeeCtrl.text = feeVal.toStringAsFixed(1);

          _freeRadiusSlider = freeVal.clamp(0.0, 30.0);
          _maxRadiusSlider = maxVal.clamp(0.0, 100.0);

          _savedFreeRadius = freeVal;
          _savedMaxRadius = maxVal;
          _savedDefaultFee = feeVal;
          _savedDepotName = _depotNameCtrl.text;

          _originActive = o['is_active'] ?? true;
        }
        if (originRes['success'] != true) {
          _originError = originRes['message']?.toString() ?? 'Failed to load delivery origin settings.';
        } else {
          _originError = null;
        }
      });
    }
  }

  Future<void> _loadBandsData() async {
    setState(() {
      _loadingBands = true;
      _bandsError = null;
    });
    final bandsRes = await _service.getDistanceBands();
    if (mounted) {
      setState(() {
        _loadingBands = false;
        if (bandsRes['bands'] is List && (bandsRes['bands'] as List).isNotEmpty) {
          _bands = bandsRes['bands'] as List;
        }
        if (bandsRes['success'] != true) {
          _bandsError = bandsRes['message']?.toString() ?? 'Failed to load distance bands.';
        } else {
          _bandsError = null;
        }
      });
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadOriginData(), _loadBandsData()]);
  }

  Future<void> _saveOrigin() async {
    if (!_originFormKey.currentState!.validate()) return;
    setState(() => _savingOrigin = true);

    final res = await _service.updateDeliveryOrigin({
      'name': _depotNameCtrl.text.trim(),
      'depot_name': _depotNameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'latitude': double.tryParse(_latCtrl.text.trim()) ?? 21.2678,
      'longitude': double.tryParse(_lngCtrl.text.trim()) ?? 81.6711,
      'free_delivery_radius_km': double.tryParse(_freeRadiusCtrl.text.trim()) ?? 0.0,
      'max_serviceable_radius_km': double.tryParse(_maxRadiusCtrl.text.trim()) ?? 25.0,
      'default_delivery_charge': double.tryParse(_defaultFeeCtrl.text.trim()) ?? 30.0,
      'is_active': _originActive,
    });

    if (mounted) {
      setState(() => _savingOrigin = false);
      if (res['success'] == true) {
        AppToast.success(context, 'Delivery origin & radius settings persisted.');
        await _loadAllData();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to save delivery origin');
      }
    }
  }

  Future<void> _createBand() async {
    if (!_bandFormKey.currentState!.validate()) return;
    setState(() => _creatingBand = true);

    final res = await _service.createDistanceBand({
      'name': _labelCtrl.text.trim(),
      'label': _labelCtrl.text.trim(),
      'min_distance_km': double.tryParse(_minKmCtrl.text.trim()) ?? 0.0,
      'max_distance_km': double.tryParse(_maxKmCtrl.text.trim()) ?? 10.0,
      'delivery_charge': double.tryParse(_chargeCtrl.text.trim()) ?? 30.0,
      'is_active': true,
      'is_supported': true,
      'applies_to': 'ALL',
    });

    if (mounted) {
      setState(() => _creatingBand = false);
      if (res['success'] == true) {
        AppToast.success(context, 'Distance pricing band added successfully.');
        _labelCtrl.clear();
        _loadAllData();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to add band');
      }
    }
  }

  Future<void> _deleteBand(int id) async {
    final res = await _service.deleteDistanceBand(id);
    if (mounted) {
      if (res['success'] == true) {
        AppToast.success(context, 'Distance band removed.');
        _loadAllData();
      } else {
        AppToast.error(context, 'Failed to delete band');
      }
    }
  }

  Future<void> _testCalculate() async {
    final lat = double.tryParse(_simLatCtrl.text.trim());
    final lng = double.tryParse(_simLngCtrl.text.trim());
    if (lat == null || lng == null) {
      AppToast.warning(context, 'Please enter valid coordinates');
      return;
    }

    final res = await _service.calculateDelivery(latitude: lat, longitude: lng);
    if (mounted) {
      setState(() {
        if (res['success'] == true && res['data'] is Map) {
          final d = res['data'] as Map;
          _simResult =
              'Calculated Distance: ${d['distance_km']} km (Straight-line Haversine)\nDelivery Fee: ₹${d['delivery_charge']}\nStatus: ${d['is_supported'] == true ? "Supported / In-Service Area" : "Out of Service Radius"} (${d['reason'] ?? 'Standard band'})';
        } else {
          _simResult = 'Calculation failed: ${res['message']}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;
        final dialogWidth = isMobile ? constraints.maxWidth * 0.96 : 840.0;
        final dialogHeight = isMobile ? constraints.maxHeight * 0.92 : 740.0;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 24,
            vertical: isMobile ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.radar_rounded,
                          color: Color(0xFF0284C7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery Origin & Radius Distance Pricing',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile
                                  ? 'Configure dispatch radius & distance fee bands.'
                                  : 'Configure base dispatch coordinates, straight-line Haversine radius, and distance pricing bands.',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload All Data',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _loadAllData,
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Prominent Saved Radius & Status Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildStatusBadge(
                          Icons.storefront_outlined,
                          'Depot',
                          _savedDepotName,
                          const Color(0xFF475569),
                          const Color(0xFFF1F5F9),
                        ),
                        _buildStatusBadge(
                          Icons.radar_rounded,
                          'Max Serviceable Radius',
                          '${_savedMaxRadius.toStringAsFixed(1)} km',
                          const Color(0xFF0284C7),
                          const Color(0xFFE0F2FE),
                        ),
                        _buildStatusBadge(
                          Icons.card_giftcard_rounded,
                          'Free Delivery Radius',
                          _savedFreeRadius > 0
                              ? '${_savedFreeRadius.toStringAsFixed(1)} km'
                              : '0.0 km (None)',
                          const Color(0xFF16A34A),
                          const Color(0xFFDCFCE7),
                        ),
                        _buildStatusBadge(
                          Icons.payments_outlined,
                          'Base Delivery Fee',
                          '₹${_savedDefaultFee.toStringAsFixed(0)}',
                          const Color(0xFFD97706),
                          const Color(0xFFFEF3C7),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _originActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _originActive ? 'ACTIVE & ENFORCED' : 'INACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _originActive ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Navigation Tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: isMobile,
                    tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
                    labelColor: const Color(0xFF0284C7),
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicatorColor: const Color(0xFF0284C7),
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: const [
                      Tab(icon: Icon(Icons.hub_outlined, size: 18), text: 'Dispatch & Radius'),
                      Tab(icon: Icon(Icons.linear_scale_rounded, size: 18), text: 'Distance Bands'),
                      Tab(icon: Icon(Icons.science_outlined, size: 18), text: 'Fee Simulator'),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tab Views - persistent mount so switching tabs is instant and never gets stuck
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOriginTab(isMobile),
                        _buildBandsTab(isMobile),
                        _buildSimulatorTab(),
                      ],
                    ),
                  ),

                  // Explicit Action Bottom Bar
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        ),
                        onPressed: _savingOrigin ? null : _saveOrigin,
                        icon: _savingOrigin
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: Text(
                          _savingOrigin ? 'Saving Changes...' : 'Save Configuration',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginTab(bool isMobile) {
    if (_loadingOrigin) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading delivery origin...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }
    if (_originError != null && _latCtrl.text.isEmpty) {
      return Center(
        child: _buildErrorWidget(
          title: 'Delivery Origin Unavailable',
          message: _originError!,
          onRetry: _loadOriginData,
        ),
      );
    }
    return SingleChildScrollView(
      child: Form(
        key: _originFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_originError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Server response slow / cold start. Showing fallback central dispatch.\n${_originError!}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _loadOriginData,
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
            // Haversine Formula Clarity Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Straight-Line Haversine Distance Engine',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Distance is calculated as the straight-line radial distance (in kilometers) between the base depot coordinates and the customer delivery location. Customer addresses exceeding the Max Serviceable Radius are prevented from ordering or flagged for special dispatch.',
                          style: TextStyle(fontSize: 11, height: 1.45, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Base Dispatch Coordinates
            const Text(
              'Base Dispatch Depot Coordinates',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _depotNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Depot / Central Dispatch Plant Name *',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.storefront_outlined, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),

            if (isMobile) ...[
              TextFormField(
                controller: _latCtrl,
                decoration: const InputDecoration(
                  labelText: 'Depot Latitude *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid latitude' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _lngCtrl,
                decoration: const InputDecoration(
                  labelText: 'Depot Longitude *',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid longitude' : null,
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Depot Latitude *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.my_location_rounded, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid latitude' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Depot Longitude *',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid longitude' : null,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            if (isMobile) ...[
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Depot Street Address',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.home_work_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pincodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pincode',
                  border: OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: Icon(Icons.pin_drop_outlined, size: 18),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Depot Street Address',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.home_work_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: TextFormField(
                      controller: _pincodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.pin_drop_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 22),

            // Redesigned Maximum Serviceable Radius Slider & Selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.radar_rounded, color: Color(0xFF0284C7), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Maximum Serviceable Radius',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Text(
                          '${_maxRadiusSlider.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Set the outer boundary distance from depot. Deliveries beyond this radius are not accepted.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF0284C7),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: const Color(0xFF0284C7),
                      overlayColor: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      valueIndicatorColor: const Color(0xFF0284C7),
                    ),
                    child: Slider(
                      value: _maxRadiusSlider.clamp(0.0, 100.0),
                      min: 0.0,
                      max: 100.0,
                      divisions: 200,
                      label: '${_maxRadiusSlider.toStringAsFixed(1)} km',
                      onChanged: (val) {
                        setState(() {
                          _maxRadiusSlider = val;
                          _maxRadiusCtrl.text = val.toStringAsFixed(1);
                        });
                      },
                    ),
                  ),

                  // Quick preset chips for Max Radius
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildPresetChip('10 km', 10.0, true),
                          _buildPresetChip('25 km (Std)', 25.0, true),
                          _buildPresetChip('50 km', 50.0, true),
                          _buildPresetChip('75 km', 75.0, true),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Redesigned Free Delivery Radius Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.card_giftcard_rounded, color: Color(0xFF16A34A), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Free Delivery Radius',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Text(
                          _freeRadiusSlider > 0 ? '${_freeRadiusSlider.toStringAsFixed(1)} km' : 'FREE (0 km)',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Customers within this straight-line radius will receive free delivery regardless of distance bands.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 8),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF16A34A),
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: const Color(0xFF16A34A),
                      overlayColor: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      valueIndicatorColor: const Color(0xFF16A34A),
                    ),
                    child: Slider(
                      value: _freeRadiusSlider.clamp(0.0, 30.0),
                      min: 0.0,
                      max: 30.0,
                      divisions: 60,
                      label: '${_freeRadiusSlider.toStringAsFixed(1)} km',
                      onChanged: (val) {
                        setState(() {
                          _freeRadiusSlider = val;
                          _freeRadiusCtrl.text = val.toStringAsFixed(1);
                        });
                      },
                    ),
                  ),

                  // Quick preset chips for Free Radius
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildPresetChip('0 km (None)', 0.0, false),
                          _buildPresetChip('2 km', 2.0, false),
                          _buildPresetChip('5 km', 5.0, false),
                          _buildPresetChip('10 km', 10.0, false),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Fallback delivery fee
            TextFormField(
              controller: _defaultFeeCtrl,
              decoration: const InputDecoration(
                labelText: 'Fallback Delivery Fee (₹) *',
                hintText: 'Default fee if distance band is not explicitly matched',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
            ),

            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Origin Active & Distance Enforcement Enabled',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              subtitle: const Text(
                'When enabled, order placement calculates delivery fee based on GPS distance.',
                style: TextStyle(fontSize: 11),
              ),
              value: _originActive,
              onChanged: (v) => setState(() => _originActive = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double km, bool isMaxRadius) {
    final current = isMaxRadius ? _maxRadiusSlider : _freeRadiusSlider;
    final isSelected = (current - km).abs() < 0.1;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isMaxRadius) {
            _maxRadiusSlider = km;
            _maxRadiusCtrl.text = km.toStringAsFixed(1);
          } else {
            _freeRadiusSlider = km;
            _freeRadiusCtrl.text = km.toStringAsFixed(1);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (isMaxRadius ? const Color(0xFF0284C7) : const Color(0xFF16A34A))
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildBandsTab(bool isMobile) {
    if (_loadingBands) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading distance bands...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }
    if (_bandsError != null && _bands.isEmpty) {
      return Center(
        child: _buildErrorWidget(
          title: 'Distance Bands Unavailable',
          message: _bandsError!,
          onRetry: _loadBandsData,
        ),
      );
    }

    final errorBanner = _bandsError != null
        ? Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Server response slow / cold start. Showing fallback distance bands.\n${_bandsError!}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _loadBandsData,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            errorBanner,
            _buildBandCreateForm(),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            _buildBandsList(),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        errorBanner,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: SingleChildScrollView(child: _buildBandCreateForm())),
              const VerticalDivider(width: 32),
              Expanded(flex: 6, child: _buildBandsList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBandCreateForm() {
    return Form(
      key: _bandFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Distance Band', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Define progressive delivery charge steps for straight-line distance ranges.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _minKmCtrl,
                  decoration: const InputDecoration(labelText: 'Min Distance (km)', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                  validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _maxKmCtrl,
                  decoration: const InputDecoration(labelText: 'Max Distance (km)', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                  validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _chargeCtrl,
            decoration: const InputDecoration(
              labelText: 'Delivery Charge (₹) *',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.currency_rupee_rounded, size: 18),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _labelCtrl,
            decoration: const InputDecoration(
              labelText: 'Band Label',
              hintText: 'e.g. Standard Local Zone',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.label_outline_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _creatingBand ? null : _createBand,
              icon: _creatingBand
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Distance Band', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Configured Distance Bands (${_bands.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_bands.length} Active',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _bands.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.linear_scale_rounded, size: 36, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      const Text('No distance bands configured.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Default fallback pricing of ₹${_defaultFeeCtrl.text} applies.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _bands.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, idx) {
                  final b = _bands[idx];
                  final minKm = b['min_distance_km'] ?? 0;
                  final maxKm = b['max_distance_km'] ?? 0;
                  final charge = b['delivery_charge'] ?? 0;
                  final label = b['label'] ?? 'Standard';

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$minKm km – $maxKm km',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text(
                          '₹$charge',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: 'Delete band',
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                          onPressed: () => _deleteBand(b['id'] as int),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSimulatorTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Fee Calculation Simulator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Simulate distance and fee calculation from the base dispatch plant to any customer coordinates.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _simLatCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Latitude', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _simLngCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Longitude', border: OutlineInputBorder(), isDense: true),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onPressed: _testCalculate,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Calculate'),
              ),
            ],
          ),
          if (_simResult != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Text(
                _simResult!,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.5, color: Color(0xFF166534)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
