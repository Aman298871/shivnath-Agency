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
  bool _isOriginCached = false;
  bool _isBandsCached = false;

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
  bool _isInternalSliderUpdate = false;
  bool _userInteractedWithSliders = false;

  double get _maxRadiusCeiling {
    if (_maxRadiusSlider <= 50.0) return 50.0;
    if (_maxRadiusSlider <= 100.0) return 100.0;
    if (_maxRadiusSlider <= 250.0) return 250.0;
    if (_maxRadiusSlider <= 500.0) return 500.0;
    if (_maxRadiusSlider <= 1000.0) return 1000.0;
    return (((_maxRadiusSlider + 200.0) / 200.0).ceil() * 200.0).toDouble().clamp(500.0, 9999.0);
  }

  int get _maxRadiusDivisions {
    final ceiling = _maxRadiusCeiling;
    if (ceiling <= 50.0) return 50;
    if (ceiling <= 100.0) return 100;
    if (ceiling <= 250.0) return 125;
    if (ceiling <= 500.0) return 100;
    if (ceiling <= 1000.0) return 100;
    return 100;
  }

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
  Map<String, dynamic>? _simData;
  bool _isSimulating = false;
  String? _simErrorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _maxRadiusCtrl.addListener(() {
      if (_isInternalSliderUpdate) return;
      final v = double.tryParse(_maxRadiusCtrl.text);
      if (v != null && v >= 0 && v <= 9999.0 && (v - _maxRadiusSlider).abs() > 0.1) {
        _userInteractedWithSliders = true;
        setState(() => _maxRadiusSlider = v);
      }
    });

    _freeRadiusCtrl.addListener(() {
      if (_isInternalSliderUpdate) return;
      final v = double.tryParse(_freeRadiusCtrl.text);
      if (v != null && v >= 0 && v <= 30 && (v - _freeRadiusSlider).abs() > 0.1) {
        _userInteractedWithSliders = true;
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
        _isOriginCached = originRes['is_cached'] == true;
        if ((originRes['success'] == true || originRes['is_cached'] == true) && originRes['origin'] is Map) {
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

          _savedFreeRadius = freeVal;
          _savedMaxRadius = maxVal;
          _savedDefaultFee = feeVal;
          _savedDepotName = _depotNameCtrl.text;

          if (!_userInteractedWithSliders) {
            _isInternalSliderUpdate = true;
            _freeRadiusCtrl.text = freeVal.toStringAsFixed(1);
            _maxRadiusCtrl.text = maxVal.toStringAsFixed(1);
            _defaultFeeCtrl.text = feeVal.toStringAsFixed(1);
            _freeRadiusSlider = freeVal.clamp(0.0, 30.0);
            _maxRadiusSlider = maxVal.clamp(0.0, 9999.0);
            _isInternalSliderUpdate = false;
          }

          _originActive = o['is_active'] ?? true;
          _originError = originRes['success'] == true ? null : originRes['message']?.toString();
        } else {
          // Preserve previously loaded valid data; surface error clearly
          _originError = originRes['message']?.toString() ?? 'Failed to load delivery origin settings. Please retry.';
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
        _isBandsCached = bandsRes['is_cached'] == true;
        if (bandsRes['bands'] is List) {
          _bands = List<dynamic>.from(bandsRes['bands'] as List);
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
    if (_originError != null && _savedDepotName.isEmpty) {
      AppToast.error(context, 'Cannot save: Delivery origin settings are unavailable. Please retry.');
      return;
    }
    if (!_originFormKey.currentState!.validate()) return;

    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    if (lat == null || lng == null) {
      AppToast.error(context, 'Valid depot latitude and longitude coordinates are required.');
      return;
    }

    final freeVal = _freeRadiusSlider;
    final maxVal = _maxRadiusSlider;
    final feeVal = double.tryParse(_defaultFeeCtrl.text.trim()) ?? 30.0;
    final nameVal = _depotNameCtrl.text.trim();

    setState(() => _savingOrigin = true);

    final res = await _service.updateDeliveryOrigin({
      'name': nameVal,
      'depot_name': nameVal,
      'address': _addressCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      'latitude': lat,
      'longitude': lng,
      'free_delivery_radius_km': freeVal,
      'max_serviceable_radius_km': maxVal,
      'default_delivery_charge': feeVal,
      'is_active': _originActive,
    });

    if (mounted) {
      setState(() {
        _savingOrigin = false;
        if (res['success'] == true) {
          _savedFreeRadius = freeVal;
          _savedMaxRadius = maxVal;
          _savedDefaultFee = feeVal;
          _savedDepotName = nameVal;
          _userInteractedWithSliders = false;
        }
      });
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

    final minKm = double.tryParse(_minKmCtrl.text.trim()) ?? 0.0;
    final maxKmStr = _maxKmCtrl.text.trim();
    final maxKm = maxKmStr.isEmpty ? null : double.tryParse(maxKmStr);
    final charge = double.tryParse(_chargeCtrl.text.trim()) ?? 0.0;
    String label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      label = maxKm != null ? '$minKm - $maxKm km Delivery' : 'Above $minKm km Delivery';
    }

    final Map<String, dynamic> bandData = {
      'name': label,
      'label': label,
      'min_distance_km': minKm,
      'delivery_charge': charge,
      'is_active': true,
      'is_supported': true,
      'applies_to': 'ALL',
    };
    if (maxKm != null) {
      bandData['max_distance_km'] = maxKm;
    }

    final res = await _service.createDistanceBand(bandData);

    if (mounted) {
      setState(() => _creatingBand = false);
      if (res['success'] == true) {
        AppToast.success(context, 'Distance pricing band added successfully.');
        _labelCtrl.clear();
        await _loadBandsData();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to add band');
      }
    }
  }

  Future<void> _deleteBand(int id, {bool isFallback = false}) async {
    if (isFallback) {
      setState(() {
        _bands.removeWhere((b) => b['id'] == id);
      });
      AppToast.info(context, 'Temporary preview band removed.');
      return;
    }
    setState(() {
      _bands.removeWhere((b) => b['id'] == id);
    });
    final res = await _service.deleteDistanceBand(id);
    if (mounted) {
      if (res['success'] == true) {
        AppToast.success(context, 'Distance band removed.');
        await _loadBandsData();
      } else {
        AppToast.error(context, res['message']?.toString() ?? 'Failed to delete band');
        await _loadBandsData();
      }
    }
  }

  Future<void> _deleteAllBands() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete All Bands?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete all configured distance bands? '
          'You will be able to create your own custom distance tiers from scratch.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final bandsToDelete = List<dynamic>.from(_bands);
    setState(() {
      _bands.clear();
      _loadingBands = true;
    });

    final res = await _service.deleteAllDistanceBands();
    if (mounted) {
      if (res['success'] == true) {
        AppToast.success(context, 'All distance bands cleared.');
        await _loadBandsData();
      } else {
        bool anyFailed = false;
        for (final b in bandsToDelete) {
          final id = b['id'];
          if (id is int && b['is_fallback'] != true) {
            final delRes = await _service.deleteDistanceBand(id);
            if (delRes['success'] != true) anyFailed = true;
          }
        }
        await _loadBandsData();
        if (mounted) {
          if (anyFailed) {
            AppToast.warning(context, 'Some bands could not be deleted.');
          } else {
            AppToast.success(context, 'All distance bands removed.');
          }
        }
      }
    }
  }

  Future<void> _showEditBandDialog(Map<String, dynamic> band) async {
    final formKey = GlobalKey<FormState>();
    final id = band['id'];
    if (id is! int) return;

    final minKm = band['min_distance_km']?.toString() ?? '0';
    final maxKm = band['max_distance_km']?.toString() ?? '';
    final charge = band['delivery_charge']?.toString() ?? '0';
    final name = band['name']?.toString() ?? band['label']?.toString() ?? '';

    final nameCtrl = TextEditingController(text: name);
    final minCtrl = TextEditingController(text: minKm);
    final maxCtrl = TextEditingController(text: maxKm);
    final chargeCtrl = TextEditingController(text: charge);

    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Edit Distance Band',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Band Name / Label *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Min Km *',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: maxCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Km',
                                hintText: 'Blank = Open-ended',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final val = double.tryParse(v.trim());
                                if (val == null) return 'Invalid';
                                final minV = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                                if (val <= minV) return '> Min';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: chargeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Delivery Charge (₹) *',
                          prefixIcon: Icon(Icons.currency_rupee_rounded, size: 16),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final parsed = double.tryParse(v ?? '');
                          if (parsed == null || parsed < 0) return 'Valid fee required';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);

                          final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                          final maxValStr = maxCtrl.text.trim();
                          final maxVal = maxValStr.isEmpty ? null : double.tryParse(maxValStr);
                          final feeVal = double.tryParse(chargeCtrl.text.trim()) ?? 0.0;

                          final patchData = <String, dynamic>{
                            'name': nameCtrl.text.trim(),
                            'min_distance_km': minVal,
                            'delivery_charge': feeVal,
                          };
                          if (maxVal != null) {
                            patchData['max_distance_km'] = maxVal;
                          } else {
                            patchData['max_distance_km'] = null;
                          }

                          final res = await _service.updateDistanceBand(id, patchData);
                          if (!mounted) return;
                          if (ctx.mounted) {
                            setDialogState(() => isSubmitting = false);
                            if (res['success'] == true) {
                              Navigator.pop(ctx);
                              AppToast.success(context, 'Distance band updated successfully.');
                              await _loadBandsData();
                            } else {
                              AppToast.error(context, res['message']?.toString() ?? 'Failed to update band');
                            }
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _testCalculate() async {
    final lat = double.tryParse(_simLatCtrl.text.trim());
    final lng = double.tryParse(_simLngCtrl.text.trim());
    if (lat == null || lng == null) {
      AppToast.warning(context, 'Please enter valid destination coordinates');
      return;
    }

    setState(() {
      _isSimulating = true;
      _simData = null;
      _simErrorMessage = null;
    });

    final res = await _service.calculateDelivery(latitude: lat, longitude: lng);
    if (mounted) {
      setState(() {
        _isSimulating = false;
        if (res['data'] is Map) {
          _simData = Map<String, dynamic>.from(res['data'] as Map);
          if (res['success'] == false && _simData?['message'] != null) {
            _simErrorMessage = _simData!['message'].toString();
          } else {
            _simErrorMessage = null;
          }
        } else {
          _simErrorMessage = res['message']?.toString() ?? 'Simulation request failed.';
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
          child: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
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

                  if (isMobile)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '$_savedDepotName (${_savedMaxRadius.toStringAsFixed(0)}km max)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isOriginCached ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _isOriginCached ? 'LOCAL CACHE' : 'SERVER SYNCED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: _isOriginCached ? const Color(0xFFB45309) : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
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
                            ((_maxRadiusSlider - _savedMaxRadius).abs() > 0.05)
                                ? '${_maxRadiusSlider.toStringAsFixed(1)} km (Draft)'
                                : '${_maxRadiusSlider.toStringAsFixed(1)} km',
                            const Color(0xFF0284C7),
                            const Color(0xFFE0F2FE),
                          ),
                          _buildStatusBadge(
                            Icons.card_giftcard_rounded,
                            'Free Delivery Radius',
                            ((_freeRadiusSlider - _savedFreeRadius).abs() > 0.05)
                                ? '${_freeRadiusSlider.toStringAsFixed(1)} km (Draft)'
                                : (_freeRadiusSlider > 0
                                    ? '${_freeRadiusSlider.toStringAsFixed(1)} km'
                                    : '0.0 km (None)'),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isOriginCached ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _isOriginCached ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isOriginCached ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                                  size: 12,
                                  color: _isOriginCached ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isOriginCached ? 'LOCAL CACHE' : 'SERVER SYNCED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _isOriginCached ? const Color(0xFFB45309) : const Color(0xFF15803D),
                                  ),
                                ),
                              ],
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
                        _buildSimulatorTab(isMobile),
                      ],
                    ),
                  ),

                  // Explicit Action Bottom Bar
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (_tabController.index == 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                        ),
                        if (_originError != null) ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              side: const BorderSide(color: Color(0xFF0284C7)),
                            ),
                            onPressed: _loadingOrigin ? null : _loadOriginData,
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Retry Load', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                          onPressed: (_loadingOrigin || _savingOrigin) ? null : _saveOrigin,
                          icon: (_savingOrigin || _loadingOrigin)
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: Text(
                            _savingOrigin
                                ? 'Saving Changes...'
                                : (_loadingOrigin ? 'Loading Configuration...' : 'Save Radius & Origin'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ] else if (_tabController.index == 1) ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: _loadingBands ? null : _loadBandsData,
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF0284C7)),
                          label: const Text('Refresh Bands', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w700)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ] else ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                          onPressed: _isSimulating ? null : _testCalculate,
                          icon: _isSimulating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.play_arrow_rounded, size: 18),
                          label: const Text('Run Simulator', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
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
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: textColor),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
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
    if (_loadingOrigin && _latCtrl.text.isEmpty && _depotNameCtrl.text.isEmpty) {
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
    if (_originError != null && _latCtrl.text.isEmpty && _depotNameCtrl.text.isEmpty) {
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
            if (_loadingOrigin) ...[
              const ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: Color(0xFF0284C7),
                  backgroundColor: Color(0xFFE0F2FE),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.radar_rounded, color: Color(0xFF0284C7), size: 20),
                          Text(
                            'Maximum Serviceable Radius',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                      value: _maxRadiusSlider.clamp(0.0, _maxRadiusCeiling),
                      min: 0.0,
                      max: _maxRadiusCeiling,
                      divisions: _maxRadiusDivisions,
                      label: '${_maxRadiusSlider.toStringAsFixed(1)} km',
                      onChanged: (val) {
                        _userInteractedWithSliders = true;
                        setState(() {
                          _maxRadiusSlider = val;
                          _isInternalSliderUpdate = true;
                          _maxRadiusCtrl.text = val.toStringAsFixed(1);
                          _isInternalSliderUpdate = false;
                        });
                      },
                    ),
                  ),

                  // Quick preset chips for Max Radius
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 4,
                        children: [
                          const Text('Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          Text(
                            'Scale: 0 - ${_maxRadiusCeiling.toStringAsFixed(0)} km (Max: 9,999 km)',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPresetChip('25 km (Std)', 25.0, true),
                          _buildPresetChip('50 km', 50.0, true),
                          _buildPresetChip('100 km', 100.0, true),
                          _buildPresetChip('250 km', 250.0, true),
                          _buildPresetChip('500 km', 500.0, true),
                          _buildPresetChip('1000 km', 1000.0, true),
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
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(Icons.card_giftcard_rounded, color: Color(0xFF16A34A), size: 20),
                          Text(
                            'Free Delivery Radius',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
                        _userInteractedWithSliders = true;
                        setState(() {
                          _freeRadiusSlider = val;
                          _isInternalSliderUpdate = true;
                          _freeRadiusCtrl.text = val.toStringAsFixed(1);
                          _isInternalSliderUpdate = false;
                        });
                      },
                    ),
                  ),

                  // Quick preset chips for Free Radius
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPresetChip('0 km (None)', 0.0, false),
                          _buildPresetChip('2 km', 2.0, false),
                          _buildPresetChip('5 km', 5.0, false),
                          _buildPresetChip('10 km', 10.0, false),
                          _buildPresetChip('15 km', 15.0, false),
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
        _userInteractedWithSliders = true;
        setState(() {
          if (isMaxRadius) {
            _maxRadiusSlider = km;
            _isInternalSliderUpdate = true;
            _maxRadiusCtrl.text = km.toStringAsFixed(1);
            _isInternalSliderUpdate = false;
          } else {
            _freeRadiusSlider = km;
            _isInternalSliderUpdate = true;
            _freeRadiusCtrl.text = km.toStringAsFixed(1);
            _isInternalSliderUpdate = false;
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
    if (_loadingBands && _bands.isEmpty) {
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
                    'Network warning: ${_bandsError!}',
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
                  decoration: const InputDecoration(
                    labelText: 'Max Distance (km)',
                    hintText: 'Blank = open-ended',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null) return 'Invalid number';
                    final minVal = double.tryParse(_minKmCtrl.text.trim()) ?? 0.0;
                    if (parsed <= minVal) return 'Must be > min';
                    return null;
                  },
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
              labelText: 'Band Label (Optional)',
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
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Configured Distance Bands (${_bands.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_bands.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _deleteAllBands,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text('Delete All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _isBandsCached ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isBandsCached ? '${_bands.length} Cached' : '${_bands.length} Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _isBandsCached ? const Color(0xFFB45309) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
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
                  final maxKm = b['max_distance_km'];
                  final charge = b['delivery_charge'] ?? 0;
                  final label = b['label'] ?? b['name'] ?? 'Standard';
                  final isFallback = b['is_fallback'] == true;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFallback ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                      ),
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
                            color: isFallback ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.straighten_rounded,
                            size: 18,
                            color: isFallback ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    maxKm == null ? 'Above $minKm km' : '$minKm km – $maxKm km',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                  if (isFallback)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('Default Template', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                    ),
                                ],
                              ),
                              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Text(
                          '₹$charge',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0284C7)),
                        ),
                        const SizedBox(width: 6),
                        if (!isFallback && b['id'] is int)
                          IconButton(
                            tooltip: 'Edit band limits or charge',
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF0284C7),
                              size: 18,
                            ),
                            onPressed: () => _showEditBandDialog(Map<String, dynamic>.from(b as Map)),
                          ),
                        IconButton(
                          tooltip: isFallback ? 'Remove template band' : 'Delete band',
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: isFallback ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                            size: 18,
                          ),
                          onPressed: () => _deleteBand(b['id'] as int, isFallback: isFallback),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildSimulatorTab(bool isMobile) {
    final d = _simData;
    final isBlocked = d?['is_blocked'] == true;
    final isSupported = d?['is_supported'] == true && !isBlocked;
    final fee = d?['delivery_charge']?.toString() ?? '0';
    final distanceKm = d?['distance_km']?.toString() ?? '0';
    final bandName = d?['band_name']?.toString() ?? 'None';
    final bandId = d?['band_id']?.toString();
    final freeRadius = double.tryParse(_freeRadiusCtrl.text.trim()) ?? 0.0;
    final distNum = double.tryParse(distanceKm) ?? 0.0;
    final isFreeApplied = distNum <= freeRadius && freeRadius > 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.science_outlined, size: 20, color: Color(0xFF0284C7)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Fee Calculation Simulator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                      'Preview authoritative backend delivery charges using currently saved distance bands & radius.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Authoritative Origin Context Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 14, color: Color(0xFF0284C7)),
                    SizedBox(width: 6),
                    Text('Authoritative Dispatch Hub', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('Hub: ${_depotNameCtrl.text}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    Text('Coords: (${_latCtrl.text}, ${_lngCtrl.text})', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    Text('Free Radius: ${_freeRadiusSlider.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                    Text('Max Radius: ${_maxRadiusSlider.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7))),
                    Text('Base Fee: ₹${_defaultFeeCtrl.text}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Quick Destination Presets for CG testing
          const Text('Quick Test Destination Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSimPresetChip('Mowa / Local (~1.2 km)', '21.2720', '81.6750'),
              _buildSimPresetChip('Telibandha (~6.1 km)', '21.2330', '81.6720'),
              _buildSimPresetChip('Naya Raipur (~18.5 km)', '21.1600', '81.7800'),
              _buildSimPresetChip('Durg/Bhilai (~35 km)', '21.2100', '81.3800'),
              _buildSimPresetChip('Bilaspur (~115 km)', '22.0800', '82.1400'),
              _buildSimPresetChip('Beyond Radius (550 km)', '25.5941', '85.1376'),
            ],
          ),

          const SizedBox(height: 14),

          if (isMobile) ...[
            TextFormField(
              controller: _simLatCtrl,
              decoration: const InputDecoration(labelText: 'Customer Destination Latitude *', border: OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _simLngCtrl,
              decoration: const InputDecoration(labelText: 'Customer Destination Longitude *', border: OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSimulating ? null : _testCalculate,
                icon: _isSimulating
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(_isSimulating ? 'Calculating...' : 'Run Pricing Simulation', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _simLatCtrl,
                    decoration: const InputDecoration(labelText: 'Destination Latitude *', border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _simLngCtrl,
                    decoration: const InputDecoration(labelText: 'Destination Longitude *', border: OutlineInputBorder(), isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: _isSimulating ? null : _testCalculate,
                  icon: _isSimulating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(_isSimulating ? 'Calculating...' : 'Run Simulation', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],

          if (_simErrorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _simErrorMessage!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (d != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSupported ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSupported ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSupported ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: isSupported ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isSupported ? 'Serviceable Destination' : 'Outside Service Radius',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isSupported ? const Color(0xFF166534) : const Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSupported ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isSupported ? '₹$fee' : 'BLOCKED',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isSupported ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildSimDetailItem('Straight-Line Distance', '$distanceKm km (Haversine)'),
                      _buildSimDetailItem('Matched Distance Band', '$bandName ${bandId != null ? "(ID: $bandId)" : ""}'),
                      _buildSimDetailItem('Calculated Delivery Fee', '₹$fee'),
                      _buildSimDetailItem(
                        'Free Delivery Rule',
                        isFreeApplied
                            ? 'APPLIED (≤ ${_freeRadiusCtrl.text} km free radius)'
                            : (freeRadius > 0 ? 'Not applied (> ${_freeRadiusCtrl.text} km)' : 'None configured (0 km)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ADMINISTRATIVE PREVIEW: This calculation uses the server\'s active delivery configuration. '
                            'Customer orders at checkout execute this identical backend calculation and persist the charge on the invoice.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimPresetChip(String label, String lat, String lng) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      onPressed: () {
        setState(() {
          _simLatCtrl.text = lat;
          _simLngCtrl.text = lng;
        });
        _testCalculate();
      },
    );
  }

  Widget _buildSimDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ],
    );
  }
}
