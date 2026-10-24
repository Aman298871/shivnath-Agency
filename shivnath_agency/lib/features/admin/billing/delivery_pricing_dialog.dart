import 'package:flutter/material.dart';
import '../../../core/services/delivery_pricing_service.dart';
import '../../../core/widgets/app_toast.dart';

class DeliveryPricingDialog extends StatefulWidget {
  const DeliveryPricingDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const DeliveryPricingDialog(),
    );
  }

  @override
  State<DeliveryPricingDialog> createState() => _DeliveryPricingDialogState();
}

class _DeliveryPricingDialogState extends State<DeliveryPricingDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DeliveryPricingService _service = DeliveryPricingService();

  bool _loading = true;
  bool _savingOrigin = false;
  bool _creatingBand = false;

  // Origin Controllers
  final _originFormKey = GlobalKey<FormState>();
  final _depotNameCtrl = TextEditingController(text: 'Shivnath Agency Central Dispatch');
  final _addressCtrl = TextEditingController(text: 'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh');
  final _pincodeCtrl = TextEditingController(text: '492014');
  final _latCtrl = TextEditingController(text: '21.267800');
  final _lngCtrl = TextEditingController(text: '81.671100');
  final _freeRadiusCtrl = TextEditingController(text: '0.0');
  final _maxRadiusCtrl = TextEditingController(text: '25.0');
  final _defaultFeeCtrl = TextEditingController(text: '30.0');
  bool _originActive = true;

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

  Future<void> _loadAllData() async {
    setState(() => _loading = true);
    final originRes = await _service.getDeliveryOrigin();
    final bandsRes = await _service.getDistanceBands();

    if (mounted) {
      setState(() {
        _loading = false;
        if (originRes['success'] == true && originRes['origin'] is Map) {
          final o = originRes['origin'] as Map;
          if (o['name'] != null) _depotNameCtrl.text = o['name'].toString();
          if (o['depot_name'] != null) _depotNameCtrl.text = o['depot_name'].toString();
          if (o['address'] != null) _addressCtrl.text = o['address'].toString();
          if (o['pincode'] != null) _pincodeCtrl.text = o['pincode'].toString();
          if (o['latitude'] != null) _latCtrl.text = o['latitude'].toString();
          if (o['longitude'] != null) _lngCtrl.text = o['longitude'].toString();
          if (o['free_delivery_radius_km'] != null) _freeRadiusCtrl.text = o['free_delivery_radius_km'].toString();
          if (o['max_serviceable_radius_km'] != null) _maxRadiusCtrl.text = o['max_serviceable_radius_km'].toString();
          if (o['default_delivery_charge'] != null) _defaultFeeCtrl.text = o['default_delivery_charge'].toString();
          _originActive = o['is_active'] ?? true;
        }

        if (bandsRes['success'] == true && bandsRes['bands'] is List) {
          _bands = bandsRes['bands'] as List;
        }
      });
    }
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
        AppToast.success(context, 'Delivery origin settings saved successfully');
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
        AppToast.success(context, 'Distance pricing band added');
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
        AppToast.success(context, 'Distance band removed');
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
          _simResult = 'Calculated Distance: ${d['distance_km']} km\nDelivery Fee: ₹${d['delivery_charge']}\nStatus: ${d['is_supported'] == true ? "Supported" : "Out of range"} (${d['reason'] ?? 'Standard band'})';
        } else {
          _simResult = 'Calculation failed: ${res['message']}';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Origin & Radius Distance Pricing',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Configure base dispatch coordinates, free radius, maximum coverage, and distance pricing bands.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF0284C7),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0284C7),
                tabs: const [
                  Tab(icon: Icon(Icons.hub_outlined, size: 18), text: 'Dispatch Origin'),
                  Tab(icon: Icon(Icons.linear_scale_rounded, size: 18), text: 'Distance Bands'),
                  Tab(icon: Icon(Icons.science_outlined, size: 18), text: 'Fee Simulator'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOriginTab(),
                          _buildBandsTab(),
                          _buildSimulatorTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginTab() {
    return SingleChildScrollView(
      child: Form(
        key: _originFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Base Dispatch Depot Coordinates', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _depotNameCtrl,
              decoration: const InputDecoration(labelText: 'Depot / Plant Name *', border: OutlineInputBorder(), isDense: true),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: const InputDecoration(labelText: 'Depot Latitude *', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid latitude' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    decoration: const InputDecoration(labelText: 'Depot Longitude *', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Invalid longitude' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Depot Address', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: TextFormField(
                    controller: _pincodeCtrl,
                    decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Radius & Coverage Boundaries', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _freeRadiusCtrl,
                    decoration: const InputDecoration(labelText: 'Free Delivery Radius (km)', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _maxRadiusCtrl,
                    decoration: const InputDecoration(labelText: 'Max Serviceable Radius (km)', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _defaultFeeCtrl,
                    decoration: const InputDecoration(labelText: 'Fallback Delivery Fee (₹)', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Origin Active & Enforced', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              value: _originActive,
              onChanged: (v) => setState(() => _originActive = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                onPressed: _savingOrigin ? null : _saveOrigin,
                icon: _savingOrigin
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Origin Configuration'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBandsTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create Form
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Form(
              key: _bandFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Distance Band', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minKmCtrl,
                          decoration: const InputDecoration(labelText: 'Min Km', border: OutlineInputBorder(), isDense: true),
                          keyboardType: TextInputType.number,
                          validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _maxKmCtrl,
                          decoration: const InputDecoration(labelText: 'Max Km', border: OutlineInputBorder(), isDense: true),
                          keyboardType: TextInputType.number,
                          validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _chargeCtrl,
                    decoration: const InputDecoration(labelText: 'Delivery Charge (₹)', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(labelText: 'Band Label', hintText: 'e.g. Standard City Delivery', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
                      onPressed: _creatingBand ? null : _createBand,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Band'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 32),
        // Bands List
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configured Distance Bands (${_bands.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                child: _bands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.linear_scale_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            const Text('No distance bands configured.', style: TextStyle(color: Color(0xFF64748B))),
                            const SizedBox(height: 4),
                            Text('Default fallback pricing applies.', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _bands.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$minKm km – $maxKm km', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Text('₹$charge', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0284C7))),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                  onPressed: () => _deleteBand(b['id'] as int),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery Fee Calculation Simulator', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Simulate distance and fee calculation from the configured base depot to a customer coordinate.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _simLatCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Latitude', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _simLngCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Longitude', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
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
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF166534)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
